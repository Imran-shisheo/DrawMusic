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
    contact = request.get('ambientMotionContact', False)
    diagnostic = request.get('ambientMotionDiagnostic', False)
    if type(contact) is not bool or type(diagnostic) is not bool:
        raise ValueError('Expected boolean ambient inspection options')
    if not contact and not diagnostic: return
    # Fixed diagnostic-owned filename, never an arbitrary path or remote URL.
    clip = ROOT / 'recordings/00-home-ambient.mp4'
    start = next((item for item in report['events'] if item.get('operation') == 'record_start' and item.get('name') == '00-home-ambient'), None)
    event = next((item for item in report['events'] if item.get('operation') == 'record_stop' and item.get('name') == '00-home-ambient'), None)
    if not start or (not event and not diagnostic) or not clip.is_file() or not 1000 <= clip.stat().st_size <= 64_000_000:
        raise ValueError('Bounded recorded-start/exact ambient recording missing')
    if event and clip.stat().st_size != event['bytes']:
        raise ValueError('Ambient recording size differs from original capture report')
    digest = hashlib.sha256(clip.read_bytes()).hexdigest()
    if event and event.get('sha256') is not None and event['sha256'] != digest:
        raise ValueError('Ambient recording SHA differs from original capture report')
    probe = subprocess.run([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-count_frames', '-count_packets',
        '-show_entries', 'stream=codec_name,width,height,start_time,duration,duration_ts,time_base,r_frame_rate,avg_frame_rate,nb_frames,nb_read_frames,nb_read_packets:format=start_time,duration',
        '-of', 'json', str(clip),
    ], check=True, capture_output=True, text=True, timeout=30)
    metadata = json.loads(probe.stdout)
    duration = float(metadata['format']['duration'])
    metadata.update(
        sha256=digest, bytes=clip.stat().st_size,
        inspectionStatus='UNACCEPTED_DIAGNOSTIC_ONLY' if diagnostic else 'DURATION_REQUIRED_BELOW',
        captureReportPassed=report.get('passed') is True,
        recordingStopAccepted=event is not None,
        durationCoversAuthored16SecondLoop=duration >= 16,
        recorderStart=start,
        ffprobeWarnings=probe.stderr[-1500:],
        scope='Actual silent Android recording diagnostics; not regenerated widgets, full-motion acceptance, smoothness, physical-device or iOS validation',
    )
    # Always print the actual duration/timestamps BEFORE checking full-loop
    # acceptance, so a rejected short capture remains useful failure evidence.
    print('UI_AMBIENT_RECORDING_METADATA ' + json.dumps(metadata), flush=True)
    if diagnostic:
        packets = subprocess.run([
            'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_packets',
            '-show_entries', 'packet=pts_time,dts_time,duration_time,flags',
            '-of', 'json', str(clip),
        ], check=True, capture_output=True, text=True, timeout=30)
        values = json.loads(packets.stdout).get('packets', [])
        if len(values) > 20000: raise ValueError('Diagnostic packet count exceeded bound')
        timestamps = [float(item['pts_time']) for item in values if 'pts_time' in item]
        summary = {'status': 'UNACCEPTED_DIAGNOSTIC_ONLY', 'count': len(values),
                   'firstPackets': values[:6], 'lastPackets': values[-6:],
                   'minPtsSeconds': min(timestamps) if timestamps else None,
                   'maxPtsSeconds': max(timestamps) if timestamps else None}
        print('UI_AMBIENT_PACKET_TIMESTAMPS ' + json.dumps(summary), flush=True)
        try:
            subprocess.run([
                'ffmpeg', '-nostdin', '-v', 'error', '-xerror', '-err_detect', 'explode',
                '-i', str(clip), '-map', '0:v:0', '-an', '-sn', '-dn', '-f', 'null', '-',
            ], check=True, capture_output=True, text=True, timeout=30)
            verdict = {'wholeVideoDecodePassed': True}
        except subprocess.CalledProcessError as error:
            verdict = {'wholeVideoDecodePassed': False, 'error': error.stderr[-1500:]}
        except subprocess.TimeoutExpired:
            verdict = {'wholeVideoDecodePassed': False, 'error': 'Whole-video diagnostic decode timed out after30s'}
        verdict.update(status='UNACCEPTED_DIAGNOSTIC_ONLY', scope='Complete video-track decode; never duration coercion or full-motion acceptance')
        print('UI_AMBIENT_DIAGNOSTIC_DECODE ' + json.dumps(verdict), flush=True)
        return  # Never sample outside a short clip or accept diagnostic footage.
    if duration < 16:
        raise ValueError('Ambient clip does not cover the authored full 16-second loop')
    output = ROOT / 'ambient-temporal-contact.png'
    subprocess.run([
        'ffmpeg', '-nostdin', '-v', 'error', '-i', str(clip),
        '-vf', 'fps=1/3:start_time=0,scale=240:-2,tile=3x2',
        '-frames:v', '1', '-y', str(output),
    ], check=True, capture_output=True, timeout=40)
    data = output.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data) > 1_500_000:
        raise ValueError('Motion contact PNG signature/size rejected')
    print('UI_AMBIENT_CONTACT_SCOPE Actual encoded-frame samples at nominal0/3/6/9/12/15s; no smoothness claim', flush=True)
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
    drive = ROOT / 'flutter-drive.log'
    if drive.exists():
        matching = [line for line in drive.read_text(errors='replace').splitlines() if 'UI_RECORDED_AURORA_CLOCK ' in line]
        for line in matching[:4]:
            print(line[line.index('UI_RECORDED_AURORA_CLOCK '):][:4000], flush=True)
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
    failure = report.get('presentationFailure')
    if failure and failure.get('name') == '00-home-not-presented':
        expected[failure['name'] + '.png'] = failure['sha256']
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
