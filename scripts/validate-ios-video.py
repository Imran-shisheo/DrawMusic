#!/usr/bin/env python3
"""Independently inspect the real ios_native_ports_test fixture with FFmpeg.

Arguments: video expected.wav project.json report.json fps [width=640]
Requires NumPy. Checks actual packet cadence, full decoding, audio correlation,
cursor timing and asymmetric document geometry; never uses container FPS alone.
"""
import array
import fractions
import json
import pathlib
import subprocess
import sys
import wave

import numpy as np

video, wav, project_path, report_path = map(pathlib.Path, sys.argv[1:5])
fps = int(sys.argv[5])
assert fps in (30, 60)
width = int(sys.argv[6]) if len(sys.argv) > 6 else 640
assert width in (640, 1080)
height = width * 5 // 4
project = json.loads(project_path.read_text())


def ffprobe(*args):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', *args, '-of', 'json', str(video)
    ]))


streams = ffprobe('-show_streams')['streams']
v = next(s for s in streams if s['codec_type'] == 'video')
a = next(s for s in streams if s['codec_type'] == 'audio')
assert v['codec_name'] == 'h264' and a['codec_name'] == 'aac'
assert (v['width'], v['height']) == (width, height)
assert abs(float(fractions.Fraction(v['avg_frame_rate'])) - fps) < .01
assert (a['sample_rate'], a['channels']) == ('44100', 1)
packets = ffprobe('-select_streams', 'v:0', '-show_packets',
                  '-show_entries', 'packet=pts_time')['packets']
pts = np.array([float(p['pts_time']) for p in packets])
assert len(pts) > 1 and abs(pts[0]) < .000002
assert np.max(np.abs(np.diff(pts) - 1 / fps)) < .000002
vd, ad = float(v['duration']), float(a['duration'])
assert abs(pts[-1] + 1 / fps - vd) < .002
assert abs(vd - ad) <= 1 / fps + .002, (vd, ad)
subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(video),
                '-map', '0:v:0', '-an', '-f', 'null', '-'], check=True)
with wave.open(str(wav)) as w:
    assert (w.getframerate(), w.getnchannels(), w.getsampwidth()) == (44100, 1, 2)
    expected_duration = w.getnframes() / 44100
    ref = np.asarray(array.array('h', w.readframes(w.getnframes())), dtype=np.float64)
assert expected_duration - .01 <= ad <= expected_duration + .15
decoded = subprocess.check_output(['ffmpeg', '-v', 'error', '-xerror', '-i', str(video),
                                  '-map', '0:a:0', '-ac', '1', '-ar', '44100', '-f', 's16le', 'pipe:1'])
out = np.asarray(array.array('h', decoded), dtype=np.float64)
assert np.sqrt(np.mean(out * out)) > 100
size = 1 << (len(ref) + len(out) - 2).bit_length()
cross = np.fft.irfft(np.fft.rfft(out, size) * np.conj(np.fft.rfft(ref, size)), size)
lags = np.arange(-round(.05 * 44100), round(.05 * 44100) + 1)
correlations = cross[lags % size] / np.sqrt(np.dot(ref, ref) * np.dot(out, out))
index = int(np.argmax(correlations))
correlation, offset_ms = float(correlations[index]), float(lags[index] * 1000 / 44100)
assert correlation > .75 and abs(offset_ms) <= 1000 / fps, (correlation, offset_ms)

loop_seconds = 480 / project['tempo']
cursor_checks, geometry_checks = [], []
catalog = {'keys': (121, 97, 198), 'bell': (40, 126, 97)}
assert project.get('style', 'smooth') == 'smooth'
for moment in (loop_seconds / 4, loop_seconds * 3 / 4):
    pixels = subprocess.check_output(['ffmpeg', '-v', 'error', '-ss', str(moment),
                                     '-i', str(video), '-frames:v', '1', '-f', 'rawvideo',
                                     '-pix_fmt', 'rgb24', 'pipe:1'])
    frame = np.frombuffer(pixels, dtype=np.uint8).reshape((height, width, 3)).astype(np.int16)
    expected_x = round(moment / loop_seconds * width)
    # Quartz antialiasing and H.264 chroma subsampling blend a narrow cursor
    # into paper. Require a full-height teal line near its scheduled position;
    # isolated green drawing marks cannot satisfy this spatial condition.
    stripe = frame[20:height - 20, max(0, expected_x - 12):min(width, expected_x + 13)]
    teal = ((stripe[:, :, 0] < 70) & (stripe[:, :, 1] > 70) &
            (stripe[:, :, 1] < 185) & (stripe[:, :, 2] > 60) & (stripe[:, :, 2] < 180))
    counts = teal.sum(axis=0)
    observed_x = max(0, expected_x - 12) + int(np.argmax(counts))
    assert counts.max() > height * .7, (moment, int(counts.max()))
    one_frame_pixels = width / (loop_seconds * fps)
    assert abs(observed_x - expected_x) <= one_frame_pixels
    cursor_checks.append({'seconds': moment, 'expected_x': expected_x,
                          'observed_x': observed_x, 'matching_rows': int(counts.max()),
                          'one_frame_tolerance_pixels': one_frame_pixels})
    for stroke in project['strokes']:
        expected_color = np.asarray(catalog[stroke['instrument']])
        start, end = stroke['points'][0], stroke['points'][-1]
        u, y = (start[0] + end[0]) / 2, (start[1] + end[1]) / 2
        x, yy = round(u * width), round(y * height)
        assert abs(x - expected_x) > 10, 'Fixture sample must avoid the cursor'
        patch = frame[yy - 2:yy + 3, x - 2:x + 3]
        distance = np.abs(patch - expected_color).max(axis=2)
        assert distance.min() <= 30, (stroke['id'], moment, patch[2, 2].tolist())
        geometry_checks.append({'stroke': stroke['id'], 'seconds': moment,
                                'x': x, 'y': yy, 'minimum_color_error': int(distance.min())})

report = {'video': {'codec': 'h264', 'width': width, 'height': height, 'fps': fps,
                    'samples': len(pts), 'duration': vd, 'full_decode': True},
          'audio': {'codec': 'aac', 'sample_rate': 44100, 'channels': 1,
                    'duration': ad, 'correlation': correlation, 'offset_ms': offset_ms},
          'cursor': cursor_checks, 'asymmetric_geometry': geometry_checks}
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
