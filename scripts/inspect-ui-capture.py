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


def inspect_native_profile_resources(phases=RESOURCE_PHASES):
    """Small exact-file summaries, not arbitrary dumpsys/runner-file access."""
    folder = ROOT / 'performance'
    if folder.is_symlink():
        raise ValueError('Native profile resource directory symlink rejected')
    graphics_pattern = re.compile(r'\s*(?:Total frames rendered:\s*\d+|Janky frames(?: \(legacy\))?:\s*\d+\s*\([0-9.]+%\)|(?:50th|90th|95th|99th) percentile:\s*\d+ms)\s*')
    memory_pattern = re.compile(r'\s*(?:(?:Native Heap|Dalvik Heap|TOTAL)\s+\d+(?:\s+\d+)+|(?:Java Heap|Native Heap|Graphics):\s*\d+(?:\s+\d+)*|TOTAL PSS:\s*\d+(?:\s+TOTAL RSS:\s*\d+)?(?:\s+TOTAL SWAP PSS:\s*\d+)?)\s*')
    for phase in phases:
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
GRAPHITE_RECORDINGS = ('00-graphite-opening', '01-root-navigation', '02-editor-instrument', '05-export-ready', '06-reduced-motion')
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
    ('metadata', 'session'), ('record_start', GRAPHITE_RECORDINGS[0]), ('record_stop', GRAPHITE_RECORDINGS[0]),
    ('graphite_opening', 'opening'), ('snapshot', '01-home'),
    ('perf_start', 'graphite-interactions-unrecorded'), ('perf_finish', 'graphite-interactions-unrecorded'),
    ('record_start', GRAPHITE_RECORDINGS[1]), ('record_stop', GRAPHITE_RECORDINGS[1]), ('graphite_trace', GRAPHITE_RECORDINGS[1]),
    ('snapshot', '02-drafts'), ('snapshot', '03-exports'), ('snapshot', '04-settings'),
    ('record_start', GRAPHITE_RECORDINGS[2]), ('record_stop', GRAPHITE_RECORDINGS[2]), ('graphite_trace', GRAPHITE_RECORDINGS[2]),
    ('snapshot', '24-graphite-editor'), ('snapshot', '08-instruments'), ('snapshot', '10-export-selection'),
    ('record_start', GRAPHITE_RECORDINGS[3]), ('record_stop', GRAPHITE_RECORDINGS[3]), ('graphite_trace', GRAPHITE_RECORDINGS[3]),
    ('snapshot', '11-export-ready'),
    ('record_start', GRAPHITE_RECORDINGS[4]), ('system_motion', 'reduced'), ('system_motion', 'normal'),
    ('record_stop', GRAPHITE_RECORDINGS[4]), ('graphite_trace', GRAPHITE_RECORDINGS[4]),
    ('snapshot', '15-home-reduced-motion'), ('graphite_complete', 'graphite'),
)
GRAPHITE_WITNESSES = {
    '01-root-navigation': ('retainedLibraryReady', 'warmLaunchNotReplayed'),
    '02-editor-instrument': ('heroObserved', 'firstInputCancelledPresentation', 'canvasRectStable', 'playingUiObserved', 'pausedUiObserved', 'warmLaunchNotReplayed'),
    '05-export-ready': ('cancelObserved', 'actualIoErrorObserved', 'fixtureDirectoryRestored', 'readyAfterRetry'),
    '06-reduced-motion': ('storedFalseDuringSystem', 'systemRestoredBeforeStored', 'systemAndStoredObserved', 'warmLaunchNotReplayed'),
}
MOTION_SETTINGS = ('window_animation_scale', 'transition_animation_scale', 'animator_duration_scale')


def graphite_requested(request):
    value = request.get('graphiteCaptureDiagnostic', False)
    if type(value) is not bool or (value and request.get('interactionMotionDiagnostic') is not True):
        raise ValueError('Graphite inspection requires explicit boolean and complete original interaction diagnostics')
    return value


def validate_graphite_report(report):
    source = report.get('source', {})
    if (report.get('passed') is not True or report.get('graphiteCapture') is not True or
            report.get('graphiteSubsetPassed') is not True or report.get('normalFullCapturePassed') is not False or
            report.get('reportSource') != 'capture-report.json' or
            source.get('graphiteCapture') is not True or source.get('label') != 'after' or
            any(not isinstance(source.get(key), str) or not re.fullmatch(r'[a-f0-9]{40}', source[key])
                for key in ('productSourceSha', 'productTreeSha', 'captureHarnessSourceSha')) or
            report.get('appMetadata', {}).get('captureMode') != 'graphite-reference-capture'):
        raise ValueError('Not an original completed source-pinned graphite report')
    events = report.get('events')
    if (not isinstance(events, list) or any(not isinstance(item, dict) for item in events) or
            [(item.get('operation'), item.get('name')) for item in events] != list(GRAPHITE_EVENTS) or
            [item.get('sequence') for item in events] != list(range(1, len(GRAPHITE_EVENTS)+1))):
        raise ValueError('Graphite original operation inventory/order differs')
    for item in events:
        if item['operation'] == 'record_stop' and item.get('wholeVideoDecode', {}).get('passed') is not True:
            raise ValueError('Graphite original clip lacks host full-stream decode')
        if item['operation'] == 'snapshot':
            witness = item.get('screenshotReadiness', {})
            if (witness.get('expectedScene') != item['name'] or type(witness.get('matchedEngineFrameNumber')) is not int or
                    witness['matchedEngineFrameNumber'] < 0 or witness.get('rasterFrameNumber') != witness['matchedEngineFrameNumber']):
                raise ValueError('Graphite original exact-frame screenshot witness missing')
        if item['operation'] == 'system_motion':
            expected = 0 if item['name'] == 'reduced' else 1
            values = item.get('actualSystemReadbacks', {})
            if set(values) != set(MOTION_SETTINGS) or any(float(values[key]) != expected for key in MOTION_SETTINGS):
                raise ValueError('Graphite original system motion readbacks mismatch')
    restored = report.get('finalSystemMotionReadbacks', {})
    if set(restored) != set(MOTION_SETTINGS) or any(float(restored[key]) != 1 for key in MOTION_SETTINGS):
        raise ValueError('Graphite final system motion restoration is unverified')


def graphite_json(relative, event, *, limit=65_536):
    path = ROOT / relative
    if (ROOT.is_symlink() or path.parent.is_symlink() or path.is_symlink() or not path.is_file() or
            event.get('evidenceFile') != relative or type(event.get('evidenceBytes')) is not int or
            not 0 < path.stat().st_size <= limit or path.stat().st_size != event['evidenceBytes']):
        raise ValueError('Bounded exact graphite evidence path/length rejected: ' + relative)
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != event.get('evidenceSha256'):
        raise ValueError('Graphite evidence SHA differs from original host: ' + relative)
    value = json.loads(data)
    if not isinstance(value, dict): raise ValueError('Graphite evidence must be a bounded object')
    return value


def inspect_graphite_evidence(report):
    validate_graphite_report(report)
    events = report['events']
    opening_event = next(item for item in events if item['operation'] == 'graphite_opening')
    opening = graphite_json('graphite-opening.json', opening_event)
    observations = opening.get('observations')
    if (opening.get('productionEntryPoint') != 'lib/main.dart' or opening.get('showWelcome') is not True or
            opening.get('fixtureGuideAlreadyCompleted') is not True or opening.get('firstFrameRasterized') is not True or
            opening.get('readyHomeRendered') is not True or opening.get('launchEndedWithoutInput') is not True or
            not isinstance(observations, list) or not 2 <= len(observations) <= 128 or
            opening_event.get('actualControllerSamples') != len(observations) or
            any(not isinstance(x, dict) or type(x.get('elapsedUs')) is not int or x['elapsedUs'] < 0 or
                type(x.get('engineFrameNumber')) is not int or x['engineFrameNumber'] < 0 or
                type(x.get('controllerValue')) not in (int, float) or not 0 <= x['controllerValue'] <= 1 for x in observations) or
            any(b['elapsedUs'] <= a['elapsedUs'] or b['controllerValue'] < a['controllerValue'] for a,b in zip(observations, observations[1:])) or
            observations[-1]['controllerValue'] <= observations[0]['controllerValue']):
        raise ValueError('Original graphite production launch witness is incomplete')
    print('UI_GRAPHITE_OPENING ' + json.dumps(opening), flush=True)
    for name in GRAPHITE_RECORDINGS[1:]:
        event = next(item for item in events if item['operation'] == 'graphite_trace' and item['name'] == name)
        trace = graphite_json('graphite-' + name + '.json', event)
        actions, witnesses = trace.get('actions'), trace.get('witnesses')
        if (not isinstance(actions, list) or any(not isinstance(x, dict) for x in actions) or
                [x.get('action') for x in actions] != list(GRAPHITE_ACTIONS[name]) or event.get('actionCount') != len(actions) or
                not isinstance(witnesses, dict) or any(witnesses.get(key) is not True for key in GRAPHITE_WITNESSES[name]) or
                any(type(x.get('tapElapsedUs')) is not int or x['tapElapsedUs'] < 0 or
                    type(x.get('engineFrameNumber')) is not int or x['engineFrameNumber'] < 0 or
                    x.get('reducedMotion') is not (name == GRAPHITE_RECORDINGS[-1]) or
                    not isinstance(x.get('targetBounds'), list) or len(x['targetBounds']) != 4 or
                    any(type(v) not in (int, float) or not math.isfinite(v) for v in x['targetBounds']) or min(x['targetBounds'][2:]) <= 0
                    for x in actions) or
                any(b['tapElapsedUs'] <= a['tapElapsedUs'] for a,b in zip(actions, actions[1:])) or
                type(trace.get('actualElapsedUs')) is not int or trace['actualElapsedUs'] <= actions[-1]['tapElapsedUs']):
            raise ValueError('Original graphite action/state witness mismatch: ' + name)
        print('UI_GRAPHITE_ACTION_TRACE ' + json.dumps({'name': name, **trace}), flush=True)
    profile_event = next(item for item in events if item['operation'] == 'perf_finish')
    result = graphite_json('performance/graphite-interactions-unrecorded.json', profile_event, limit=1_048_576)
    frames, hz = result.get('rawFrames'), result.get('refreshHz')
    scope = result.get('visibleScope', {})
    if (profile_event.get('recordingDuringMeasurement') is not False or scope.get('screenRecordingActive') is not False or
            scope.get('graphiteProductionInteractions') is not True or not isinstance(frames, list) or not 1 <= len(frames) <= 20000 or
            type(hz) not in (int, float) or not math.isfinite(hz) or hz <= 0 or
            any(not isinstance(frame, dict) or any(type(frame.get(key)) is not int or frame[key] < 0
                for key in ('frameNumber', 'vsyncUs', 'rasterFinishWallUs', 'buildUs', 'rasterUs', 'totalUs')) for frame in frames)):
        raise ValueError('Missing actual bounded unrecorded graphite engine timings')
    budget = 1_000_000 / hz
    if type(result.get('frameBudgetUs')) not in (int,float) or abs(result['frameBudgetUs']-budget) > .001:
        raise ValueError('Graphite observed refresh/frame budget mismatch')
    for key, field in (('uiBuild','buildUs'), ('raster','rasterUs'), ('totalSpan','totalUs')):
        values = sorted(frame[field] for frame in frames)
        observed = result.get(key, {})
        expected = {'count': len(values), 'maxUs': values[-1], 'overBudgetFrames': sum(v > budget for v in values),
                    **{label: values[int((len(values)-1)*p+.5)] for label,p in (('p50Us',.5),('p90Us',.9),('p95Us',.95),('p99Us',.99))}}
        if any(observed.get(k) != v for k,v in expected.items()):
            raise ValueError('Graphite engine summary differs from original raw samples: ' + key)
    misses = sum(f['buildUs'] > budget or f['rasterUs'] > budget for f in frames)
    if result.get('eitherUiOrRasterOverBudgetFrames') != misses:
        raise ValueError('Graphite engine budget-miss count differs')
    summary = {key:value for key,value in result.items() if key != 'rawFrames'}
    print('UI_GRAPHITE_PROFILE_VERIFIED ' + json.dumps({'originalRawFrameCount':len(frames), 'actualSummaryRecomputed':True,
        'scope':'Unrecorded software-emulator engine samples, not presentation dropped frames, physical smoothness/audio/iOS acceptance', **summary}), flush=True)


def interaction_contact_names(request):
    names = request.get('interactionContactNames', [])
    allowed = GRAPHITE_RECORDINGS if graphite_requested(request) else INTERACTION_RECORDINGS
    if not isinstance(names, list) or len(names) > 2 or any(not isinstance(name, str) or name not in allowed for name in names) or len(set(names)) != len(names):
        raise ValueError('Select at most two unique exact interaction recording names')
    if names and request.get('interactionMotionDiagnostic') is not True:
        raise ValueError('Interaction contacts require explicit recording diagnostics')
    return names


def interaction_contact(clip, name, frame_count, remaining_bytes, *, dense=False):
    count = 9 if dense else 3
    if frame_count < count:
        raise ValueError('Not enough distinct original decoded frames for contact')
    # Decoded-frame ordinals span the actual clip. showinfo reports the actual
    # PTS for each selected frame, rather than assigning synthetic timestamps.
    indices = [(frame_count - 1) * index // (count - 1) for index in range(count)]
    selection = '+'.join(f'eq(n\\,{index})' for index in indices)
    result = subprocess.run([
        'ffmpeg', '-nostdin', '-v', 'info', '-xerror', '-err_detect', 'explode',
        '-i', str(clip), '-map', '0:v:0', '-an', '-sn', '-dn',
        '-vf', f'select={selection},showinfo,scale=220:-2,tile=3x{3 if dense else 1}:padding=2:color=navy',
        '-frames:v', '1', '-f', 'image2pipe', '-vcodec', 'png', 'pipe:1',
    ], check=True, capture_output=True, timeout=30)
    data = result.stdout
    times = [float(value) for value in re.findall(r'\bn:\s*\d+.*?\bpts_time:([-+0-9.eE]+)', result.stderr.decode(errors='replace'))]
    if len(times) != count or not all(math.isfinite(value) for value in times) or any(b <= a for a, b in zip(times, times[1:])):
        raise ValueError('Original decoded contact timestamps missing or not distinct')
    if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data) > remaining_bytes:
        raise ValueError('Contact PNG signature/combined byte bound rejected')
    print('UI_INTERACTION_CONTACT_SCOPE ' + json.dumps({
        'name': name, 'status': 'UNACCEPTED_DIAGNOSTIC_ONLY',
        'decodedFrameIndices': indices, 'actualDecodedPtsSeconds': times,
        'scope': f'{count} actual decoded original frames evenly spanning frame ordinals; resized only for this contact PNG. Original MP4 unchanged; not smoothness or complete scene acceptance.',
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
        return 0
    names = request.get('interactionRecordingNames')
    graphite = graphite_requested(request)
    if graphite:
        validate_graphite_report(report)
        if names is not None and names != list(GRAPHITE_RECORDINGS):
            raise ValueError('Graphite diagnostics inspect exactly all five original declared clips')
        names = GRAPHITE_RECORDINGS
    elif names is None:
        names = INTERACTION_RECORDINGS
    elif (names != ['01-root-navigation', '06-reduced-motion'] or
            report.get('transitionCaptureOnly') is not True or
            report.get('normalFullCapturePassed') is not False or
            {item.get('name') for item in report['events'] if item.get('operation') in ('record_start', 'record_stop')} != set(names)):
        raise ValueError('Only explicit exact original transition-subset recording selection is supported')
    if any(name not in names for name in contacts):
        raise ValueError('Requested contact must belong to inspected original recording selection')
    folder = ROOT / 'recordings'
    if folder.is_symlink() or not folder.is_dir():
        raise ValueError('Original recordings directory missing or unsafe')
    for name in names:
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
            contact_bytes += interaction_contact(clip, name, frame_count, 1_500_000 - contact_bytes,
                                                 dense=graphite or report.get('transitionCaptureOnly') is True)
    return contact_bytes


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
    graphite = graphite_requested(request)
    report = load_capture_report(request)
    if graphite:
        inspect_graphite_evidence(report)
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
    for path in ([] if graphite else sorted((ROOT / 'performance').glob('*.json'))):
        value = json.loads(path.read_text())
        value.pop('rawFrames', None)
        print(f'UI_PERFORMANCE_SUMMARY {path.name} {json.dumps(value)}', flush=True)
    inspect_native_profile_resources(('graphite-interactions-unrecorded',) if graphite else RESOURCE_PHASES)
    logs = [ROOT / 'recordings' / (name + '.log') for name in GRAPHITE_RECORDINGS] if graphite else sorted((ROOT / 'recordings').glob('*.log'))[:8]
    for path in logs:
        if graphite and not path.exists():
            print('UI_GRAPHITE_RECORDING_LOG_MISSING ' + path.name, flush=True)
            continue
        if not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.log', path.name):
            raise ValueError('Recording diagnostic name rejected')
        print(f'UI_RECORDING_LOG_BEGIN {path.name}', flush=True)
        for line in path.read_text(errors='replace').splitlines()[-80:]:
            print(re.sub(r'DrawMusicCapture-[0-9a-f]{32}-', 'DrawMusicCapture-[redacted]-', line[:1000]), flush=True)
        print(f'UI_RECORDING_LOG_END {path.name}', flush=True)
    screenshots = request.get('screenshots', [])
    if not isinstance(screenshots, list) or len(screenshots) > 5:
        raise ValueError('Select at most five exact acceptance PNG names per read-only inspection')
    print('UI_CAPTURE_REPORT_SOURCE ' + json.dumps({key: report.get(key) for key in ('reportSource', 'passed', 'inspectionStatus')}), flush=True)
    # Encoder/clock diagnosis is independent of PNG display/log-size limits.
    inspect_ambient_recording(request, report)
    contact_bytes = inspect_interaction_recordings(request, report)
    expected = {item['name'] + '.png': item for item in report.get('events', []) if item.get('operation') == 'snapshot'}
    failure = report.get('presentationFailure')
    if failure and failure.get('name') == '00-home-not-presented':
        expected[failure['name'] + '.png'] = failure
    total = contact_bytes if graphite else 0
    sizes = []
    for name in screenshots:
        if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
            raise ValueError('Screenshot name rejected')
        sizes.append({'name': name, 'bytes': (ROOT / 'screenshots' / name).stat().st_size})
    print('UI_CAPTURE_PNG_REQUEST_SIZES ' + json.dumps({'images': sizes, 'totalBytes': sum(item['bytes'] for item in sizes), 'priorContactBytes': total, 'maxBytes': 1_500_000}), flush=True)
    if graphite and total + sum(item['bytes'] for item in sizes) > 1_500_000:
        raise ValueError('Combined original graphite PNG/contact batch exceeds1.5MB')
    for name in screenshots:
        if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
            raise ValueError('Screenshot name rejected')
        data = verified_png(name, expected, 1_500_000 - total)
        total += len(data)
        emit_png(name, data)


if __name__ == '__main__':
    main()
