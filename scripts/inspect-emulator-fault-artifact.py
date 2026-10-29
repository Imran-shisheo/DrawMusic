#!/usr/bin/env python3
"""Fixed-path read-only inspection of one unaccepted owned-SDK trace.

No SDK launch, arbitrary file selection, raw console/environment/map dumps or
inference of a natural SDK exit signal from LLDB's raw numeric exit status.
"""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re

spec = importlib.util.spec_from_file_location('bounded_runtime_reader', Path(__file__).with_name('inspect-runtime-artifact.py'))
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
PREFIX = Path('ui-capture/emulator-lldb-trace')
FIELDS = {
    'installation.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'installed', 'sdkSha256', 'controllerSha256'),
    'lifecycle.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'phase', 'sdkSha256', 'controllerSha256', 'wrapperPid', 'ownedDebuggerPid', 'debuggerReturncode', 'debuggerTerminationSignal', 'drainsComplete', 'startEpochSeconds', 'debuggerExitEpochSeconds', 'endEpochSeconds'),
    'collection.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'observerPhase', 'debuggerFinished', 'tracePhase', 'traceBytes', 'traceSha256'),
    'faults.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'phase', 'ownedInferiorPid', 'sigsegvStopsObserved', 'actualExitStatus', 'finalStateName', 'startEpochSeconds', 'endEpochSeconds', 'errorCategory', 'launchErrorCode', 'continueErrorCode'),
}
TOKENS = ('dynamic loader', 'rendezvous', 'link_map', 'failed to read', 'unable to read', 'could not read', 'invalid address', 'unwind', 'unsupported', 'exec', 'lldb', 'error:', 'warning:')


def validate_request(request):
    if set(request) != {'mode', 'runId', 'artifactId', 'artifactName'} or request.get('mode') not in ('emulator-fault', 'ui-transport'):
        raise ValueError('Explicit fixed-schema emulator-fault inspection required')
    if any(type(request.get(key)) is not int or request[key] <= 0 for key in ('runId', 'artifactId')):
        raise ValueError('Positive exact run and artifact IDs required')
    prefix = 'drawmusic-emulator-fault-trace-' if request['mode'] == 'emulator-fault' else 'drawmusic-ui-visuals-'
    if not isinstance(request.get('artifactName'), str) or not re.fullmatch(re.escape(prefix) + r'[0-9a-f]{40}', request['artifactName']):
        raise ValueError('Only explicitly unaccepted fault-trace artifacts allowed')


def scalar(value):
    if value is None or type(value) in (bool, int, float):
        return value
    if isinstance(value, str):
        return value[:160]
    return '<non-scalar omitted>'


def flight_observations(text):
    """Read only bounded authored telemetry; never print arbitrary driver lines."""
    numbers = {'naturalFramesObserved', 'stateChangesObserved', 'stateChangesDroppedForBound',
               'actualElapsedUs', 'engineFrameNumber', 'postFrameTimestampUs', 'systemFrameTimestampUs',
               'wallElapsedUs', 'routeTransitionDurationUs', 'routeReverseDurationUs', 'canvasMountedCount',
               'canvasVisibleCount', 'canvasHitTestableCount', 'canvasElementIdentity', 'shuttleVisibleCount',
               'shuttleMountedCount', 'shuttleOpacity', 'matchingHeroTags', 'routeAnimationValue'}
    booleans = {'diagnosticOnly', 'acceptanceEligible', 'intentPresent', 'intentCancelled', 'reducedMotion', 'contextMounted'}
    summary, frames = [], []
    for line in text.splitlines():
        for label, output in (('UI_GRAPHITE_FLIGHT_SUMMARY ', summary), ('UI_GRAPHITE_FLIGHT_FRAME ', frames)):
            if label not in line:
                continue
            payload = line.split(label, 1)[1]
            if len(payload) > 8192 or len(output) >= (1 if output is summary else 80):
                raise ValueError('Flight telemetry exceeds authored bounds')
            value = json.loads(payload)
            if not isinstance(value, dict):
                raise ValueError('Flight telemetry must be an object')
            selected = {key: item for key, item in value.items()
                        if (key in numbers and (item is None or type(item) in (int, float) and -1e15 <= item <= 1e15))
                        or (key in booleans and (item is None or type(item) is bool))}
            if 'routePath' in value:
                path = value['routePath']
                selected['routeKind'] = 'home' if path == '/home' else 'editor' if isinstance(path, str) and path.startswith('/editor/') else 'other'
            for key, allowed in {'routeType': {'_PageBasedMaterialPageRoute<void>', '_CustomTransitionPageRoute<void>', 'MaterialPageRoute<void>'},
                                 'routeAnimationStatus': {'dismissed', 'forward', 'reverse', 'completed'},
                                 'lifecycle': {'resumed', 'inactive', 'paused', 'hidden', 'detached'}}.items():
                if key in value:
                    selected[key] = value[key] if value[key] is None or value[key] in allowed else '<other omitted>'
            rectangle = value.get('canvasRect')
            if isinstance(rectangle, list) and len(rectangle) == 4 and all(type(x) in (int, float) and -1e6 <= x <= 1e6 for x in rectangle):
                selected['canvasRect'] = rectangle
            errors = value.get('fieldErrors')
            if isinstance(errors, dict):
                allowed_errors = {'canvasMounted', 'canvasVisible', 'canvasHitTestable', 'shuttleVisible', 'sourceVisible',
                    'routerLookup', 'modalLookup', 'shuttleOpacity', 'canvasRect', 'forwardDuration', 'reverseDuration',
                    'shuttleMounted', 'intentCancelled', 'heroTags', 'reducedMotion', 'animationValue', 'animationStatus'}
                selected['fieldErrors'] = {key: item if item in {'FlutterError', 'StateError', 'TypeError', '_TypeError', 'AssertionError'} else '<other omitted>'
                                           for key, item in errors.items() if key in allowed_errors}
            output.append(selected)
    return {'summary': summary, 'frames': frames, 'scope': 'Authored engine-frame state only; raw driver lines and route identities omitted. Not presentation or smoothness acceptance.'}


def inspect(root, request, emit=print):
    validate_request(request)
    result = {'diagnosticOnly': True, 'acceptanceEligible': False, 'request': request, 'files': [], 'missing': [],
              'scope': 'Stored fixed-path owned debugger metadata only. Console bytes are hashed/classified, never printed. Numeric LLDB exit status is not a natural SDK signal.'}
    found = 0
    # Single-directory normal uploads have contents at ZIP root; fault-trace
    # uploads preserve their ui-capture/ sibling because they include two roots.
    capture_prefix = Path() if request['mode'] == 'ui-transport' else Path('ui-capture')
    if request['mode'] == 'ui-transport':
        captured = []
        observed = reader.inspect_observer(root, Path('emulator-process'), captured.append)
        found += observed['files']
        if captured:
            original = json.loads(captured[0].split('EMULATOR_PROCESS_DIAGNOSTIC ', 1)[1])
            for log in original.get('logs', []):
                log.pop('boundedSignalAndTailLines', None)
            result['normalSdkObserver'] = original
    for name, fields in FIELDS.items():
        relative = PREFIX / name
        if not (root / relative).exists():
            result['missing'].append(str(relative))
            continue
        data = reader.safe_bytes(root, relative, 32768)
        value = json.loads(data)
        if not isinstance(value, dict):
            raise ValueError('Diagnostic metadata must be an object')
        item = {'file': str(relative), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                'selected': {key: scalar(value.get(key)) for key in fields}}
        if name == 'lifecycle.json':
            signals = value.get('wrapperSignals', [])
            if not isinstance(signals, list) or len(signals) > 16:
                raise ValueError('Bounded wrapper signals required')
            item['wrapperSignals'] = [{key: scalar(signal.get(key)) for key in ('signal', 'epochSeconds', 'forwardedToVerifiedOwnedDebugger')}
                                      for signal in signals if isinstance(signal, dict)]
            item['drains'] = {channel: {key: scalar(value.get(channel, {}).get(key))
                                       for key in ('bytesDrained', 'headBytes', 'tailBytes', 'eof', 'truncated')}
                              for channel in ('stdout', 'stderr')}
        result['files'].append(item)
        found += 1
    for channel in ('stdout', 'stderr'):
        for part, limit in (('head', 65536), ('tail', 262144)):
            relative = PREFIX / f'{channel}-{part}.log'
            if not (root / relative).exists():
                result['missing'].append(str(relative))
                continue
            data = reader.safe_bytes(root, relative, limit)
            text = data.decode('utf-8', errors='replace').lower()
            result['files'].append({'file': str(relative), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                                    'diagnosticTokenCounts': {token: text.count(token) for token in TOKENS},
                                    'rawConsolePrinted': False})
            found += 1
    driver = capture_prefix / 'flutter-drive.log'
    if (root / driver).exists():
        data = reader.safe_bytes(root, driver, 8 * 1024 * 1024)
        text = data.decode('utf-8', errors='replace')
        result['flightObservation'] = flight_observations(text)
        # Only canonical renderer identities, never raw driver capability URLs,
        # arguments, test tokens or arbitrary matching log lines.
        result['driverRenderer'] = {'file': str(driver), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'impellerVulkanAnnouncements': len(re.findall(r'Using the Impeller rendering backend \(Vulkan\)', text)),
            'impellerGlesAnnouncements': len(re.findall(r'Using the Impeller rendering backend \(OpenGLES\)', text)),
            'softwareSkiaAnnouncements': len(re.findall(r'Using the Skia rendering backend \(Software\)', text)),
            'rawConsolePrinted': False}
    else:
        result['missing'].append(str(driver))
    report_path = capture_prefix / 'capture-report.json'
    if (root / report_path).exists():
        report_data = reader.safe_bytes(root, report_path, 2 * 1024 * 1024)
        report = json.loads(report_data)
        result['captureReport'] = {key: report.get(key) for key in ('passed', 'diagnosticOnly', 'acceptanceEligible',
            'diagnosticSequenceCompleted', 'graphiteSubsetPassed', 'normalFullCapturePassed', 'normalProductCapturePassed')
            if report.get(key) is None or type(report.get(key)) is bool}
        result['captureReportSha256'] = hashlib.sha256(report_data).hexdigest()
        events = report.get('events', [])
        if not isinstance(events, list) or len(events) > 256:
            raise ValueError('Bounded capture events required')
        profile_path = capture_prefix / 'performance/graphite-interactions-unrecorded.json'
        if (root / profile_path).exists():
            data = reader.safe_bytes(root, profile_path, 1_048_576)
            event = next(x for x in events if x.get('operation') == 'perf_finish' and x.get('name') == 'graphite-interactions-unrecorded')
            if event.get('evidenceBytes') != len(data) or event.get('evidenceSha256') != hashlib.sha256(data).hexdigest():
                raise ValueError('Profile differs from original host witness')
            profile = json.loads(data)
            frames, hz = profile.get('rawFrames'), profile.get('refreshHz')
            scope = profile.get('visibleScope', {})
            if (event.get('recordingDuringMeasurement') is not False or scope.get('screenRecordingActive') is not False
                    or scope.get('graphiteProductionInteractions') is not True or not isinstance(frames, list)
                    or not 1 <= len(frames) <= 20000 or type(hz) not in (int, float) or not math.isfinite(hz) or hz <= 0
                    or any(not isinstance(frame, dict) or any(type(frame.get(k)) is not int or frame[k] < 0
                        for k in ('frameNumber', 'vsyncUs', 'rasterFinishWallUs', 'buildUs', 'rasterUs', 'totalUs')) for frame in frames)):
                raise ValueError('Unrecorded raw frame witnesses required')
            budget = 1_000_000 / hz
            if type(profile.get('frameBudgetUs')) not in (int, float) or abs(profile['frameBudgetUs'] - budget) > .001:
                raise ValueError('Profile refresh/budget mismatch')
            timing = {'originalRawFrameCount': len(frames), 'refreshHz': hz, 'frameBudgetUs': budget,
                      'actualSummaryRecomputed': True, 'acceptanceEligible': False,
                      'scope': 'Unrecorded software-emulator engine timings with diagnostic renderer/debugger; not physical presentation, dropped frames or smoothness acceptance.'}
            for key, field in (('uiBuild', 'buildUs'), ('raster', 'rasterUs'), ('totalSpan', 'totalUs')):
                values = sorted(frame[field] for frame in frames)
                expected = {'count': len(values), 'maxUs': values[-1], 'overBudgetFrames': sum(v > budget for v in values),
                    **{label: values[int((len(values)-1)*fraction+.5)] for label, fraction in (('p50Us', .5), ('p90Us', .9), ('p95Us', .95), ('p99Us', .99))}}
                if any(profile.get(key, {}).get(k) != v for k, v in expected.items()):
                    raise ValueError('Profile raw/summary mismatch')
                timing[key] = expected
            misses = sum(f['buildUs'] > budget or f['rasterUs'] > budget for f in frames)
            if profile.get('eitherUiOrRasterOverBudgetFrames') != misses:
                raise ValueError('Profile budget-miss mismatch')
            timing['eitherUiOrRasterOverBudgetFrames'] = misses
            result['unrecordedProfile'] = timing
        recordings = []
        for name in ('00-graphite-opening', '01-root-navigation', '02-editor-instrument', '05-export-ready', '06-reduced-motion'):
            event = next((x for x in events if x.get('operation') == 'record_stop' and x.get('name') == name), None)
            if event is None:
                continue
            data = reader.safe_bytes(root, capture_prefix / 'recordings' / (name + '.mp4'), 64_000_000)
            digest = hashlib.sha256(data).hexdigest()
            if event.get('bytes') != len(data) or event.get('sha256') != digest:
                raise ValueError('Original recording byte/hash witness mismatch')
            recordings.append({'name': name, 'bytes': len(data), 'sha256': digest,
                'originalHostWholeDecodePassed': event.get('wholeVideoDecode', {}).get('passed') is True,
                'acceptanceEligible': False, 'scope': 'Original video hash verified; decode status is the original host witness, not an independent re-decode.'})
        result['originalRecordings'] = recordings
    if not found:
        raise ValueError('No fixed diagnostic evidence found')
    emit('OWNED_SDK_TRACE_INSPECTION ' + json.dumps(result, sort_keys=True))
    return result


if __name__ == '__main__':
    inspect(Path('work/ui-capture-inspect'), json.loads(Path('cloud/ui-capture-inspect.json').read_text()))
