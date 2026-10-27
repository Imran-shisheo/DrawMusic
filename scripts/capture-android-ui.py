#!/usr/bin/env python3
"""Actual screen/performance capture on this job's disposable QEMU only.

The diagnostic profile target talks only through an authenticated localhost ADB
reverse tunnel. Normal lib/main.dart has no capture server/network dependency.
"""
import hashlib
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import threading
import time

DEVICE = 'emulator-5554'
PACKAGE = 'com.imranshisheo.scribblesong'
OUTPUT = Path('work/ui-capture')


def adb(*args, binary=False, required=True, timeout=35):
    result = subprocess.run(['adb', '-s', DEVICE, *args], capture_output=True,
                            text=not binary, timeout=timeout, check=False)
    if required and result.returncode:
        error = result.stderr.decode(errors='replace') if binary else result.stderr
        raise RuntimeError(f'Owned emulator {args[0]} failed: {error[-500:]}')
    return result


def slug(value):
    if not isinstance(value, str) or not re.fullmatch(r'[a-z0-9-]{1,80}', value):
        raise ValueError('Invalid capture artifact name')
    return value


def optional_dump(*args):
    try:
        return adb('shell', *args, required=False, timeout=5).stdout
    except subprocess.TimeoutExpired:
        return 'Optional owned-emulator diagnostic timed out after5s\n'


def presented_scene_evidence(png):
    """Reject the observed flat native splash, not a visual-design acceptance."""
    decoded = subprocess.run([
        'ffmpeg', '-nostdin', '-v', 'error', '-i', 'pipe:0',
        '-vf', 'crop=iw*0.8:ih*0.7:iw*0.1:ih*0.15,scale=64:112',
        '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1',
    ], input=png, capture_output=True, check=True, timeout=10).stdout
    if len(decoded) != 64 * 112 * 3:
        raise RuntimeError('Actual compositor PNG could not be sampled')
    pixels = [tuple(decoded[i:i+3]) for i in range(0, len(decoded), 3)]
    dominant = Counter(pixels).most_common(1)[0][0]
    varied = sum(sum(abs(a-b) for a,b in zip(pixel, dominant)) > 30 for pixel in pixels)
    return {'centralForegroundRatio': varied / len(pixels),
            'centralDominantRgb': list(dominant),
            'scope': 'Actual compositor central pixel coverage; rejects the observed flat splash, not design or motion acceptance'}


def decode_recording(target):
    started = time.monotonic()
    try:
        subprocess.run([
            'ffmpeg', '-nostdin', '-v', 'error', '-xerror', '-err_detect', 'explode',
            '-i', str(target), '-map', '0:v:0', '-an', '-sn', '-dn', '-f', 'null', '-',
        ], check=True, capture_output=True, text=True, timeout=30)
    except subprocess.CalledProcessError as error:
        raise RuntimeError('Whole MP4 video decode failed: ' + error.stderr[-1500:]) from error
    return {'passed': True, 'decoder': 'ffmpeg -xerror -err_detect explode',
            'elapsedSeconds': time.monotonic() - started, 'timeoutSeconds': 30,
            'scope': 'Actual complete video-track software decode to null output; not audio, physical presentation/smoothness or iOS validation'}


class Capture:
    def __init__(self):
        self.token = secrets.token_hex(16)
        self.sequence = 0
        self.lock = threading.Lock()
        self.recording = None
        self.perf = None
        self.complete = False
        self.report = {'passed': False, 'scope': 'Owned API35 QEMU profile-build screenshots, silent interaction recordings and real engine timings; not phone/iOS acceptance', 'events': [], 'recordingsHaveAudio': False}

    def record_start(self, name):
        if self.recording or adb('shell', 'pidof', 'screenrecord', required=False).stdout.strip():
            raise RuntimeError('Another screen recording is active')
        attempts = []
        for width, height, bitrate in ((720, 1600, 4000000), (432, 960, 2000000)):
            remote = f'/sdcard/Download/DrawMusicCapture-{self.token}-{name}-{width}x{height}.mp4'
            path = OUTPUT / 'recordings' / f'{name}.log'
            attempt_offset = path.stat().st_size if path.exists() else 0
            log = path.open('a')
            log.write(f'Owned codec startup attempt {width}x{height}\n'); log.flush()
            process = subprocess.Popen(['adb', '-s', DEVICE, 'shell', 'screenrecord', '--verbose', '--bit-rate', str(bitrate), '--size', f'{width}x{height}', '--time-limit', '180', remote], stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 8
            verified_since = None
            pid = ''
            while process.poll() is None and time.monotonic() < deadline:
                pid = adb('shell', 'pidof', 'screenrecord', required=False).stdout.strip()
                if re.fullmatch(r'\d+', pid):
                    cmd = adb('shell', 'cat', f'/proc/{pid}/cmdline', required=False).stdout
                    if remote not in cmd:
                        log.close()
                        raise RuntimeError('Recorder startup identity differs; refusing signal/fallback')
                    if verified_since is None: verified_since = time.monotonic()
                    if time.monotonic() - verified_since >= 1.5:
                        settings = {'width': width, 'height': height, 'bitrate': bitrate,
                                    'startupOwnershipVerifiedSeconds': 1.5, 'codecFallbackAttempts': attempts}
                        self.recording = (name, remote, pid, process, log, settings)
                        return settings
                else:
                    verified_since = None
                time.sleep(.1)
            if process.poll() is None:
                cmd = adb('shell', 'cat', f'/proc/{pid}/cmdline', required=False).stdout if re.fullmatch(r'\d+', pid) else ''
                if remote in cmd:
                    adb('shell', 'kill', '-2', pid)
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired: process.terminate()
                log.close()
                raise RuntimeError('Owned recorder startup did not stabilize within8s; no speculative fallback')
            process.wait(timeout=3); log.close()
            tail = path.read_bytes()[attempt_offset:].decode(errors='replace')[-4000:].replace(self.token, '[redacted]')
            attempts.append({'width': width, 'height': height, 'exitCode': process.returncode, 'diagnostic': tail})
            adb('shell', 'rm', '-f', remote)
            if 'unable to configure video/avc codec' not in tail:
                raise RuntimeError(f'Owned recorder exited before startup: {tail[-800:]}')
        raise RuntimeError(f'Both bounded AVC resolutions failed: {attempts}')

    def record_stop(self):
        if not self.recording:
            raise RuntimeError('No owned recording is active')
        name, remote, pid, process, log, settings = self.recording
        self.recording = None
        try:
            cmd = adb('shell', 'cat', f'/proc/{pid}/cmdline', required=False).stdout
            if remote not in cmd:
                log.flush()
                tail = Path(log.name).read_text(errors='replace')[-2000:].replace(self.token, '[redacted]')
                raise RuntimeError(f'Recording exited or identity changed; refusing signal (exit={process.poll()}): {tail[-1000:]}')
            adb('shell', 'kill', '-2', pid)
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.terminate()
                raise RuntimeError('Screen recording did not finalize within20s')
        finally:
            log.close()
        target = OUTPUT / 'recordings' / f'{name}.mp4'
        adb('pull', remote, str(target), timeout=20)
        adb('shell', 'rm', '-f', remote)
        if target.stat().st_size < 1000:
            raise RuntimeError('No real screen recording was produced')
        probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
            '-show_entries', 'stream=codec_name,width,height,nb_frames:format=duration',
            '-of', 'json', str(target)], check=True, capture_output=True, text=True, timeout=10)
        metadata = json.loads(probe.stdout)
        stream = metadata.get('streams', [{}])[0]
        duration = float(metadata.get('format', {}).get('duration', 0))
        if stream.get('codec_name') != 'h264' or duration <= 0 or (stream.get('width'), stream.get('height')) != (settings['width'], settings['height']):
            raise RuntimeError('MP4 metadata does not identify the requested real AVC video')
        if name == '00-home-ambient' and duration < 16:
            raise RuntimeError('Actual ambient MP4 did not cover the authored16s loop')
        decoded = decode_recording(target)
        return {'file': str(target), 'bytes': target.stat().st_size, 'audio': False,
                'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                'codec': metadata, 'wholeVideoDecode': decoded, 'recorderSettings': settings}

    def event(self, body):
        with self.lock:
            if body.get('token') != self.token or body.get('sequence') != self.sequence + 1:
                raise ValueError('Capture authentication/sequence rejected')
            self.sequence += 1
            operation, name = body.get('operation'), slug(body.get('name'))
            item = {'sequence': self.sequence, 'operation': operation, 'name': name, 'hostMonotonicSeconds': time.monotonic()}
            if operation == 'snapshot':
                deadline = time.monotonic() + 20
                attempts = 0
                while True:
                    result = adb('exec-out', 'screencap', '-p', binary=True)
                    if not result.stdout.startswith(b'\x89PNG\r\n\x1a\n'):
                        raise RuntimeError('ADB did not return an actual PNG screenshot')
                    if name != '01-home' or self.report.get('source', {}).get('label') != 'after': break
                    attempts += 1
                    if attempts == 1:
                        (OUTPUT / 'window-before-first-home.txt').write_text(optional_dump('dumpsys', 'window', 'windows'))
                        (OUTPUT / 'surface-layers-before-first-home.txt').write_text(optional_dump('dumpsys', 'SurfaceFlinger', '--list'))
                    evidence = presented_scene_evidence(result.stdout)
                    item.update(presentation=evidence, compositorReadinessAttempts=attempts)
                    if evidence['centralForegroundRatio'] >= .02:
                        (OUTPUT / 'surface-layers-home-presented.txt').write_text(optional_dump('dumpsys', 'SurfaceFlinger', '--list'))
                        break
                    # Preserve the exact last failed compositor image as evidence.
                    (OUTPUT / 'screenshots' / '00-home-not-presented.png').write_bytes(result.stdout)
                    self.report['presentationFailure'] = {
                        'name': '00-home-not-presented', 'sha256': hashlib.sha256(result.stdout).hexdigest(),
                        'bytes': len(result.stdout), 'attempts': attempts, 'presentation': evidence}
                    if time.monotonic() >= deadline:
                        raise RuntimeError(f'Home widget tree loaded but actual compositor remains flat/native splash after20s: {evidence}')
                    time.sleep(.5)
                target = OUTPUT / 'screenshots' / f'{name}.png'
                target.write_bytes(result.stdout)
                item.update(file=str(target), bytes=len(result.stdout), sha256=hashlib.sha256(result.stdout).hexdigest())
            elif operation == 'record_start':
                item.update(self.record_start(name))
            elif operation == 'record_stop':
                if not self.recording or self.recording[0] != name:
                    raise ValueError('Recording name mismatch')
                item.update(self.record_stop())
            elif operation == 'perf_start':
                if self.recording or self.perf:
                    raise RuntimeError('Profile phase must run without screenrecord or overlapping phases')
                self.perf = name
                adb('shell', 'dumpsys', 'gfxinfo', PACKAGE, 'reset')
                (OUTPUT / 'performance' / f'{name}-memory-before.txt').write_text(adb('shell', 'dumpsys', 'meminfo', PACKAGE).stdout)
            elif operation == 'perf_finish':
                if self.perf != name or not isinstance(body.get('result'), dict):
                    raise ValueError('Missing real performance result')
                self.perf = None
                result = body['result']
                if not result.get('rawFrames'):
                    raise ValueError('No real Flutter frame samples')
                (OUTPUT / 'performance' / f'{name}.json').write_text(json.dumps(result, indent=2) + '\n')
                (OUTPUT / 'performance' / f'{name}-android-framestats.txt').write_text(adb('shell', 'dumpsys', 'gfxinfo', PACKAGE, 'framestats').stdout)
                (OUTPUT / 'performance' / f'{name}-memory-after.txt').write_text(adb('shell', 'dumpsys', 'meminfo', PACKAGE).stdout)
                item.update(frameSamples=len(result['rawFrames']), recordingDuringMeasurement=False,
                            pssScope='Before/after whole-app process snapshots, not measured peak or physical-device memory')
            elif operation == 'display':
                displays = {'phone': ('1080x2400', '420', '1.0'), 'compact': ('640x1280', '320', '2.0'), 'tablet': ('1600x2400', '240', '1.0')}
                if name not in displays or self.recording or self.perf:
                    raise ValueError('Invalid display preset or capture phase')
                size, density, scale = displays[name]
                adb('shell', 'wm', 'size', size)
                adb('shell', 'wm', 'density', density)
                adb('shell', 'settings', 'put', 'system', 'font_scale', scale)
                item.update(physicalSize=size, densityDpi=density, systemFontScale=scale)
            elif operation == 'metadata':
                if body.get('buildMode') != 'profile' or body.get('animationsDisabled') is not False:
                    raise ValueError('Capture must use profile mode with animations enabled')
                self.report['appMetadata'] = {key: value for key, value in body.items() if key not in ('token', 'sequence')}
            elif operation == 'complete':
                if body.get('passed') is not True or self.recording or self.perf:
                    raise ValueError('Incomplete capture session')
                self.complete = True
            else:
                raise ValueError('Unsupported capture operation')
            self.report['events'].append(item)
            (OUTPUT / 'capture-progress.json').write_text(json.dumps(self.report, indent=2) + '\n')
            print(f'Actual UI capture: {operation} / {name}', flush=True)
            return {'ok': True, 'sequence': self.sequence}


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Only the disposable GitHub Actions emulator is authorized')
    if adb('shell', 'getprop', 'ro.kernel.qemu').stdout.strip() != '1':
        raise RuntimeError('QEMU identity check rejected device operation')
    for folder in ('screenshots', 'recordings', 'performance'):
        (OUTPUT / folder).mkdir(parents=True, exist_ok=True)
    provenance = json.loads((OUTPUT / 'source-provenance.json').read_text())
    capture = Capture()
    capture.report['source'] = provenance

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            try:
                if self.path != '/event' or not 0 < int(self.headers.get('Content-Length', '0')) <= 2_000_000:
                    raise ValueError('Invalid local capture request')
                body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                result = capture.event(body)
                self.send_response(200)
            except Exception as error:
                capture.report['hostError'] = str(error)
                result = {'ok': False, 'error': str(error)}
                self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        def log_message(self, *_):
            pass  # Do not log auth payloads or request bodies.

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    adb('reverse', f'tcp:{port}', f'tcp:{port}')
    for key in ('window_animation_scale', 'transition_animation_scale', 'animator_duration_scale'):
        adb('shell', 'settings', 'put', 'global', key, '1.0')
        if float(adb('shell', 'settings', 'get', 'global', key).stdout.strip()) != 1:
            raise RuntimeError('System animation scale is not enabled')
    adb('shell', 'wm', 'size', '1080x2400')
    adb('shell', 'wm', 'density', '420')
    adb('shell', 'settings', 'put', 'system', 'font_scale', '1.0')
    # Fresh owned diagnostic app data; never an owner's existing installation.
    adb('shell', 'am', 'force-stop', PACKAGE, required=False)
    adb('uninstall', PACKAGE, required=False)
    command = ['flutter', 'drive', '--profile', '--no-pub', '-d', DEVICE,
               '--driver=test_driver/ui_visual_capture_driver.dart',
               '--target=integration_test/ui_visual_capture_test.dart',
               f'--dart-define=UI_CAPTURE_TOKEN={capture.token}',
               f'--dart-define=UI_CAPTURE_PORT={port}',
               f'--dart-define=UI_CAPTURE_LABEL={provenance["label"]}']
    try:
        # Do not print this command: the one-job localhost capability is private.
        with (OUTPUT / 'flutter-drive.log').open('w') as log:
            run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=900, check=False)
        if run.returncode or not capture.complete or capture.report.get('hostError'):
            raise RuntimeError(f'Profile UI capture failed (exit {run.returncode}); see flutter-drive.log')
        capture.report['passed'] = True
    except Exception as error:
        capture.report['error'] = str(error)
        log = OUTPUT / 'flutter-drive.log'
        if log.exists():
            print('Actual profile test failure log:', flush=True)
            for line in log.read_text(errors='replace').splitlines()[-150:]:
                if 'UI_CAPTURE_TOKEN=' not in line:
                    print(line, flush=True)
        raise
    finally:
        if capture.recording:
            try:
                capture.record_stop()
            except Exception as error:
                capture.report['recordingCleanupError'] = str(error)
        (OUTPUT / 'android-logcat.txt').write_text(adb('logcat', '-d', '-s', 'AndroidRuntime', 'flutter', required=False).stdout)
        (OUTPUT / 'capture-report.json').write_text(json.dumps(capture.report, indent=2) + '\n')
        adb('reverse', '--remove', f'tcp:{port}', required=False)
        server.shutdown()
        server.server_close()
        print(json.dumps({'passed': capture.report['passed'], 'events': len(capture.report['events']), 'scope': capture.report['scope']}), flush=True)


if __name__ == '__main__':
    main()
