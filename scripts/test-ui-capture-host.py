#!/usr/bin/env python3
"""Host orchestration regressions. Fake ADB/processes are NOT native runtime proof."""
import copy
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
import struct
import zlib
import traceback
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('capture_host', Path(__file__).with_name('capture-android-ui.py'))
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)


class Process:
    def __init__(self, exit_code): self.returncode = exit_code
    def poll(self): return self.returncode
    def wait(self, timeout): return self.returncode


class RecorderTests(unittest.TestCase):
    def test_offline_cleanup_retains_original_report_before_adb_and_closes_server(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-final-report-') as directory:
            output = Path(directory)
            capture = host.Capture()
            capture.report['error'] = 'original driver failure'
            calls = []
            server = SimpleNamespace(shutdown=lambda:calls.append('shutdown'), server_close=lambda:calls.append('close'))
            def adb(*args, **kwargs):
                # The original failure/event inventory must already exist even
                # if this first best-effort diagnostic never returns.
                original = json.loads((output / 'capture-report.json').read_text())
                self.assertEqual(original['error'], 'original driver failure')
                if args[0] == 'logcat':
                    raise host.subprocess.TimeoutExpired(['private-command', capture.token], 35)
                raise RuntimeError('device offline')
            with patch.object(host, 'OUTPUT', output), patch.object(host, 'adb', adb):
                with self.assertRaisesRegex(ValueError, 'original driver failure'):
                    try:
                        raise ValueError('original driver failure')
                    finally:
                        host.finalize_capture(capture, server, 1234)
            report = json.loads((output / 'capture-report.json').read_text())
            self.assertEqual(report['error'], 'original driver failure')
            self.assertFalse(report['passed'])
            self.assertEqual([x['stage'] for x in report['cleanupErrors']], ['collect-logcat', 'remove-owned-reverse'])
            self.assertNotIn(capture.token, json.dumps(report))
            self.assertEqual(calls, ['shutdown', 'close'])

    def test_cleanup_failure_cannot_turn_completed_capture_into_accepted_success(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-final-report-') as directory:
            capture = host.Capture();capture.report['passed'] = True
            calls = []
            def shutdown():
                calls.append('shutdown')
                raise RuntimeError('server close failed')
            server = SimpleNamespace(shutdown=shutdown, server_close=lambda:calls.append('close'))
            with patch.object(host, 'OUTPUT', Path(directory)), patch.object(host, 'adb', return_value=SimpleNamespace(stdout='')):
                with self.assertRaisesRegex(RuntimeError, 'not accepted'):
                    host.finalize_capture(capture, server, 1234)
            self.assertFalse(json.loads((Path(directory) / 'capture-report.json').read_text())['passed'])
            self.assertEqual(calls, ['shutdown', 'close'])

    def test_clean_finalization_preserves_actual_success_and_original_events(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-final-report-') as directory:
            capture = host.Capture();capture.report.update(passed=True, events=[{'original':'owned snapshot'}])
            server = SimpleNamespace(shutdown=lambda:None, server_close=lambda:None)
            with patch.object(host, 'OUTPUT', Path(directory)), patch.object(host, 'adb', return_value=SimpleNamespace(stdout='real diagnostic output')):
                self.assertEqual(host.finalize_capture(capture, server, 1234), [])
            report = json.loads((Path(directory) / 'capture-report.json').read_text())
            self.assertTrue(report['passed'])
            self.assertEqual(report['events'], [{'original':'owned snapshot'}])
            self.assertFalse((Path(directory) / 'capture-report.json.tmp').exists())

    def test_original_scene_frame_scaler_witness_is_retained_not_reconstructed(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-shot-witness-') as directory:
            root = Path(directory);(root / 'screenshots').mkdir()
            witness = {'expectedScene':'05-editor-drawn', 'matchedEngineFrameNumber':9, 'rasterFrameNumber':9,
                       'matchedFrameworkSnapshot':{'platformNominalTextScaleFactor':2.0, 'actualScaledFonts':{'14':28.0}}}
            with patch.object(host, 'OUTPUT', root), patch.object(host, 'adb', return_value=SimpleNamespace(stdout=b'\x89PNG\r\n\x1a\nowned-native-pixels')):
                capture = host.Capture()
                capture.event({'token':capture.token, 'sequence':1, 'operation':'snapshot', 'name':'05-editor-drawn', 'screenshotReadiness':witness})
                report = json.loads((root / 'capture-progress.json').read_text())
                self.assertEqual(report['events'][0]['screenshotReadiness'], witness)
                self.assertNotIn(capture.token, json.dumps(report))
                for bad in (witness | {'expectedScene':'wrong-scene'}, witness | {'rasterFrameNumber':10},
                            witness | {'rasterFrameNumber':True}, witness | {'matchedEngineFrameNumber':True},
                            witness | {'extra':'x' * 16_384}):
                    invalid = host.Capture()
                    with self.assertRaises(ValueError):
                        invalid.event({'token':invalid.token, 'sequence':1, 'operation':'snapshot', 'name':'05-editor-drawn', 'screenshotReadiness':bad})
                    self.assertEqual(invalid.report['events'], [])

    def test_timeout_report_and_trace_never_expose_command_or_capability(self):
        token='private-one-job-capability'
        original=host.subprocess.TimeoutExpired(['private-command','--dart-define=UI_CAPTURE_TOKEN='+token],1200)
        message=host.safe_capture_error(original,token)
        try:
            try: raise original
            except host.subprocess.TimeoutExpired as error:
                host.raise_capture_failure(error,token)
        except RuntimeError as error:
            trace=''.join(traceback.format_exception(error))
        self.assertIn('exceeded 1200s',message)
        for sensitive in (token,'private-command','--dart-define=UI_CAPTURE_TOKEN='):
            self.assertNotIn(sensitive,message)
            self.assertNotIn(sensitive,trace)

    def test_encoded_start_timeout_cleans_owned_native_and_adb_child(self):
        self.failed_start_cleanup(changed_identity=False)

    def test_encoded_start_identity_change_never_signals_other_native_pid(self):
        self.failed_start_cleanup(changed_identity=True)

    def failed_start_cleanup(self, *, changed_identity):
        class StalledAdb:
            stopped = False
            terminated = False
            def poll(self): return -15 if self.stopped else None
            def wait(self, timeout):
                if not self.stopped: raise host.subprocess.TimeoutExpired('owned-adb',timeout)
                return -15
            def terminate(self): self.terminated=True; self.stopped=True
            def kill(self): raise AssertionError('Terminate already completed')
        with tempfile.TemporaryDirectory(prefix='drawmusic-start-cleanup-') as directory:
            log=(Path(directory)/'record.log').open('w')
            log.write('Original encoder diagnostic preserved\n')
            process=StalledAdb();capture=host.Capture();calls=[]
            def adb(*args, **kwargs):
                calls.append(args)
                return SimpleNamespace(stdout='different native command' if changed_identity else '/owned/exact.mp4')
            with patch.object(host,'adb',adb):
                capture._cleanup_failed_start('/owned/exact.mp4','123',process,log,RuntimeError('encoded readiness timed out'))
            self.assertTrue(log.closed)
            self.assertTrue(process.terminated)
            self.assertIsNone(capture.recording)
            self.assertEqual(any(call[:2]==('shell','kill') for call in calls),not changed_identity)
            diagnostic=capture.report['recorderStartupFailures'][0]
            self.assertIn('Original encoder diagnostic',diagnostic['logTail'])
            self.assertEqual(diagnostic['nativeSignalSent'],not changed_identity)

    def test_actual_png_decoder_rejects_flat_splash_but_accepts_presented_content(self):
        def png(content):
            def chunk(kind, data):
                return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
            raw=b''.join(b'\0'+b''.join(bytes((85,223,245) if content and x<40 else (9,11,24)) for x in range(80)) for _ in range(160))
            return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',80,160,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
        self.assertLess(host.presented_scene_evidence(png(False))['centralForegroundRatio'], .02)
        self.assertGreater(host.presented_scene_evidence(png(True))['centralForegroundRatio'], .02)

    def exercise(self, *, failure='unable to configure video/avc codec', wrong_owner=False, readiness_error=None):
        calls, created, clock = [], [], [0.]
        def popen(command, stdout, stderr):
            created.append(command)
            if len(created) == 1 and not wrong_owner:
                stdout.write('ERROR: ' + failure + '\n'); stdout.flush()
                return Process(1)
            return Process(None)
        def adb(*args, **kwargs):
            calls.append(args)
            if args == ('shell', 'cat', '/proc/uptime'):
                return SimpleNamespace(stdout='100.0 50.0')
            if args[:2] == ('shell', 'pidof'):
                return SimpleNamespace(stdout='123' if created else '')
            if args[:2] == ('shell', 'cat'):
                return SimpleNamespace(stdout='unrelated recording' if wrong_owner else '\x00'.join(created[-1]))
            return SimpleNamespace(stdout='')
        def sleep(seconds): clock[0] += seconds
        with tempfile.TemporaryDirectory(prefix='drawmusic-recorder-test-') as directory:
            output = Path(directory); (output/'recordings').mkdir()
            with patch.object(host, 'OUTPUT', output), patch.object(host, 'adb', adb), patch.object(host.subprocess, 'Popen', popen), patch.object(host.time, 'monotonic', lambda:clock[0]), patch.object(host.time, 'sleep', sleep), patch.object(host.Capture, '_await_encoded_media', return_value={'ready':True,'scope':'Mocked host orchestration only; separate actual MP4 parser tests'}, side_effect=readiness_error):
                capture = host.Capture()
                try:
                    settings = capture.record_start('00-home-ambient')
                except RuntimeError as error:
                    return None, str(error), calls, created
                capture.recording[4].close()
                return settings, None, calls, created

    def test_known_codec_configuration_failure_uses_bounded_portrait_fallback(self):
        settings, error, calls, created = self.exercise()
        self.assertIsNone(error)
        self.assertEqual((settings['width'], settings['height']), (432,960))
        self.assertEqual(len(created), 2)
        self.assertEqual(len(settings['codecFallbackAttempts']), 1)
        self.assertFalse(any(call[:2] == ('shell','kill') for call in calls))

    def test_record_start_readiness_exception_reaches_guarded_cleanup(self):
        settings,error,calls,created=self.exercise(readiness_error=RuntimeError('Actual encoded readiness timeout'))
        self.assertIsNone(settings)
        self.assertIn('readiness timeout',error)
        self.assertTrue(any(call[:2]==('shell','kill') for call in calls))

    def test_unknown_startup_failure_does_not_retry_or_claim_success(self):
        settings, error, calls, created = self.exercise(failure='unrelated encoder failure')
        self.assertIsNone(settings)
        self.assertIn('exited before startup', error)
        self.assertEqual(len(created), 1)

    def test_unrelated_process_is_never_signaled_or_used_as_recording(self):
        settings, error, calls, created = self.exercise(wrong_owner=True)
        self.assertIsNone(settings)
        self.assertIn('identity differs', error)
        self.assertEqual(len(created), 1)
        self.assertFalse(any(call[:2] == ('shell','kill') for call in calls))

    def test_lost_recording_identity_closes_log_and_never_signals(self):
        with tempfile.TemporaryDirectory(prefix='drawmusic-recorder-stop-') as directory:
            log = (Path(directory)/'record.log').open('w')
            capture = host.Capture()
            capture.recording = ('ambient', '/owned/exact.mp4', '123', Process(1), log, {'width':432,'height':960})
            calls = []
            def adb(*args, **kwargs):
                calls.append(args)
                return SimpleNamespace(stdout='a different process')
            with patch.object(host, 'adb', adb):
                with self.assertRaisesRegex(RuntimeError, 'refusing signal'):
                    capture.record_stop()
            self.assertTrue(log.closed)
            self.assertIsNone(capture.recording)
            self.assertFalse(any(call[:2] == ('shell','kill') for call in calls))


class StaticBackdropProtocol(unittest.TestCase):
    """Protocol fixtures only: never native/rendering performance evidence."""
    def result(self, solid):
        sample = {'backdropSolid': solid, 'sameAuroraStateControllerTexture': True,
                  'auroraIsAnimating': True, 'auroraTickerModeEnabled': True,
                  'appLifecycle': 'resumed', 'reducedMotion': False, 'timeDilation': 1,
                  'staticCacheRawImages': [{'width': 774, 'height': 816}]}
        return {'diagnosticOnly': True, 'rawFrames': [{'frameNumber': 1}],
                'visibleScope': {'diagnosticOnly': True, 'solidMode': solid,
                    'nominalObservationMilliseconds': 17000,
                    'clockSamples': [copy.deepcopy(sample) for _ in range(34)]}}

    def emit(self, capture, operation, name='static-backdrop-probe', **extra):
        return capture.event({'token': capture.token, 'sequence': capture.sequence + 1,
                              'operation': operation, 'name': name, **extra})

    def phases(self, capture):
        self.emit(capture, 'metadata', 'session', buildMode='profile', animationsDisabled=False,
                  captureMode='diagnostic-static-backdrop-only')
        for index, name in enumerate(host.PROBE_PROFILES):
            self.emit(capture, 'perf_start', name)
            self.emit(capture, 'perf_finish', name, result=self.result(bool(index)))

    def restore(self, capture, **changes):
        value = {'diagnosticOnly': True, 'exactDecorationRestored': True, 'freshLookupSameTarget': True,
                 'restoredRasterEvidence': {'manualFrameRequests': 0, 'matchedNaturalFrames': [
                     {'rasterFrameNumber': 20, 'matchedEngineFrameNumber': 20},
                     {'rasterFrameNumber': 21, 'matchedEngineFrameNumber': 21}]}}
        value.update(changes)
        return self.emit(capture, 'static_backdrop_restored', **value)

    def test_diagnostic_is_separate_and_requires_both_real_profiles_and_final_restoration(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(host, 'OUTPUT', Path(directory)), patch.object(host, 'adb', return_value=SimpleNamespace(stdout='fixture')):
            (Path(directory)/'performance').mkdir()
            capture = host.Capture(static_backdrop_probe=True)
            self.phases(capture)
            with self.assertRaisesRegex(ValueError, 'Incomplete diagnostic'):
                self.emit(capture, 'diagnostic_complete', passed=True, diagnosticOnly=True, normalFootageProduced=False)
            self.restore(capture)
            self.emit(capture, 'diagnostic_complete', passed=True, diagnosticOnly=True, normalFootageProduced=False)
            self.assertTrue(capture.complete)
            self.assertTrue(capture.report['diagnosticPassed'])
            self.assertFalse(capture.report['normalProductCapturePassed'])
            self.assertFalse(capture.report['normalFootageProduced'])

    def test_probe_never_accepts_normal_footage_or_normal_completion(self):
        with patch.object(host, 'adb') as adb:
            for operation in ('snapshot', 'record_start', 'record_stop', 'complete', 'display'):
                capture = host.Capture(static_backdrop_probe=True)
                with self.assertRaisesRegex(ValueError, 'rejects normal'):
                    self.emit(capture, operation)
                self.assertFalse(capture.complete)
            adb.assert_not_called()
        capture = host.Capture()
        with self.assertRaisesRegex(ValueError, 'Incomplete diagnostic'):
            self.emit(capture, 'diagnostic_complete', passed=True, diagnosticOnly=True, normalFootageProduced=False)

    def test_changed_cache_or_fake_restoration_frames_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(host, 'OUTPUT', Path(directory)), patch.object(host, 'adb', return_value=SimpleNamespace(stdout='fixture')):
            (Path(directory)/'performance').mkdir()
            capture = host.Capture(static_backdrop_probe=True)
            self.emit(capture, 'perf_start', host.PROBE_PROFILES[0])
            self.emit(capture, 'perf_finish', host.PROBE_PROFILES[0], result=self.result(False))
            self.emit(capture, 'perf_start', host.PROBE_PROFILES[1])
            changed = self.result(True)
            changed['visibleScope']['clockSamples'][-1]['staticCacheRawImages'][0]['width'] = 775
            with self.assertRaisesRegex(ValueError, 'texture changed'):
                self.emit(capture, 'perf_finish', host.PROBE_PROFILES[1], result=changed)
            self.assertFalse(capture.complete)
            for field, value in [('freshLookupSameTarget', False), ('exactDecorationRestored', False)]:
                with self.assertRaisesRegex(ValueError, 'restoration'):
                    self.restore(capture, **{field: value})
            with self.assertRaisesRegex(ValueError, 'restoration'):
                self.restore(capture, restoredRasterEvidence={'manualFrameRequests': 1, 'matchedNaturalFrames': []})

    def test_host_cpu_context_excludes_serial_and_machine_identifiers(self):
        files = {'/proc/cpuinfo': 'model name : Example CPU\nSerial : sensitive-fixture\n',
                 '/sys/fs/cgroup/cpu.max': '400000 100000'}
        with patch.object(host.subprocess, 'run', return_value=SimpleNamespace(stdout='4\n')), patch.object(host.Path, 'read_text', autospec=True, side_effect=lambda path: files[str(path)]):
            context = host.host_cpu_context()
        self.assertEqual(context['nproc'], 4)
        self.assertEqual(context['cgroupCpuMax'], '400000 100000')
        self.assertEqual(context['cpuModel'], 'Example CPU')
        self.assertNotIn('sensitive-fixture', str(context))




class ResponsiveSubsetProtocol(unittest.TestCase):
    """Protocol fixtures only; screenshots below are fake ADB test bytes."""
    def emit(self, capture, operation, name, **extra):
        return capture.event({'token': capture.token, 'sequence': capture.sequence + 1,
                              'operation': operation, 'name': name, **extra})

    def metadata(self, capture, preset):
        return self.emit(capture, 'metadata', 'session', buildMode='profile', animationsDisabled=False,
                         captureMode='responsive-' + preset)

    def snapshot(self, capture, name):
        return self.emit(capture, 'snapshot', name, screenshotReadiness={
            'expectedScene': name, 'matchedEngineFrameNumber': 5, 'rasterFrameNumber': 5,
            'matchedFrameworkSnapshot': {'platformNominalTextScaleFactor': 2}})

    def test_each_exact_two_shot_subset_reports_only_subset_success_and_keeps_readiness(self):
        for preset, names in host.RESPONSIVE_SHOTS.items():
            with self.subTest(preset=preset), tempfile.TemporaryDirectory() as directory, patch.object(host, 'OUTPUT', Path(directory)), patch.object(host, 'adb', return_value=SimpleNamespace(stdout=b'\x89PNG\r\n\x1a\nunit-fixture')):
                (Path(directory)/'screenshots').mkdir()
                capture = host.Capture(responsive_preset=preset)
                self.metadata(capture, preset)
                for name in names: self.snapshot(capture, name)
                self.emit(capture, 'responsive_complete', preset, passed=True, subsetOnly=True,
                          responsivePreset=preset, normalFullCapturePassed=False)
                self.assertTrue(capture.complete)
                self.assertTrue(capture.report['responsiveSubsetPassed'])
                self.assertFalse(capture.report['normalFullCapturePassed'])
                self.assertEqual(capture.report['completedScreenshotNames'], list(names))
                shots = [event for event in capture.report['events'] if event['operation'] == 'snapshot']
                self.assertEqual([event['screenshotReadiness']['expectedScene'] for event in shots], list(names))

    def test_invalid_or_conflicting_presets_and_metadata_modes_fail_closed(self):
        for preset in ('phone', '', 'large', 2):
            with self.assertRaisesRegex(ValueError, 'Unknown or conflicting'):
                host.Capture(responsive_preset=preset)
        with self.assertRaisesRegex(ValueError, 'Unknown or conflicting'):
            host.Capture(responsive_preset='compact', static_backdrop_probe=True)
        capture = host.Capture(responsive_preset='compact')
        with self.assertRaisesRegex(ValueError, 'mode mismatch'):
            self.metadata(capture, 'tablet')

    def test_missing_duplicate_wrong_set_or_unwitnessed_shots_cannot_complete(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(host, 'OUTPUT', Path(directory)), patch.object(host, 'adb', return_value=SimpleNamespace(stdout=b'\x89PNG\r\n\x1a\nunit-fixture')):
            (Path(directory)/'screenshots').mkdir()
            capture = host.Capture(responsive_preset='compact')
            self.metadata(capture, 'compact')
            first, second = host.RESPONSIVE_SHOTS['compact']
            self.snapshot(capture, first)
            with self.assertRaisesRegex(ValueError, 'Incomplete'):
                self.emit(capture, 'responsive_complete', 'compact', passed=True, subsetOnly=True,
                          responsivePreset='compact', normalFullCapturePassed=False)
            with self.assertRaisesRegex(ValueError, 'exactly'):
                self.snapshot(capture, first)
            with self.assertRaisesRegex(ValueError, 'exactly'):
                self.snapshot(capture, host.RESPONSIVE_SHOTS['tablet'][1])
            with self.assertRaisesRegex(ValueError, 'original exact-frame'):
                self.emit(capture, 'snapshot', second)
            self.assertEqual(capture.responsive_snapshots, [first])
            self.assertFalse(capture.complete)

    def test_responsive_never_starts_recording_profile_live_display_or_full_completion(self):
        with patch.object(host, 'adb') as adb:
            for operation in ('record_start', 'record_stop', 'perf_start', 'perf_finish', 'display', 'complete', 'diagnostic_complete'):
                capture = host.Capture(responsive_preset='compact')
                with self.assertRaisesRegex(ValueError, 'rejects recording'):
                    self.emit(capture, operation, 'compact')
                self.assertFalse(capture.complete)
            adb.assert_not_called()
        with self.assertRaisesRegex(ValueError, 'Incomplete or mismatched'):
            self.emit(host.Capture(), 'responsive_complete', 'compact', passed=True,
                      subsetOnly=True, responsivePreset='compact', normalFullCapturePassed=False)


if __name__ == '__main__': unittest.main()
