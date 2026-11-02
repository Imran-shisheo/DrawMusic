#!/usr/bin/env python3
"""Actual screen/performance capture on this job's disposable QEMU only.

The diagnostic profile target talks only through an authenticated localhost ADB
reverse tunnel. Normal lib/main.dart has no capture server/network dependency.
"""
import hashlib
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import secrets
import subprocess
import threading
import time

from ui_capture_mp4 import encoded_avc_readiness
from runtime_transport_diagnostics import safe_snapshot

DEVICE = 'emulator-5554'
PACKAGE = 'com.devwithdelta.doodimo'
OUTPUT = Path('work/ui-capture')
PROFILE_PROCESS_TIMEOUT_SECONDS = 1200


def safe_capture_error(error, token):
    if isinstance(error, subprocess.TimeoutExpired):
        # TimeoutExpired.__str__ includes the complete command, including the
        # one-job loopback capability. Report the bound, never its command.
        return f'Capture subprocess exceeded {round(float(error.timeout))}s; capture incomplete.'
    return f'{type(error).__name__}: {str(error).replace(token, "[redacted]")}'[:2000]


def raise_capture_failure(error, token):
    raise RuntimeError(safe_capture_error(error, token)) from None


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


def host_cpu_context():
    """Only processor count/quota/model; never host IDs or full environment."""
    def text(path):
        try: return Path(path).read_text().strip()
        except OSError: return None
    try:
        value = subprocess.run(['nproc'], capture_output=True, text=True, timeout=2, check=True).stdout.strip()
        processors = int(value) if value.isdigit() else None
    except (OSError, ValueError, subprocess.SubprocessError): processors = None
    cpuinfo = text('/proc/cpuinfo') or ''
    model = next((line.split(':', 1)[1].strip() for line in cpuinfo.splitlines() if line.startswith('model name') and ':' in line), None)
    return {'nproc': processors, 'cgroupCpuMax': text('/sys/fs/cgroup/cpu.max'),
            'cpuModel': model, 'scope': 'Actual host CPU context; missing fields remain null, no machine IDs'}


PROBE_PROFILES = ('diagnostic-static-backdrop-normal', 'diagnostic-static-backdrop-solid')
RESPONSIVE_SHOTS = {
    'compact': ('16-home-compact-large-text', '17-editor-compact-large-text'),
    'tablet': ('18-home-tablet', '19-editor-tablet'),
    'light': ('22-home-light', '23-editor-light'),
}
INITIAL_DISPLAYS = {
    'compact': ('640x1280', '320', '2.0'),
    'tablet': ('1600x2400', '240', '1.0'),
    'light': ('1080x2400', '420', '1.0'),
} # Applied before Flutter/app process launch, never to a live VM service.



HOME_PROFILE_EVENTS = (
    ('metadata', 'session'), ('snapshot', '01-home'),
    ('perf_start', 'home-ambient-visible'), ('diagnostic', 'home-motion-clock'),
    ('perf_finish', 'home-ambient-visible'), ('record_start', '00-home-ambient'),
    ('record_stop', '00-home-ambient'), ('home_profile_complete', 'home-profile'),
)
TRANSITION_CLIPS = ('01-root-navigation', '06-reduced-motion')
TRANSITION_EVENTS = (('metadata', 'session'), ('snapshot', '01-home'),
    ('record_start', TRANSITION_CLIPS[0]), ('record_stop', TRANSITION_CLIPS[0]), ('transition_trace', TRANSITION_CLIPS[0]),
    ('record_start', TRANSITION_CLIPS[1]), ('record_stop', TRANSITION_CLIPS[1]), ('transition_trace', TRANSITION_CLIPS[1]),
    ('transition_complete', 'transitions'))
TRANSITION_ACTIONS = ('root-library', *('library-normal-' + str(i) for i in range(4)),
    *('library-rapid-' + str(i) for i in range(6)), 'root-settings', 'root-home',
    'root-library-return', 'root-home-editor', 'editor-open', 'editor-back',
    'sheet-editor-open', 'sheet-tools-open', 'sheet-paper-open', 'sheet-close', 'sheet-editor-back')

GRAPHITE_CLIPS = ('00-graphite-opening', '01-root-navigation', '02-editor-instrument', '05-export-ready', '06-reduced-motion')
GRAPHITE_SHOTS = ('01-home', '02-drafts', '03-exports', '04-settings', '24-graphite-editor', '08-instruments', '10-export-selection', '11-export-ready', '15-home-reduced-motion')
GRAPHITE_ACTIONS = {
    '01-root-navigation': ('root-library', *('library-normal-' + str(i) for i in range(4)),
        *('library-rapid-' + str(i) for i in range(6)), 'root-settings', 'root-home'),
    '02-editor-instrument': ('artwork-open', 'canvas-first-input', 'voice-open', 'voice-bell', 'play', 'pause',
        'music-open', 'music-close', 'tools-open', 'tools-close', 'background-open', 'background-close',
        'editor-back', 'rapid-artwork-reopen', 'rapid-play', 'rapid-pause', 'rapid-back'),
    '05-export-ready': ('cancel-format-video', 'cancel-start', 'cancel-job', 'error-format-image', 'error-start', 'retry-export'),
    '06-reduced-motion': ('system-library', 'system-exports', 'system-drafts', 'system-home',
        'stored-library', 'stored-exports', 'stored-drafts', 'stored-home'),
}
GRAPHITE_EVENTS = (
    ('metadata', 'session'), ('record_start', GRAPHITE_CLIPS[0]), ('record_stop', GRAPHITE_CLIPS[0]),
    ('graphite_opening', 'opening'), ('snapshot', '01-home'),
    ('perf_start', 'graphite-interactions-unrecorded'), ('perf_finish', 'graphite-interactions-unrecorded'),
    ('record_start', GRAPHITE_CLIPS[1]), ('record_stop', GRAPHITE_CLIPS[1]), ('graphite_trace', GRAPHITE_CLIPS[1]),
    ('snapshot', '02-drafts'), ('snapshot', '03-exports'), ('snapshot', '04-settings'),
    ('record_start', GRAPHITE_CLIPS[2]), ('record_stop', GRAPHITE_CLIPS[2]), ('graphite_trace', GRAPHITE_CLIPS[2]),
    ('snapshot', '24-graphite-editor'), ('snapshot', '08-instruments'), ('snapshot', '10-export-selection'),
    ('record_start', GRAPHITE_CLIPS[3]), ('record_stop', GRAPHITE_CLIPS[3]), ('graphite_trace', GRAPHITE_CLIPS[3]),
    ('snapshot', '11-export-ready'),
    ('record_start', GRAPHITE_CLIPS[4]), ('system_motion', 'reduced'), ('system_motion', 'normal'),
    ('record_stop', GRAPHITE_CLIPS[4]), ('graphite_trace', GRAPHITE_CLIPS[4]),
    ('snapshot', '15-home-reduced-motion'), ('graphite_complete', 'graphite'),
)
MOTION_SETTINGS = ('window_animation_scale', 'transition_animation_scale', 'animator_duration_scale')


class Capture:
    def __init__(self, *, static_backdrop_probe=False, responsive_preset=None, home_profile_only=False, transition_capture_only=False, graphite_capture=False):
        if type(graphite_capture) is not bool or (graphite_capture and (static_backdrop_probe or responsive_preset is not None or home_profile_only or transition_capture_only)):
            raise ValueError('Unknown or conflicting graphite mode')
        self.graphite_capture = graphite_capture
        self.graphite_traces = []
        self.graphite_opening = False
        self.graphite_system_motion = None
        if type(transition_capture_only) is not bool or (transition_capture_only and (static_backdrop_probe or responsive_preset is not None or home_profile_only)):
            raise ValueError('Unknown or conflicting transition subset mode')
        self.transition_capture_only = transition_capture_only
        self.transition_traces = []
        if type(home_profile_only) is not bool or (home_profile_only and (static_backdrop_probe or responsive_preset is not None)):
            raise ValueError('Unknown or conflicting Home profile subset mode')
        if responsive_preset not in (None, *RESPONSIVE_SHOTS) or (static_backdrop_probe and responsive_preset is not None):
            raise ValueError('Unknown or conflicting responsive/probe mode')
        self.responsive_preset = responsive_preset
        self.home_profile_only = home_profile_only
        self.responsive_snapshots = []
        self.token = secrets.token_hex(16)
        self.sequence = 0
        self.lock = threading.Lock()
        self.recording = None
        self.perf = None
        self.complete = False
        self.static_backdrop_probe = static_backdrop_probe
        self.probe_profiles = []
        self.probe_restored = False
        self.probe_cache_size = None
        self.report = {'passed': False, 'scope': 'Owned API35 QEMU profile-build screenshots, silent interaction recordings and real engine timings; not phone/iOS acceptance', 'events': [], 'recordingsHaveAudio': False}
        if graphite_capture:
            self.report.update(scope='Actual graphite production launch mount, Hero/input, retained tabs, panels/export and reduced-motion subset; initial recording excludes OS/VM startup, unrecorded interaction engine timings are separate; not physical/audio/iOS smoothness acceptance',
                graphiteCapture=True, graphiteSubsetPassed=False, normalFullCapturePassed=False)
        if transition_capture_only:
            self.report.update(scope='Actual normal/reduced transition recordings with real taps, not full23 capture, profiling, smoothness or physical/iOS acceptance',
                transitionCaptureOnly=True, transitionSubsetPassed=False, normalFullCapturePassed=False)
        if home_profile_only:
            self.report.update(scope='Normal unchanged Home screenshot, unrecorded engine profile and actual ambient video subset; not full23 capture, smoothness or physical/iOS acceptance',
                               homeProfileOnly=True, homeProfileSubsetPassed=False, normalFullCapturePassed=False)

        if responsive_preset is not None:
            self.report.update(scope='Actual responsive screenshot subset only; not full23 capture, performance, audio, physical-device or iOS acceptance',
                               responsivePreset=responsive_preset, responsiveSubsetPassed=False, normalFullCapturePassed=False)
        if static_backdrop_probe:
            self.report.update(scope='Diagnostic-only same-run static radial-backdrop A/B; not normal product capture or smoothness/device acceptance',
                               diagnosticOnly=True, normalProductCapturePassed=False, normalFootageProduced=False)

    def _write_graphite_json(self, relative, value):
        allowed = {'graphite-opening.json', 'performance/graphite-interactions-unrecorded.json',
                   *('graphite-' + name + '.json' for name in GRAPHITE_CLIPS[1:])}
        if relative not in allowed:
            raise ValueError('Undeclared graphite evidence path')
        data = (json.dumps(value, indent=2)+'\n').encode()
        limit = 1_048_576 if relative.startswith('performance/') else 65_536
        if not 0 < len(data) <= limit:
            raise ValueError('Graphite evidence exceeds bounded diagnostic size')
        (OUTPUT / relative).write_bytes(data)
        return {'evidenceFile': relative, 'evidenceBytes': len(data), 'evidenceSha256': hashlib.sha256(data).hexdigest()}

    def _cleanup_failed_start(self, remote, pid, process, log, error):
        diagnostic = {'error': str(error).replace(self.token, '[redacted]'),
                      'nativeSignalSent': False, 'ownedAdbTerminated': False}
        try:
            if process.poll() is None:
                try:
                    cmd = adb('shell', 'cat', f'/proc/{pid}/cmdline', required=False, timeout=2).stdout
                    if remote in cmd:
                        adb('shell', 'kill', '-2', pid, timeout=2)
                        diagnostic['nativeSignalSent'] = True
                    else:
                        diagnostic['nativeIdentityChanged'] = True
                except Exception as cleanup_error:
                    diagnostic['identityOrSignalError'] = str(cleanup_error).replace(self.token, '[redacted]')[-500:]
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    # This Popen is the exact ADB child created here, never a
                    # discovered/reused native PID. Unknown native identity is
                    # never signaled, even during failed-start cleanup.
                    process.terminate()
                    diagnostic['ownedAdbTerminated'] = True
                    try: process.wait(timeout=1)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        diagnostic['ownedAdbKilledAfterTerminateTimeout'] = True
                        try: process.wait(timeout=1)
                        except subprocess.TimeoutExpired:
                            diagnostic['ownedAdbWaitTimedOut'] = True
        except Exception as cleanup_error:
            diagnostic['cleanupError'] = str(cleanup_error).replace(self.token, '[redacted]')[-500:]
        finally:
            try:
                log.flush()
                diagnostic['logTail'] = Path(log.name).read_text(errors='replace')[-2000:].replace(self.token, '[redacted]')
            except Exception as log_error:
                diagnostic['logError'] = str(log_error)[-500:]
            finally:
                try: log.close()
                except Exception as log_error: diagnostic['logCloseError'] = str(log_error)[-500:]
                self.report.setdefault('recorderStartupFailures', []).append(diagnostic)

    def _await_encoded_media(self, remote, pid, process):
        deadline = time.monotonic() + 25
        last = {'ready': False, 'reason': 'No output file yet'}
        while time.monotonic() < deadline:
            cmd = adb('shell', 'cat', f'/proc/{pid}/cmdline', required=False, timeout=3).stdout
            if process.poll() is not None or remote not in cmd:
                raise RuntimeError('Recorder exited/identity changed before encoded media; refusing signal')
            size = adb('shell', 'stat', '-c', '%s', remote, required=False, timeout=3).stdout.strip()
            if size.isdigit():
                def read_at(offset, count):
                    if count <= 0 or time.monotonic() >= deadline: return b''
                    block, within = divmod(offset, 4096)
                    blocks = (within + count + 4095) // 4096
                    output = adb('exec-out', 'dd', f'if={remote}', 'bs=4096',
                                 f'skip={block}', f'count={blocks}', binary=True, required=False, timeout=3).stdout
                    return output[within:within+count]
                last = encoded_avc_readiness(read_at, int(size))
                if last['ready']:
                    last.update(hostReadyMonotonicSeconds=time.monotonic(),
                                guestUptimeAtReadiness=optional_dump('cat', '/proc/uptime').strip())
                    return last
            time.sleep(.3)
        # The caller performs bounded ownership-guarded cleanup for every
        # encoded-readiness failure, including this timeout.
        raise RuntimeError(f'Actual encoded AVC media not ready within25s: {last}')

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
            start_clock = {'hostStartedMonotonicSeconds': time.monotonic(),
                           'guestUptimeBeforeStart': optional_dump('cat', '/proc/uptime').strip()}
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
                        try:
                            media = self._await_encoded_media(remote, pid, process)
                        except Exception as error:
                            self._cleanup_failed_start(remote, pid, process, log, error)
                            raise
                        settings = {'width': width, 'height': height, 'bitrate': bitrate,
                                    'startupOwnershipVerifiedSeconds': 1.5, 'codecFallbackAttempts': attempts,
                                    'startupClocks': start_clock, 'firstEncodedVideo': media}
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
        stop_clock = {'hostStopRequestedMonotonicSeconds': time.monotonic(),
                      'guestUptimeBeforeStop': optional_dump('cat', '/proc/uptime').strip()}
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
        # Persist failure metadata too; rejected short clips remain diagnosable
        # without weakening or retiming their duration.
        (OUTPUT / 'recordings' / f'{name}-inspection.json').write_text(json.dumps({
            'status': 'PENDING_ACCEPTANCE', 'codec': metadata, 'recorderSettings': settings,
            'stopClocks': stop_clock, 'bytes': target.stat().st_size}, indent=2)+'\n')
        if stream.get('codec_name') != 'h264' or duration <= 0 or (stream.get('width'), stream.get('height')) != (settings['width'], settings['height']):
            raise RuntimeError('MP4 metadata does not identify the requested real AVC video')
        if name == '00-home-ambient' and duration < 16:
            raise RuntimeError(f'Actual ambient MP4 duration={duration}s did not cover authored16s loop; stopClocks={stop_clock}')
        decoded = decode_recording(target)
        return {'file': str(target), 'bytes': target.stat().st_size, 'audio': False,
                'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                'codec': metadata, 'wholeVideoDecode': decoded, 'recorderSettings': settings, 'stopClocks': stop_clock}

    def event(self, body):
        with self.lock:
            if body.get('token') != self.token or body.get('sequence') != self.sequence + 1:
                raise ValueError('Capture authentication/sequence rejected')
            self.sequence += 1
            operation, name = body.get('operation'), slug(body.get('name'))
            item = {'sequence': self.sequence, 'operation': operation, 'name': name, 'hostMonotonicSeconds': time.monotonic()}
            if self.graphite_capture:
                index = len(self.report['events'])
                if index >= len(GRAPHITE_EVENTS) or (operation, name) != GRAPHITE_EVENTS[index]:
                    raise ValueError('Graphite capture requires exactly its ordered original operations')
            if self.transition_capture_only:
                index = len(self.report['events'])
                if index >= len(TRANSITION_EVENTS) or (operation, name) != TRANSITION_EVENTS[index]:
                    raise ValueError('Transition subset requires exactly its ordered original operations')
            if self.home_profile_only:
                index = len(self.report['events'])
                if index >= len(HOME_PROFILE_EVENTS) or (operation, name) != HOME_PROFILE_EVENTS[index]:
                    raise ValueError('Home profile subset requires exactly its ordered original operations')
            if self.responsive_preset is not None:
                if operation not in ('metadata', 'snapshot', 'responsive_complete'):
                    raise ValueError('Responsive subset rejects recording profiling live display and full completion')
                if operation == 'snapshot':
                    wanted = RESPONSIVE_SHOTS[self.responsive_preset]
                    if len(self.responsive_snapshots) >= 2 or name != wanted[len(self.responsive_snapshots)]:
                        raise ValueError('Responsive subset requires exactly its ordered two screenshots')
            if self.static_backdrop_probe and operation not in ('metadata', 'perf_start', 'perf_finish', 'static_backdrop_restored', 'diagnostic_complete'):
                raise ValueError('Probe-only host rejects normal screenshots recordings and completion')
            if operation == 'snapshot':
                if self.graphite_capture:
                    # All nine graphite stills are separate revisits after the
                    # owned recorder has exited and its original MP4 decoded.
                    # Reject before ANY screencap/ADB work, even if a future
                    # caller accidentally changes the ordered protocol.
                    if self.recording is not None or self.perf is not None:
                        raise ValueError('Graphite snapshot requires no owned recorder or profile phase')
                    item['snapshotCaptureState'] = {
                        'ownedRecorderActive': False, 'profileActive': False}
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
                readiness = body.get('screenshotReadiness')
                if readiness is not None:
                    if (not isinstance(readiness, dict) or
                            len(json.dumps(readiness).encode()) > 16_384 or
                            readiness.get('expectedScene') != name or
                            type(readiness.get('matchedEngineFrameNumber')) is not int or
                            readiness['matchedEngineFrameNumber'] < 0 or
                            type(readiness.get('rasterFrameNumber')) is not int or
                            readiness.get('rasterFrameNumber') != readiness['matchedEngineFrameNumber']):
                        raise ValueError('Invalid bounded exact-scene screenshot witness')
                    # Retain the ORIGINAL frame-associated scaler/geometry
                    # witness: Android log lines may truncate long JSON.
                    item['screenshotReadiness'] = readiness
                if self.home_profile_only and readiness is None:
                    raise ValueError('Home profile snapshot requires original exact-frame readiness')
                if self.graphite_capture and readiness is None:
                    raise ValueError('Graphite snapshot requires original exact-frame readiness')
                if self.responsive_preset is not None:
                    if readiness is None:
                        raise ValueError('Responsive snapshot requires original exact-frame readiness')
                    self.responsive_snapshots.append(name)
            elif operation == 'record_start':
                item.update(self.record_start(name))
            elif operation == 'record_stop':
                if not self.recording or self.recording[0] != name:
                    raise ValueError('Recording name mismatch')
                item.update(self.record_stop())
            elif operation == 'perf_start':
                if self.static_backdrop_probe and (len(self.probe_profiles) >= 2 or name != PROBE_PROFILES[len(self.probe_profiles)]):
                    raise ValueError('Probe requires exactly ordered normal/solid A/B phases')
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
                if self.graphite_capture and (body.get('recordingDuringMeasurement') is not False or
                        result.get('visibleScope', {}).get('screenRecordingActive') is not False or
                        result.get('visibleScope', {}).get('graphiteProductionInteractions') is not True):
                    raise ValueError('Graphite profile must be actual unrecorded production interactions')
                if self.home_profile_only:
                    scope = result.get('visibleScope', {})
                    samples = scope.get('clockSamples', [])
                    if (result.get('diagnosticOnly') is True or scope.get('diagnosticOnly') is True or
                            scope.get('solidMode') is True or scope.get('route') != '/home' or
                            scope.get('homeCreateHitTestableAtStart') is not True or
                            scope.get('animationsDisabledAtStart') is not False or
                            scope.get('screenRecordingActive') is not False or
                            scope.get('nominalObservationMilliseconds') != 17000 or
                            result.get('observationElapsedUs', 0) < 17_000_000 or len(samples) != 34 or
                            any(sample.get('auroraIsAnimating') is not True or
                                sample.get('auroraTickerModeEnabled') is not True or
                                sample.get('appLifecycle') != 'resumed' or sample.get('reducedMotion') is not False or
                                sample.get('timeDilation') != 1 for sample in samples)):
                        raise ValueError('Missing normal visible Home profile/clock evidence')
                if self.static_backdrop_probe:
                    scope = result.get('visibleScope', {})
                    samples = scope.get('clockSamples', [])
                    solid = name == PROBE_PROFILES[1]
                    if (result.get('diagnosticOnly') is not True or scope.get('diagnosticOnly') is not True or
                            scope.get('solidMode') is not solid or len(samples) != 34 or
                            scope.get('nominalObservationMilliseconds') != 17000 or
                            any(sample.get('backdropSolid') is not solid or
                                sample.get('sameAuroraStateControllerTexture') is not True or
                                sample.get('auroraIsAnimating') is not True or
                                sample.get('auroraTickerModeEnabled') is not True or
                                sample.get('appLifecycle') != 'resumed' or sample.get('reducedMotion') is not False or
                                sample.get('timeDilation') != 1 or len(sample.get('staticCacheRawImages', [])) != 1
                                for sample in samples)):
                        raise ValueError('Missing bounded diagnostic clocks/cache/live-state evidence')
                    sizes = {(sample['staticCacheRawImages'][0].get('width'), sample['staticCacheRawImages'][0].get('height')) for sample in samples}
                    if (len(sizes) != 1 or any(not isinstance(value, int) or value <= 0 for size in sizes for value in size) or
                            (self.probe_cache_size is not None and sizes != {self.probe_cache_size})):
                        raise ValueError('Static texture changed across same-run A/B')
                    self.probe_cache_size = next(iter(sizes))
                    if not result.get('rawFrames'):
                        raise ValueError('No real Flutter frame samples')
                    self.probe_profiles.append(name)
                if not result.get('rawFrames'):
                    raise ValueError('No real Flutter frame samples')
                (OUTPUT / 'performance' / f'{name}.json').write_text(json.dumps(result, indent=2) + '\n')
                if self.graphite_capture:
                    item.update(self._write_graphite_json('performance/graphite-interactions-unrecorded.json', result))
                (OUTPUT / 'performance' / f'{name}-android-framestats.txt').write_text(adb('shell', 'dumpsys', 'gfxinfo', PACKAGE, 'framestats').stdout)
                (OUTPUT / 'performance' / f'{name}-memory-after.txt').write_text(adb('shell', 'dumpsys', 'meminfo', PACKAGE).stdout)
                item.update(frameSamples=len(result['rawFrames']), recordingDuringMeasurement=False,
                            pssScope='Before/after whole-app process snapshots, not measured peak or physical-device memory')
            elif operation == 'diagnostic':
                observations = body.get('observations')
                samples = observations.get('clockSamples') if isinstance(observations, dict) else None
                if name != 'home-motion-clock' or self.recording or body.get('recordingDuringMeasurement') is not False or not isinstance(samples, list) or not 1 <= len(samples) <= 40:
                    raise ValueError('Invalid bounded unrecorded Home clock observation')
                if self.home_profile_only and len(samples) != 34:
                    raise ValueError('Home profile subset requires original34 clock observations')
                (OUTPUT / 'performance' / f'{name}.json').write_text(json.dumps({
                    'scope': 'Actual unrecorded controller/lifecycle/framework-clock observations; not physical performance or proof of encoder causality by itself',
                    'observationElapsedUs': body.get('observationElapsedUs'),
                    'observations': observations}, indent=2)+'\n')
                item.update(clockSamples=len(samples), recordingDuringMeasurement=False)
            elif operation == 'display':
                displays = {'phone': ('1080x2400', '420', '1.0'), 'compact': ('640x1280', '320', '2.0'), 'tablet': ('1600x2400', '240', '1.0')}
                if name not in displays or self.recording or self.perf:
                    raise ValueError('Invalid display preset or capture phase')
                size, density, scale = displays[name]
                adb('shell', 'wm', 'size', size)
                adb('shell', 'wm', 'density', density)
                adb('shell', 'settings', 'put', 'system', 'font_scale', scale)
                item.update(physicalSize=size, densityDpi=density, systemFontScale=scale)
            elif operation == 'system_motion':
                if not self.graphite_capture or name not in ('reduced', 'normal') or not self.recording or self.recording[0] != GRAPHITE_CLIPS[-1]:
                    raise ValueError('System motion changes require the owned graphite reduced-motion phase')
                value = '0.0' if name == 'reduced' else '1.0'
                observed = {}
                for setting in MOTION_SETTINGS:
                    adb('shell', 'settings', 'put', 'global', setting, value)
                    observed[setting] = adb('shell', 'settings', 'get', 'global', setting).stdout.strip()
                    if float(observed[setting]) != float(value):
                        raise ValueError('Owned system motion setting did not apply')
                self.graphite_system_motion = name == 'reduced'
                item.update(actualSystemReadbacks=observed, reducedMotionRequested=self.graphite_system_motion)
            elif operation == 'graphite_opening':
                observations = body.get('observations')
                stop = self.report['events'][-1] if self.report['events'] else {}
                if (not self.graphite_capture or self.recording or self.perf or
                        stop.get('operation') != 'record_stop' or stop.get('name') != GRAPHITE_CLIPS[0] or
                        stop.get('wholeVideoDecode', {}).get('passed') is not True or
                        body.get('productionEntryPoint') != 'lib/main.dart' or body.get('showWelcome') is not True or
                        body.get('fixtureGuideAlreadyCompleted') is not True or body.get('firstFrameRasterized') is not True or
                        body.get('readyHomeRendered') is not True or body.get('launchEndedWithoutInput') is not True or
                        not isinstance(observations, list) or not 2 <= len(observations) <= 128 or
                        any(not isinstance(x, dict) for x in observations) or
                        any(type(x.get('elapsedUs')) is not int or x['elapsedUs'] < 0 or
                            type(x.get('engineFrameNumber')) is not int or x['engineFrameNumber'] < 0 or
                            type(x.get('controllerValue')) not in (int, float) or not 0 <= x['controllerValue'] <= 1
                            for x in observations) or
                        any(b['elapsedUs'] <= a['elapsedUs'] for a, b in zip(observations, observations[1:])) or
                        max(x['controllerValue'] for x in observations) <= min(x['controllerValue'] for x in observations)):
                    raise ValueError('Missing actual production launch/controller/whole-video evidence')
                witness = {key: value for key, value in body.items() if key not in ('token', 'sequence')}
                item.update(self._write_graphite_json('graphite-opening.json', witness))
                self.graphite_opening = True
                item.update(actualControllerSamples=len(observations),
                    scope='First actual production widget mount in a fixture-seeded profile diagnostic process; not OS/VM cold-start time or phase-by-phase presentation proof')
            elif operation == 'graphite_trace':
                actions, witnesses = body.get('actions'), body.get('witnesses')
                stop = self.report['events'][-1] if self.report['events'] else {}
                reduced = name == GRAPHITE_CLIPS[-1]
                required = {
                    '01-root-navigation': ('retainedLibraryReady', 'warmLaunchNotReplayed'),
                    '02-editor-instrument': ('heroObserved', 'firstInputCancelledPresentation', 'canvasRectStable', 'playingUiObserved', 'pausedUiObserved', 'warmLaunchNotReplayed'),
                    '05-export-ready': ('cancelObserved', 'actualIoErrorObserved', 'fixtureDirectoryRestored', 'readyAfterRetry'),
                    '06-reduced-motion': ('storedFalseDuringSystem', 'systemRestoredBeforeStored', 'systemAndStoredObserved', 'warmLaunchNotReplayed'),
                }
                if (not self.graphite_capture or name not in GRAPHITE_ACTIONS or self.recording or self.perf or
                        stop.get('operation') != 'record_stop' or stop.get('name') != name or
                        stop.get('wholeVideoDecode', {}).get('passed') is not True or
                        not isinstance(actions, list) or any(not isinstance(a, dict) for a in actions) or
                        [a.get('action') for a in actions] != list(GRAPHITE_ACTIONS[name]) or
                        any(type(a.get('tapElapsedUs')) is not int or a['tapElapsedUs'] < 0 or
                            type(a.get('engineFrameNumber')) is not int or a['engineFrameNumber'] < 0 or
                            not isinstance(a.get('targetBounds'), list) or len(a['targetBounds']) != 4 or
                            any(type(x) not in (int, float) or not math.isfinite(x) for x in a['targetBounds']) or
                            min(a['targetBounds'][2:]) <= 0 or
                            type(a.get('requestedPostTapWaitMs')) is not int or not 0 <= a['requestedPostTapWaitMs'] <= 1500 or
                            a.get('reducedMotion') is not reduced for a in actions) or
                        any(b['tapElapsedUs'] <= a['tapElapsedUs'] for a, b in zip(actions, actions[1:])) or
                        type(body.get('actualElapsedUs')) is not int or body['actualElapsedUs'] <= actions[-1]['tapElapsedUs'] or
                        not isinstance(witnesses, dict) or any(witnesses.get(key) is not True for key in required[name])):
                    raise ValueError('Missing actual graphite action/state/decode evidence')
                item.update(self._write_graphite_json('graphite-' + name + '.json', {
                    'scope': 'Actual hit-tested/pointer actions and UI/storage witnesses; not physical audibility, every-frame continuity or presentation FPS',
                    'actions': actions, 'witnesses': witnesses, 'actualElapsedUs': body['actualElapsedUs']}))
                self.graphite_traces.append(name)
                item.update(actionCount=len(actions), reducedMotion=reduced, witnesses=witnesses)
            elif operation == 'graphite_complete':
                if (not self.graphite_capture or not self.graphite_opening or self.recording or self.perf or
                        self.graphite_traces != list(GRAPHITE_CLIPS[1:]) or self.graphite_system_motion is not False or
                        body.get('storedMotionRestored') is not True or body.get('passed') is not True or
                        body.get('normalFullCapturePassed') is not False or
                        self.report.get('appMetadata', {}).get('captureMode') != 'graphite-reference-capture'):
                    raise ValueError('Incomplete graphite subset or unrestored motion state')
                self.complete = True
                self.report.update(graphiteSubsetPassed=True, normalFullCapturePassed=False)
            elif operation == 'transition_trace':
                reduced = name == TRANSITION_CLIPS[1]
                actions = body.get('actions')
                stop = self.report['events'][-1] if self.report['events'] else {}
                if (not self.transition_capture_only or self.recording or self.perf or
                        stop.get('operation') != 'record_stop' or stop.get('name') != name or
                        stop.get('wholeVideoDecode', {}).get('passed') is not True or
                        body.get('reducedMotion') is not reduced or body.get('finalHomeRendered') is not True or
                        not isinstance(actions, list) or len(actions) != len(TRANSITION_ACTIONS) or
                        [action.get('action') for action in actions if isinstance(action, dict)] != list(TRANSITION_ACTIONS) or
                        any(type(action.get('tapElapsedUs')) is not int or action['tapElapsedUs'] < 0 or
                            action.get('reducedMotion') is not reduced for action in actions) or
                        any(b['tapElapsedUs'] <= a['tapElapsedUs'] for a, b in zip(actions, actions[1:])) or
                        type(body.get('actualElapsedUs')) is not int or body['actualElapsedUs'] <= actions[-1]['tapElapsedUs']):
                    raise ValueError('Missing actual bounded transition action/decode evidence')
                (OUTPUT / ('transition-' + name + '.json')).write_text(json.dumps({
                    'scope': 'Actual hit-tested taps and wall-clock spacing; not presentation smoothness or animation correctness by itself',
                    'actions': actions, 'actualElapsedUs': body['actualElapsedUs'], 'reducedMotion': reduced}, indent=2)+'\n')
                self.transition_traces.append(name)
                item.update(actionCount=len(actions), reducedMotion=reduced)
            elif operation == 'transition_complete':
                if (not self.transition_capture_only or self.recording or self.perf or
                        self.transition_traces != list(TRANSITION_CLIPS) or
                        body.get('passed') is not True or body.get('subsetOnly') is not True or
                        body.get('normalFullCapturePassed') is not False):
                    raise ValueError('Incomplete normal/reduced transition subset')
                self.complete = True
                self.report['transitionSubsetPassed'] = True
            elif operation == 'home_profile_complete':
                if (not self.home_profile_only or self.recording or self.perf or
                        body.get('passed') is not True or body.get('subsetOnly') is not True or
                        body.get('normalFullCapturePassed') is not False or
                        self.report.get('appMetadata', {}).get('captureMode') != 'home-profile-only'):
                    raise ValueError('Incomplete or mismatched normal Home profile subset')
                stop = self.report['events'][-1]
                if stop.get('wholeVideoDecode', {}).get('passed') is not True:
                    raise ValueError('Home profile subset requires actual whole-video decode')
                self.complete = True
                self.report['homeProfileSubsetPassed'] = True
            elif operation == 'responsive_complete':
                if (self.responsive_preset is None or name != self.responsive_preset or self.recording or self.perf or
                        body.get('passed') is not True or body.get('subsetOnly') is not True or
                        body.get('normalFullCapturePassed') is not False or
                        body.get('responsivePreset') != self.responsive_preset or
                        self.responsive_snapshots != list(RESPONSIVE_SHOTS[self.responsive_preset]) or
                        self.report.get('appMetadata', {}).get('captureMode') != 'responsive-' + self.responsive_preset):
                    raise ValueError('Incomplete or mismatched responsive screenshot subset')
                self.complete = True
                self.report.update(responsiveSubsetPassed=True, completedScreenshotNames=list(self.responsive_snapshots))
            elif operation == 'static_backdrop_restored':
                restored = body.get('restoredRasterEvidence', {})
                frames = restored.get('matchedNaturalFrames', [])
                if (not self.static_backdrop_probe or name != 'static-backdrop-probe' or
                        body.get('diagnosticOnly') is not True or body.get('exactDecorationRestored') is not True or
                        body.get('freshLookupSameTarget') is not True or restored.get('manualFrameRequests') != 0 or
                        len(frames) < 2 or len({frame.get('rasterFrameNumber') for frame in frames}) < 2 or
                        any(not isinstance(frame.get('rasterFrameNumber'), int) or frame['rasterFrameNumber'] < 0 or frame.get('matchedEngineFrameNumber') != frame['rasterFrameNumber'] for frame in frames)):
                    raise ValueError('No exact restoration joined to two natural raster completions')
                self.probe_restored = self.probe_profiles == list(PROBE_PROFILES) and self.perf is None
                item['restorationAfterBothProfiles'] = self.probe_restored
                (OUTPUT / 'performance' / 'diagnostic-static-backdrop-restoration.json').write_text(json.dumps({
                    key: value for key, value in body.items() if key not in ('token', 'sequence')}, indent=2)+'\n')
            elif operation == 'diagnostic_complete':
                if (not self.static_backdrop_probe or name != 'static-backdrop-probe' or self.recording or self.perf or
                        self.probe_profiles != list(PROBE_PROFILES) or not self.probe_restored or
                        self.report.get('appMetadata', {}).get('captureMode') != 'diagnostic-static-backdrop-only' or
                        body.get('passed') is not True or body.get('diagnosticOnly') is not True or body.get('normalFootageProduced') is not False):
                    raise ValueError('Incomplete diagnostic-only A/B and restoration')
                self.complete = True
                self.report['diagnosticPassed'] = True
            elif operation == 'metadata':
                mode = body.get('captureMode')
                if (self.graphite_capture and (mode != 'graphite-reference-capture' or body.get('label') != 'after')) or (not self.graphite_capture and mode == 'graphite-reference-capture'):
                    raise ValueError('Host/app graphite mode or after-label mismatch')
                if (self.transition_capture_only and (mode != 'transition-capture-only' or body.get('label') != 'after')) or (not self.transition_capture_only and mode == 'transition-capture-only'):
                    raise ValueError('Host/app transition mode or after-label mismatch')
                if (self.home_profile_only and (mode != 'home-profile-only' or body.get('label') != 'after')) or (not self.home_profile_only and mode == 'home-profile-only'):
                    raise ValueError('Host/app Home profile mode or after-label mismatch')
                if ((self.responsive_preset is not None and mode != 'responsive-' + self.responsive_preset) or
                        (self.responsive_preset is None and isinstance(mode, str) and mode.startswith('responsive-'))):
                    raise ValueError('Host/app responsive mode mismatch')
                if ((self.static_backdrop_probe and body.get('captureMode') != 'diagnostic-static-backdrop-only') or
                        (not self.static_backdrop_probe and body.get('captureMode') == 'diagnostic-static-backdrop-only')):
                    raise ValueError('Host/app diagnostic mode mismatch')
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



def finalize_capture(capture, server, port):
    """Retain original failure evidence and close the server even when ADB dies."""
    was_passed = capture.report.get('passed') is True
    errors = []

    def failed(stage, error):
        errors.append({'stage': stage, 'error': safe_capture_error(error, capture.token)})
        capture.report['passed'] = False
        capture.report['cleanupErrors'] = list(errors)

    def persist():
        try:
            temporary = OUTPUT / 'capture-report.json.tmp'
            temporary.write_text(json.dumps(capture.report, indent=2) + '\n')
            temporary.replace(OUTPUT / 'capture-report.json')
        except Exception as error:
            failed('persist-original-report', error)

    try:
        if capture.recording:
            try:
                capture.record_stop()
            except Exception as error:
                failed('finalize-owned-recording', error)
        # Do this BEFORE any further ADB operation: offline logcat previously
        # masked the driver failure and prevented final event/SHA preservation.
        persist()
        if capture.graphite_capture:
            try:
                restored = {}
                for setting in MOTION_SETTINGS:
                    adb('shell', 'settings', 'put', 'global', setting, '1.0')
                    restored[setting] = adb('shell', 'settings', 'get', 'global', setting).stdout.strip()
                    if float(restored[setting]) != 1:
                        raise ValueError('Owned system motion restoration did not apply')
                capture.report['finalSystemMotionReadbacks'] = restored
            except Exception as error:
                failed('restore-owned-system-motion', error)
        try:
            output = adb('logcat', '-d', '-s', 'AndroidRuntime', 'flutter', required=False).stdout
            (OUTPUT / 'android-logcat.txt').write_text(output)
        except Exception as error:
            failed('collect-logcat', error)
    finally:
        try:
            adb('reverse', '--remove', f'tcp:{port}', required=False)
        except Exception as error:
            failed('remove-owned-reverse', error)
        try:
            server.shutdown()
        except Exception as error:
            failed('shutdown-local-server', error)
        finally:
            try:
                server.server_close()
            except Exception as error:
                failed('close-local-server', error)
        persist()
    if errors and was_passed:
        raise RuntimeError('Capture cleanup failed; original evidence retained and capture is not accepted.')
    return errors


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Only the disposable GitHub Actions emulator is authorized')
    if adb('shell', 'getprop', 'ro.kernel.qemu').stdout.strip() != '1':
        raise RuntimeError('QEMU identity check rejected device operation')
    adb('shell', 'settings', 'put', 'secure', 'show_ime_with_hard_keyboard', '1')
    if adb('shell', 'settings', 'get', 'secure', 'show_ime_with_hard_keyboard').stdout.strip() != '1':
        raise RuntimeError('Owned emulator native IME configuration did not apply')
    for folder in ('screenshots', 'recordings', 'performance'):
        (OUTPUT / folder).mkdir(parents=True, exist_ok=True)
    provenance = json.loads((OUTPUT / 'source-provenance.json').read_text())
    diagnostic = provenance.get('diagnosticOnly')
    if diagnostic not in (None, 'static-backdrop'):
        raise RuntimeError('Unknown capture diagnostic mode')
    responsive = provenance.get('responsivePreset')
    home_only = provenance.get('homeProfileOnly', False)
    if home_only is True and provenance.get('label') != 'after':
        raise RuntimeError('Home profile subset requires after-source provenance')
    transitions = provenance.get('transitionCaptureOnly', False)
    if transitions is True and (provenance.get('label') != 'after' or provenance.get('transitionComparison') not in ('before-fix', 'after-fix')):
        raise RuntimeError('Transition subset requires explicit pinned after-source comparison role')
    graphite = provenance.get('graphiteCapture', False)
    if graphite is True and provenance.get('label') != 'after':
        raise RuntimeError('Graphite capture requires pinned after-source provenance')
    capture = Capture(static_backdrop_probe=diagnostic == 'static-backdrop', responsive_preset=responsive, home_profile_only=home_only, transition_capture_only=transitions, graphite_capture=graphite)
    capture.report['source'] = provenance
    capture.report['hostCpuContext'] = host_cpu_context()
    capture.report['nativeImeWithHardwareKeyboard'] = True

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            try:
                if self.path != '/event' or not 0 < int(self.headers.get('Content-Length', '0')) <= 2_000_000:
                    raise ValueError('Invalid local capture request')
                body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                result = capture.event(body)
                self.send_response(200)
            except Exception as error:
                message = safe_capture_error(error, capture.token)
                capture.report['hostError'] = message
                result = {'ok': False, 'error': message}
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
    if responsive is not None or capture.static_backdrop_probe:
        # Fresh owned job; prove no old app/VM-service process is live before wm.
        adb('shell', 'am', 'force-stop', PACKAGE, required=False)
        if adb('shell', 'pidof', PACKAGE, required=False).stdout.strip():
            raise RuntimeError('Refusing responsive wm configuration with a live app process')
    size, density, scale = INITIAL_DISPLAYS.get(responsive, INITIAL_DISPLAYS['light'])
    adb('shell', 'wm', 'size', size)
    adb('shell', 'wm', 'density', density)
    adb('shell', 'settings', 'put', 'system', 'font_scale', scale)
    capture.report['initialDisplayBeforeAppLaunch'] = {'physicalSize': size, 'densityDpi': density, 'systemFontScale': scale}
    # Fresh owned diagnostic app data; never an owner's existing installation.
    adb('shell', 'am', 'force-stop', PACKAGE, required=False)
    adb('uninstall', PACKAGE, required=False)
    command = ['flutter', 'drive', '--profile', '--no-pub', '-d', DEVICE,
               '--driver=test_driver/ui_visual_capture_driver.dart',
               '--target=integration_test/ui_visual_capture_test.dart',
               f'--dart-define=UI_CAPTURE_TOKEN={capture.token}',
               f'--dart-define=UI_CAPTURE_PORT={port}',
               f'--dart-define=UI_CAPTURE_LABEL={provenance["label"]}']
    if capture.static_backdrop_probe:
        command.append('--dart-define=UI_STATIC_BACKDROP_PROBE=true')
    if responsive is not None:
        command.append('--dart-define=UI_RESPONSIVE_PRESET=' + responsive)
    if capture.home_profile_only:
        command.append('--dart-define=UI_HOME_PROFILE_ONLY=true')
    if capture.transition_capture_only:
        command.append('--dart-define=UI_TRANSITION_CAPTURE_ONLY=true')
    if capture.graphite_capture:
        command.append('--dart-define=UI_GRAPHITE_CAPTURE=true')
    capture.report['profileProcessBudgetSeconds'] = PROFILE_PROCESS_TIMEOUT_SECONDS
    capture.report['profileProcessBudgetScope'] = 'Whole Flutter drive process, including cold profile compilation and runtime; all per-operation acceptance gates remain independent.'
    # Observe the already verified owned QEMU and bounded host counters before
    # compilation. Never inspect command lines/environment or repair transport.
    # These snapshots are outside the measured interaction/frame phases.
    safe_snapshot('before', verified_qemu=True, output=OUTPUT)
    try:
        # Do not print this command: the one-job localhost capability is private.
        with (OUTPUT / 'flutter-drive.log').open('w') as log:
            run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=PROFILE_PROCESS_TIMEOUT_SECONDS, check=False)
        if run.returncode or not capture.complete or capture.report.get('hostError'):
            raise RuntimeError(f'Profile UI capture failed (exit {run.returncode}); see flutter-drive.log')
        capture.report['passed'] = True
    except Exception as error:
        # Preserve immediate evidence before ADB/recorder cleanup can change it.
        # A cgroup OOM counter alone is not per-process cause attribution.
        safe_snapshot('failure', verified_qemu=True, output=OUTPUT)
        capture.report['error'] = safe_capture_error(error, capture.token)
        log = OUTPUT / 'flutter-drive.log'
        if log.exists():
            print('Actual profile test failure log:', flush=True)
            for line in log.read_text(errors='replace').splitlines()[-150:]:
                if 'UI_CAPTURE_TOKEN=' not in line:
                    print(line.replace(capture.token, '[redacted]'), flush=True)
        raise_capture_failure(error, capture.token)
    finally:
        try:
            finalize_capture(capture, server, port)
        finally:
            safe_snapshot('final', verified_qemu=True, output=OUTPUT)
        print(json.dumps({'passed': capture.report['passed'], 'events': len(capture.report['events']), 'scope': capture.report['scope']}), flush=True)


if __name__ == '__main__':
    main()
