#!/usr/bin/env python3
"""Read-only inspection of this repository's diagnostic UI artifact.

Optional PNGs are the exact ADB screenshots, not regenerated widgets. Their SHA
must match the capture host's report. Only original fixture content is captured;
this does not read an owner's phone or arbitrary files from the runner.
"""
import base64
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path('work/ui-capture-inspect')
RESOURCE_PHASES = ('home-ambient-visible', 'diagnostic-static-backdrop-normal', 'diagnostic-static-backdrop-solid')


def inspect_native_profile_resources():
    """Small exact-file summaries, not arbitrary dumpsys/runner-file access."""
    folder = ROOT / 'performance'
    if folder.is_symlink():
        raise ValueError('Native profile resource directory symlink rejected')
    graphics_pattern = re.compile(r'\s*(?:Total frames rendered:\s*\d+|Janky frames(?: \(legacy\))?:\s*\d+\s*\([0-9.]+%\)|(?:50th|90th|95th|99th) percentile:\s*\d+ms)\s*')
    memory_pattern = re.compile(r'\s*(?:(?:Native Heap|Dalvik Heap|TOTAL)\s+\d+(?:\s+\d+)+|(?:Java Heap|Native Heap|Graphics):\s*\d+(?:\s+\d+)*|TOTAL PSS:\s*\d+(?:\s+TOTAL RSS:\s*\d+)?(?:\s+TOTAL SWAP PSS:\s*\d+)?)\s*')
    for phase in RESOURCE_PHASES:
        for suffix in ('android-framestats', 'memory-before', 'memory-after'):
            name = phase + '-' + suffix + '.txt'
            path = folder / name
            result = {'file': name, 'available': False,
                      'scope': 'Android HWUI/window gfxinfo summary is not Flutter Surface presentation/drop measurement. Memory is process PSS/heap/Graphics before or after this phase, not peak or physical-device evidence.'}
            if not path.exists() and not path.is_symlink():
                result['reason'] = 'missing'
            else:
                if path.is_symlink() or not path.is_file() or path.stat().st_size > 65_536:
                    raise ValueError('Native profile resource file unsafe or exceeds64KiB: ' + name)
                data = path.read_bytes()
                pattern = graphics_pattern if suffix == 'android-framestats' else memory_pattern
                lines = [line.strip() for line in data.decode(errors='replace').splitlines() if pattern.fullmatch(line)]
                result.update(available=True, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                              summaryLines=lines, summaryStatus='observed_exact_lines' if lines else 'unavailable_no_matching_summary')
            print('UI_NATIVE_PROFILE_RESOURCES ' + json.dumps(result), flush=True)
INTERACTION_RECORDINGS = (
    '01-root-navigation', '02-home-editor-back', '03-paper-sheet',
    '04-instrument-and-playback', '05-export-ready', '06-reduced-motion',
)


def interaction_contact_names(request):
    names = request.get('interactionContactNames', [])
    if not isinstance(names, list) or len(names) > 2 or any(not isinstance(name, str) or name not in INTERACTION_RECORDINGS for name in names) or len(set(names)) != len(names):
        raise ValueError('Select at most two unique exact interaction recording names')
    if names and request.get('interactionMotionDiagnostic') is not True:
        raise ValueError('Interaction contacts require explicit recording diagnostics')
    return names


def interaction_contact(clip, name, frame_count, remaining_bytes):
    if frame_count < 3:
        raise ValueError('Three distinct original decoded frames required for contact')
    # Decoded-frame ordinals span the actual clip. showinfo reports the actual
    # PTS for each selected frame, rather than assigning synthetic timestamps.
    indices = [0, (frame_count - 1) // 2, frame_count - 1]
    selection = '+'.join(f'eq(n\\,{index})' for index in indices)
    result = subprocess.run([
        'ffmpeg', '-nostdin', '-v', 'info', '-xerror', '-err_detect', 'explode',
        '-i', str(clip), '-map', '0:v:0', '-an', '-sn', '-dn',
        '-vf', f'select={selection},showinfo,scale=220:-2,tile=3x1:padding=2:color=navy',
        '-frames:v', '1', '-f', 'image2pipe', '-vcodec', 'png', 'pipe:1',
    ], check=True, capture_output=True, timeout=30)
    data = result.stdout
    times = [float(value) for value in re.findall(r'\bn:\s*\d+.*?\bpts_time:([-+0-9.eE]+)', result.stderr.decode(errors='replace'))]
    if len(times) != 3 or not all(math.isfinite(value) for value in times) or any(b <= a for a, b in zip(times, times[1:])):
        raise ValueError('Original decoded contact timestamps missing or not distinct')
    if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data) > remaining_bytes:
        raise ValueError('Contact PNG signature/combined byte bound rejected')
    print('UI_INTERACTION_CONTACT_SCOPE ' + json.dumps({
        'name': name, 'status': 'UNACCEPTED_DIAGNOSTIC_ONLY',
        'decodedFrameIndices': indices, 'actualDecodedPtsSeconds': times,
        'scope': 'Three actual decoded original frames at first/middle/last frame; resized only for this contact PNG. Original MP4 unchanged; not smoothness or complete scene acceptance.',
    }), flush=True)
    emit_png(name + '-contact.png', data, motion=True)
    return len(data)


def inspect_interaction_recordings(request, report):
    contacts = interaction_contact_names(request)
    contact_bytes = 0
    diagnostic = request.get('interactionMotionDiagnostic', False)
    if type(diagnostic) is not bool:
        raise ValueError('Expected boolean interactionMotionDiagnostic')
    if not diagnostic:
        return
    folder = ROOT / 'recordings'
    if folder.is_symlink() or not folder.is_dir():
        raise ValueError('Original recordings directory missing or unsafe')
    for name in INTERACTION_RECORDINGS:
        starts = [item for item in report['events'] if item.get('operation') == 'record_start' and item.get('name') == name]
        stops = [item for item in report['events'] if item.get('operation') == 'record_stop' and item.get('name') == name]
        if len(starts) != 1 or len(stops) != 1:
            raise ValueError('Unique original recording start/stop missing: ' + name)
        start, stop = starts[0], stops[0]
        if type(start.get('sequence')) is not int or type(stop.get('sequence')) is not int or not 0 < start['sequence'] < stop['sequence']:
            raise ValueError('Original recording event order invalid: ' + name)
        clip = folder / (name + '.mp4')
        if clip.is_symlink() or not clip.is_file() or not 1000 <= clip.stat().st_size <= 64_000_000:
            raise ValueError('Bounded exact original recording missing: ' + name)
        digest = hashlib.sha256(clip.read_bytes()).hexdigest()
        if clip.stat().st_size != stop.get('bytes') or digest != stop.get('sha256'):
            raise ValueError('Recording bytes/SHA differ from original host manifest: ' + name)
        probe = subprocess.run([
            'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-count_frames', '-count_packets',
            '-show_entries', 'stream=codec_name,width,height,start_time,duration,duration_ts,time_base,r_frame_rate,avg_frame_rate,nb_frames,nb_read_frames,nb_read_packets:format=start_time,duration',
            '-of', 'json', str(clip),
        ], check=True, capture_output=True, text=True, timeout=30)
        metadata = json.loads(probe.stdout)
        duration = float(metadata['format']['duration'])
        if not math.isfinite(duration) or not 0 < duration <= 181 or len(metadata.get('streams', [])) != 1:
            raise ValueError('Original recording metadata outside diagnostic bounds: ' + name)
        stream = metadata['streams'][0]
        if stream.get('codec_name') != 'h264' or not 0 < int(stream['width']) <= 1080 or not 0 < int(stream['height']) <= 2400:
            raise ValueError('Original recording video geometry/codec rejected: ' + name)
        packets = subprocess.run([
            'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_packets',
            '-show_entries', 'packet=pts_time,dts_time,duration_time,flags', '-of', 'json', str(clip),
        ], check=True, capture_output=True, text=True, timeout=30)
        values = json.loads(packets.stdout).get('packets', [])
        if not isinstance(values, list) or not 0 < len(values) <= 20000:
            raise ValueError('Original recording packet count outside bound: ' + name)
        timestamps = [float(item['pts_time']) for item in values]
        decode_timestamps = [float(item['dts_time']) for item in values]
        if not all(math.isfinite(value) for value in timestamps + decode_timestamps) or any(b < a for a, b in zip(decode_timestamps, decode_timestamps[1:])):
            raise ValueError('Original recording PTS/DTS missing/nonfinite or DTS out of order: ' + name)
        evidence = {'name': name, 'status': 'UNACCEPTED_DIAGNOSTIC_ONLY',
                    'captureReportPassed': report.get('passed') is True, 'reportSource': report.get('reportSource'),
                    'bytes': clip.stat().st_size, 'sha256': digest, 'metadata': metadata,
                    'packetCount': len(values), 'firstPackets': values[:3], 'lastPackets': values[-3:],
                    'minPtsSeconds': min(timestamps), 'maxPtsSeconds': max(timestamps),
                    'recorderStart': start, 'recordingStop': stop,
                    'scope': 'Exact original owned interaction video; no padding/retiming, presentation/smoothness or physical/iOS acceptance'}
        print('UI_INTERACTION_RECORDING_METADATA ' + json.dumps(evidence), flush=True)
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
        verdict.update(name=name, status='UNACCEPTED_DIAGNOSTIC_ONLY', scope='Complete original video-track decode; not full visual-suite acceptance')
        print('UI_INTERACTION_DIAGNOSTIC_DECODE ' + json.dumps(verdict), flush=True)
        if name in contacts:
            if not verdict['wholeVideoDecodePassed']:
                raise ValueError('Cannot sample interaction with failed whole-stream decode: ' + name)
            frame_count = int(stream['nb_read_frames'])
            if frame_count != len(values):
                raise ValueError('Contact original decoded-frame/packet count mismatch: ' + name)
            contact_bytes += interaction_contact(clip, name, frame_count, 1_500_000 - contact_bytes)


def load_capture_report(request):
    """Use only the original host's bounded manifest; never infer lost events."""
    final = ROOT / 'capture-report.json'
    partial = not final.exists() and not final.is_symlink()
    if partial and request.get('ambientMotionDiagnostic') is not True:
        raise ValueError('Missing final report; original progress requires explicit diagnostic mode')
    path = ROOT / ('capture-progress.json' if partial else 'capture-report.json')
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 1_048_576:
        raise ValueError('Original bounded capture manifest missing or unsafe: ' + path.name)
    report = json.loads(path.read_text())
    if not isinstance(report, dict) or type(report.get('passed')) is not bool:
        raise ValueError('Capture manifest must contain an original boolean passed state')
    events = report.get('events')
    if not isinstance(events, list) or len(events) > 4096:
        raise ValueError('Capture manifest events missing or excessive')
    for event in events:
        if not isinstance(event, dict) or not isinstance(event.get('operation'), str) or not isinstance(event.get('name'), str):
            raise ValueError('Malformed original capture event')
        if event['operation'] in ('snapshot', 'record_stop'):
            if type(event.get('bytes')) is not int or event['bytes'] <= 0:
                raise ValueError('Original media event byte count missing')
            if not isinstance(event.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}', event['sha256']):
                raise ValueError('Original media event SHA missing')
    if partial and report['passed'] is not False:
        raise ValueError('Progress manifest cannot claim a completed capture pass')
    report['reportSource'] = path.name
    if partial:
        report['inspectionStatus'] = 'UNACCEPTED_DIAGNOSTIC_ONLY'
    return report


def verified_png(name, expected, remaining_bytes):
    if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
        raise ValueError('Screenshot name rejected')
    path = ROOT / 'screenshots' / name
    if path.is_symlink() or not path.is_file() or path.stat().st_size > remaining_bytes:
        raise ValueError('Screenshot missing, unsafe or inspection batch size rejected')
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('PNG signature rejected')
    original = expected.get(name, {})
    if len(data) != original.get('bytes') or hashlib.sha256(data).hexdigest() != original.get('sha256'):
        raise ValueError('Screenshot bytes do not match the original host manifest')
    return data


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
        recordingStopEvidence={key:event.get(key) for key in ('wholeVideoDecode','stopClocks','bytes','sha256')} if event else None,
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
        timing = [line for line in drive.read_text(errors='replace').splitlines()
                  if any(marker in line for marker in ("assembleProfile", 'Built build/app/outputs/flutter-apk/app-profile.apk', 'Installing build/app/outputs/flutter-apk/app-profile.apk'))]
        for line in timing[:12]:
            if 'UI_CAPTURE_TOKEN=' not in line:
                print('UI_PROFILE_BUILD_TIMING ' + line[:2000], flush=True)
    for path in sorted((ROOT / 'performance').glob('*.json')):
        value = json.loads(path.read_text())
        value.pop('rawFrames', None)
        print(f'UI_PERFORMANCE_SUMMARY {path.name} {json.dumps(value)}', flush=True)
    inspect_native_profile_resources()
    for path in sorted((ROOT / 'recordings').glob('*.log'))[:8]:
        if not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.log', path.name):
            raise ValueError('Recording diagnostic name rejected')
        print(f'UI_RECORDING_LOG_BEGIN {path.name}', flush=True)
        for line in path.read_text(errors='replace').splitlines()[-80:]:
            print(re.sub(r'DrawMusicCapture-[0-9a-f]{32}-', 'DrawMusicCapture-[redacted]-', line[:1000]), flush=True)
        print(f'UI_RECORDING_LOG_END {path.name}', flush=True)
    screenshots = request.get('screenshots', [])
    if not isinstance(screenshots, list) or len(screenshots) > 5:
        raise ValueError('Select at most five exact acceptance PNG names per read-only inspection')
    report = load_capture_report(request)
    print('UI_CAPTURE_REPORT_SOURCE ' + json.dumps({key: report.get(key) for key in ('reportSource', 'passed', 'inspectionStatus')}), flush=True)
    # Encoder/clock diagnosis is independent of PNG display/log-size limits.
    inspect_ambient_recording(request, report)
    inspect_interaction_recordings(request, report)
    expected = {item['name'] + '.png': item for item in report.get('events', []) if item.get('operation') == 'snapshot'}
    failure = report.get('presentationFailure')
    if failure and failure.get('name') == '00-home-not-presented':
        expected[failure['name'] + '.png'] = failure
    total = 0
    sizes = []
    for name in screenshots:
        if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
            raise ValueError('Screenshot name rejected')
        sizes.append({'name': name, 'bytes': (ROOT / 'screenshots' / name).stat().st_size})
    print('UI_CAPTURE_PNG_REQUEST_SIZES ' + json.dumps({'images': sizes, 'totalBytes': sum(item['bytes'] for item in sizes), 'maxBytes': 1_500_000}), flush=True)
    for name in screenshots:
        if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
            raise ValueError('Screenshot name rejected')
        data = verified_png(name, expected, 1_500_000 - total)
        total += len(data)
        emit_png(name, data)


if __name__ == '__main__':
    main()
