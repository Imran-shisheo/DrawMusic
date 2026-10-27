#!/usr/bin/env python3
"""Read-only inspection of this repository's diagnostic UI artifact.

Optional PNGs are the exact ADB screenshots, not regenerated widgets. Their SHA
must match the capture host's report. Only original fixture content is captured;
this does not read an owner's phone or arbitrary files from the runner.
"""
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path('work/ui-capture-inspect')


def emit_png(name, data, *, motion=False):
    prefix = 'UI_MOTION_CONTACT_PNG' if motion else 'UI_CAPTURE_PNG'
    digest = hashlib.sha256(data).hexdigest()
    print(f'{prefix}_BEGIN|{name}|{digest}|{len(data)}', flush=True)
    encoded = base64.b64encode(data).decode('ascii')
    for offset in range(0, len(encoded), 160):
        print(prefix + '_DATA|' + encoded[offset:offset + 160], flush=True)
    print(f'{prefix}_END|{name}', flush=True)


def inspect_ambient_recording(request, report):
    if not request.get('ambientMotionContact', False):
        return
    if request['ambientMotionContact'] is not True:
        raise ValueError('Expected boolean ambientMotionContact')
    # Fixed diagnostic-owned filename, not an arbitrary path or remote URL.
    clip = ROOT / 'recordings/00-home-ambient.mp4'
    event = next((item for item in report['events']
                  if item.get('operation') == 'record_stop'
                  and item.get('name') == '00-home-ambient'), None)
    if not event or not clip.is_file() or not 1000 <= clip.stat().st_size <= 64_000_000:
        raise ValueError('Bounded actual ambient recording missing')
    if clip.stat().st_size != event['bytes']:
        raise ValueError('Ambient recording size differs from original capture report')
    probe = subprocess.run([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=codec_name,width,height,r_frame_rate,avg_frame_rate,nb_frames:format=duration',
        '-of', 'json', str(clip),
    ], check=True, capture_output=True, text=True, timeout=20)
    metadata = json.loads(probe.stdout)
    if float(metadata['format']['duration']) < 16:
        raise ValueError('Ambient clip does not cover the authored full 16-second loop')
    metadata.update(
        sha256=hashlib.sha256(clip.read_bytes()).hexdigest(),
        scope='Temporal samples of actual silent Android screenrecord; not regenerated widgets or a smoothness/physical-device claim',
        nominalSampleSeconds=[0, 3, 6, 9, 12, 15],
        sampling='ffmpeg fps=1/3:start_time=0 picks adjacent real encoded frames at nominal timestamps',
    )
    print('UI_AMBIENT_RECORDING_METADATA ' + json.dumps(metadata), flush=True)
    output = ROOT / 'ambient-temporal-contact.png'
    subprocess.run([
        'ffmpeg', '-nostdin', '-v', 'error', '-i', str(clip),
        '-vf', 'fps=1/3:start_time=0,scale=240:-2,tile=3x2',
        '-frames:v', '1', '-y', str(output),
    ], check=True, capture_output=True, timeout=40)
    data = output.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data) > 1_500_000:
        raise ValueError('Motion contact PNG signature/size rejected')
    emit_png('20-home-ambient-temporal.png', data, motion=True)


def main():
    request = json.loads(Path('cloud/ui-capture-inspect.json').read_text())
    for name in ('source-provenance.json', 'capture-report.json', 'flutter-drive.log'):
        path = ROOT / name
        print(f'UI_INSPECT_START {name}', flush=True)
        value = path.read_text(errors='replace') if path.exists() else 'Missing diagnostic file'
        for line in value.splitlines()[-180:]:
            if 'UI_CAPTURE_TOKEN=' not in line:
                print(line, flush=True)
        print(f'UI_INSPECT_END {name}', flush=True)
    for path in sorted((ROOT / 'performance').glob('*.json')):
        value = json.loads(path.read_text())
        value.pop('rawFrames', None)
        print(f'UI_PERFORMANCE_SUMMARY {path.name} {json.dumps(value)}', flush=True)
    for path in sorted((ROOT / 'recordings').glob('*.log'))[:8]:
        if not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.log', path.name):
            raise ValueError('Recording diagnostic name rejected')
        print(f'UI_RECORDING_LOG_BEGIN {path.name}', flush=True)
        for line in path.read_text(errors='replace').splitlines()[-80:]:
            print(re.sub(r'DrawMusicCapture-[0-9a-f]{32}-', 'DrawMusicCapture-[redacted]-', line[:1000]), flush=True)
        print(f'UI_RECORDING_LOG_END {path.name}', flush=True)
    screenshots = request.get('screenshots', [])
    if not isinstance(screenshots, list) or len(screenshots) > 4:
        raise ValueError('Select at most four exact PNG names per read-only inspection')
    report = json.loads((ROOT / 'capture-report.json').read_text())
    expected = {item['name'] + '.png': item['sha256'] for item in report.get('events', []) if item.get('operation') == 'snapshot'}
    total = 0
    for name in screenshots:
        if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
            raise ValueError('Screenshot name rejected')
        data = (ROOT / 'screenshots' / name).read_bytes()
        total += len(data)
        if not data.startswith(b'\x89PNG\r\n\x1a\n') or total > 1_000_000:
            raise ValueError('PNG signature/inspection batch size rejected')
        digest = hashlib.sha256(data).hexdigest()
        if digest != expected.get(name):
            raise ValueError('Screenshot bytes do not match the actual capture report')
        emit_png(name, data)
    inspect_ambient_recording(request, report)


if __name__ == '__main__':
    main()
