#!/usr/bin/env python3
import importlib.util
import copy
import contextlib
import io
import subprocess
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runtime_inspect', Path(__file__).with_name('inspect-runtime-artifact.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
REQUEST = {'mode': 'runtime', 'runId': 40525650391, 'artifactId': 12748102114, 'artifactName': 'drawmusic-runtime-evidence-' + 'a' * 40}
ui_spec = importlib.util.spec_from_file_location('ui_inspect', Path(__file__).with_name('inspect-ui-capture.py'))
ui = importlib.util.module_from_spec(ui_spec)
ui_spec.loader.exec_module(ui)


class RuntimeInspectionTest(unittest.TestCase):
    def test_exact_attempt_request_rejects_arbitrary_paths_and_ui_name(self):
        module.validate_request(REQUEST)
        for change in ({'artifactId': True}, {'artifactName': 'drawmusic-ui-visuals-' + 'a' * 40}, {'path': '/etc/passwd'}, {'transportPath': 'work/runtime-output/arbitrary.json'}, {'runId': -1}):
            with self.assertRaises(ValueError):
                module.validate_request(REQUEST | change)

    def test_real_files_emit_android_signals_host_and_actual_native_cases_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            log = root / 'work/runtime-output/android.log'
            log.parent.mkdir(parents=True)
            log.write_text('native start\nFATAL EXCEPTION: main\nService connection disposed\n')
            (log.parent / 'hd-background-host.json').write_text(json.dumps({'passed': False}))
            (log.parent / 'runtime-transport-failure.json').write_text(json.dumps({'qemuVerified': False, 'host': {'memory': {'MemAvailable': '128kB'}}}))
            junit = root / module.JUNIT_ROOT / 'connected/debug/TEST-Pixel.xml'
            junit.parent.mkdir(parents=True)
            junit.write_text('<testsuite tests="1" failures="0"><testcase name="actualCodec" classname="NativeTest" time="2.1"/></testsuite>')
            secret = root / 'arbitrary-secret.txt'
            secret.write_text('NEVER PRINT THIS')
            emitted = []
            module.inspect(root, REQUEST, emitted.append)
            text = '\n'.join(emitted)
            self.assertIn('FATAL EXCEPTION: main', text)
            self.assertIn('actualCodec', text)
            self.assertIn('MemAvailable', text)
            self.assertIn('runtime-transport-failure.json', text)
            self.assertIn('"passed": false', text)
            self.assertNotIn('NEVER PRINT THIS', text)

    def test_missing_or_oversized_files_fail_instead_of_partial_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST, lambda _: None)
            log = root / 'work/runtime-output/android.log'
            log.parent.mkdir(parents=True)
            with log.open('wb') as file:
                file.truncate(8 * 1024 * 1024 + 1)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST, lambda _: None)
            log.unlink()
            transport = log.parent / 'runtime-transport-failure.json'
            with transport.open('wb') as file:
                file.truncate(128 * 1024 + 1)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST, lambda _: None)

    def test_symlink_and_xml_entity_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'work/runtime-output'
            folder.mkdir(parents=True)
            target = root / 'secret'
            target.write_text('secret')
            (folder / 'android.log').symlink_to(target)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST, lambda _: None)
            (folder / 'android.log').unlink()
            junit = root / module.JUNIT_ROOT / 'TEST-native.xml'
            junit.parent.mkdir(parents=True)
            junit.write_text('<!DOCTYPE testsuite [<!ENTITY secret SYSTEM "file:///etc/passwd">]><testsuite/>')
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST, lambda _: None)


class UiPartialInspectionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.root_patch = patch.object(ui, 'ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.report = {'passed': False, 'events': []}
        self.progress = self.root / 'capture-progress.json'
        self.progress.write_text(json.dumps(self.report))

    def test_missing_final_uses_original_progress_only_in_explicit_diagnostic_mode(self):
        for request in ({}, {'ambientMotionDiagnostic': False}, {'ambientMotionDiagnostic': 1}):
            with self.assertRaises(ValueError): ui.load_capture_report(request)
        report = ui.load_capture_report({'ambientMotionDiagnostic': True})
        self.assertIs(report['passed'], False)
        self.assertEqual(report['reportSource'], 'capture-progress.json')
        self.assertEqual(report['inspectionStatus'], 'UNACCEPTED_DIAGNOSTIC_ONLY')
        self.assertEqual(report['events'], [])

    def test_present_invalid_final_never_falls_back_and_normal_final_remains_final(self):
        final = self.root / 'capture-report.json'
        for value in ('not json', '[]', '{"passed":false,"events":{}}'):
            final.write_text(value)
            with self.assertRaises((ValueError, json.JSONDecodeError)):
                ui.load_capture_report({'ambientMotionDiagnostic': True})
        final.write_text(json.dumps({'passed': True, 'events': []}))
        result = ui.load_capture_report({})
        self.assertTrue(result['passed'])
        self.assertEqual(result['reportSource'], 'capture-report.json')
        self.assertNotIn('inspectionStatus', result)

    def test_progress_must_be_bounded_regular_original_failed_manifest(self):
        for report in ({'passed': True, 'events': []}, {'passed': 0, 'events': []},
                       {'passed': False, 'events': [None]}, {'passed': False, 'events': [{}]},
                       {'passed': False, 'events': [{'name': '01-home', 'operation': 'snapshot'}]}):
            self.progress.write_text(json.dumps(report))
            with self.assertRaises(ValueError): ui.load_capture_report({'ambientMotionDiagnostic': True})
        self.progress.write_bytes(b' ' * (1_048_576 + 1))
        with self.assertRaises(ValueError): ui.load_capture_report({'ambientMotionDiagnostic': True})
        self.progress.unlink()
        with self.assertRaises(ValueError): ui.load_capture_report({'ambientMotionDiagnostic': True})
        secret = self.root / 'other'
        secret.write_text(json.dumps(self.report))
        self.progress.symlink_to(secret)
        with self.assertRaises(ValueError): ui.load_capture_report({'ambientMotionDiagnostic': True})

    def test_partial_snapshot_still_requires_original_sha_and_bytes(self):
        data = b'\x89PNG\r\n\x1a\noriginal-owned-capture'
        folder = self.root / 'screenshots'
        folder.mkdir()
        (folder / '01-home.png').write_bytes(data)
        item = {'operation': 'snapshot', 'name': '01-home', 'bytes': len(data),
                'sha256': hashlib.sha256(data).hexdigest()}
        self.progress.write_text(json.dumps({'passed': False, 'events': [item]}))
        result = ui.load_capture_report({'ambientMotionDiagnostic': True})
        expected = {'01-home.png': result['events'][0]}
        self.assertEqual(ui.verified_png('01-home.png', expected, 1000), data)
        for change in ({'sha256': '0' * 64}, {'bytes': len(data) + 1}):
            with self.assertRaises(ValueError): ui.verified_png('01-home.png', {'01-home.png': item | change}, 1000)

    def test_partial_media_rejects_missing_start_and_mismatched_recorded_sha_or_bytes(self):
        folder = self.root / 'recordings'
        folder.mkdir()
        clip = folder / '00-home-ambient.mp4'
        clip.write_bytes(b'owned-avc' * 200)
        start = {'operation': 'record_start', 'name': '00-home-ambient'}
        stop = {'operation': 'record_stop', 'name': '00-home-ambient', 'bytes': clip.stat().st_size,
                'sha256': hashlib.sha256(clip.read_bytes()).hexdigest()}
        for events in ([stop], [start, stop | {'sha256': '0' * 64}], [start, stop | {'bytes': 2}]):
            with patch.object(ui.subprocess, 'run') as process:
                with self.assertRaises(ValueError):
                    ui.inspect_ambient_recording({'ambientMotionDiagnostic': True}, {'events': events, 'passed': False})
                process.assert_not_called()


class OriginalInteractionInspection(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.folder = self.root / 'recordings'
        self.folder.mkdir()
        self.patch = patch.object(ui, 'ROOT', self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.report = {'passed': False, 'reportSource': 'capture-progress.json', 'events': []}
        for i, name in enumerate(ui.INTERACTION_RECORDINGS):
            data = (name.encode() + b'owned-fixture') * 100
            (self.folder / (name + '.mp4')).write_bytes(data)
            self.report['events'] += [
                {'operation': 'record_start', 'name': name, 'sequence': i * 2 + 1},
                {'operation': 'record_stop', 'name': name, 'sequence': i * 2 + 2,
                 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()},
            ]
        self.metadata = {'format': {'duration': '0.5'}, 'streams': [{'codec_name': 'h264', 'width': 720, 'height': 1600, 'nb_read_frames': '2'}]}
        self.packets = {'packets': [{'pts_time': '0.0', 'dts_time': '0.0'}, {'pts_time': '0.25', 'dts_time': '0.25'}]}

    def result(self, value):
        return subprocess.CompletedProcess([], 0, json.dumps(value), '')

    def invoke(self, runner):
        output = io.StringIO()
        with patch.object(ui.subprocess, 'run', side_effect=runner), contextlib.redirect_stdout(output):
            ui.inspect_interaction_recordings({'interactionMotionDiagnostic': True}, self.report)
        return output.getvalue()

    def test_explicit_boolean_only_and_default_does_no_subprocess_work(self):
        with patch.object(ui.subprocess, 'run') as run:
            ui.inspect_interaction_recordings({}, self.report)
            with self.assertRaises(ValueError): ui.inspect_interaction_recordings({'interactionMotionDiagnostic': 1}, self.report)
            run.assert_not_called()

    def test_all_six_original_clips_keep_diagnostic_status_and_decode_whole_stream(self):
        calls = []
        def run(command, **kwargs):
            calls.append((command, kwargs))
            if command[0] == 'ffmpeg': return self.result({})
            return self.result(self.packets if '-show_packets' in command else self.metadata)
        text = self.invoke(run)
        self.assertEqual(text.count('UI_INTERACTION_RECORDING_METADATA '), 6)
        self.assertEqual(text.count('"wholeVideoDecodePassed": true'), 6)
        self.assertNotIn('"captureReportPassed": true', text)
        decodes = [command for command, _ in calls if command[0] == 'ffmpeg']
        self.assertEqual(len(decodes), 6)
        for command in decodes:
            self.assertIn('-xerror', command)
            self.assertIn('explode', command)
            self.assertNotIn('-t', command)
            self.assertNotIn('-ss', command)
        self.assertTrue(all(kwargs['timeout'] == 30 for _, kwargs in calls))

    def test_original_start_stop_order_hash_bytes_and_exact_path_required(self):
        stop = self.report['events'][1]
        for change in ({'sha256': '0' * 64}, {'bytes': stop['bytes'] + 1}, {'sequence': 0}):
            original = stop.copy()
            stop.update(change)
            with patch.object(ui.subprocess, 'run') as run:
                with self.assertRaises(ValueError): ui.inspect_interaction_recordings({'interactionMotionDiagnostic': True}, self.report)
                run.assert_not_called()
            stop.update(original)
        self.report['events'].pop(0)
        with self.assertRaises(ValueError): self.invoke(lambda *_a, **_k: self.fail('unowned subprocess'))

    def test_symlink_and_duplicate_start_fail_before_decode(self):
        path = self.folder / (ui.INTERACTION_RECORDINGS[0] + '.mp4')
        path.rename(self.root / 'unrelated')
        path.symlink_to(self.root / 'unrelated')
        with self.assertRaises(ValueError): self.invoke(lambda *_a, **_k: self.fail('symlink subprocess'))
        path.unlink()
        (self.root / 'unrelated').rename(path)
        self.report['events'].append(self.report['events'][0].copy())
        with self.assertRaises(ValueError): self.invoke(lambda *_a, **_k: self.fail('duplicate subprocess'))

    def test_nonfinite_pts_and_reversed_dts_rejected_before_decoder(self):
        for packets in ([{'pts_time': 'nan', 'dts_time': '0'}], [{'pts_time': '1', 'dts_time': '1'}, {'pts_time': '0', 'dts_time': '0'}], []):
            def run(command, **kwargs):
                self.assertNotEqual(command[0], 'ffmpeg')
                return self.result({'packets': packets} if '-show_packets' in command else self.metadata)
            with self.assertRaises(ValueError): self.invoke(run)

    def test_valid_b_frame_presentation_reordering_is_reported_not_rejected(self):
        self.packets = {'packets': [
            {'pts_time': '0.0', 'dts_time': '-0.25'},
            {'pts_time': '0.375', 'dts_time': '-0.125'},
            {'pts_time': '0.125', 'dts_time': '0.0'},
            {'pts_time': '0.25', 'dts_time': '0.125'},
        ]}
        def run(command, **kwargs):
            return self.result({} if command[0] == 'ffmpeg' else self.packets if '-show_packets' in command else self.metadata)
        self.assertEqual(self.invoke(run).count('"wholeVideoDecodePassed": true'), 6)

    def test_decode_failure_and_timeout_remain_explicit_not_success(self):
        for error in (subprocess.CalledProcessError(1, ['ffmpeg'], stderr='broken AVC'), subprocess.TimeoutExpired(['ffmpeg'], 30)):
            def run(command, **kwargs):
                if command[0] == 'ffmpeg': raise error
                return self.result(self.packets if '-show_packets' in command else self.metadata)
            text = self.invoke(run)
            self.assertEqual(text.count('"wholeVideoDecodePassed": false'), 6)
            self.assertNotIn('"wholeVideoDecodePassed": true', text)
            self.assertIn('UNACCEPTED_DIAGNOSTIC_ONLY', text)


    def test_contact_names_are_explicit_unique_fixed_and_at_most_two(self):
        for names in (True, '../private.mp4', ['../private'], list(ui.INTERACTION_RECORDINGS[:3]), [ui.INTERACTION_RECORDINGS[0]] * 2):
            with self.assertRaises(ValueError): ui.interaction_contact_names({'interactionMotionDiagnostic': True, 'interactionContactNames': names})
        with self.assertRaises(ValueError): ui.interaction_contact_names({'interactionContactNames': [ui.INTERACTION_RECORDINGS[0]]})
        self.assertEqual(ui.interaction_contact_names({}), [])

    def test_actual_three_frame_contact_emits_declared_pts_without_retiming_original(self):
        png = b'\x89PNG\r\n\x1a\nfixture'
        stderr = b'[Parsed_showinfo] n:0 pts:0 pts_time:0.0\n[Parsed_showinfo] n:1 pts:20 pts_time:2.0\n[Parsed_showinfo] n:2 pts:40 pts_time:4.0\n'
        with patch.object(ui.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, png, stderr)) as run, patch.object(ui, 'emit_png') as emit, contextlib.redirect_stdout(io.StringIO()) as output:
            size = ui.interaction_contact(self.folder / '01-root-navigation.mp4', '01-root-navigation', 5, 100)
        self.assertEqual(size, len(png))
        self.assertIn('"actualDecodedPtsSeconds": [0.0, 2.0, 4.0]', output.getvalue())
        self.assertIn('UNACCEPTED_DIAGNOSTIC_ONLY', output.getvalue())
        command = run.call_args.args[0]
        self.assertNotIn('-r', command)
        self.assertNotIn('-ss', command)
        self.assertNotIn('-t', command)
        self.assertEqual(command[-1], 'pipe:1')
        emit.assert_called_once_with('01-root-navigation-contact.png', png, motion=True)

    def test_contact_rejects_missing_pts_too_few_frames_and_combined_byte_overflow(self):
        png = b'\x89PNG\r\n\x1a\nfixture'
        times = b'n:0 pts_time:0\nn:1 pts_time:2\nn:2 pts_time:4\n'
        for frames, remaining, stderr in ((2, 100, times), (5, 1, times), (5, 100, b'')):
            with patch.object(ui.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, png, stderr)), patch.object(ui, 'emit_png') as emit:
                with self.assertRaises(ValueError): ui.interaction_contact(self.folder / '01-root-navigation.mp4', '01-root-navigation', frames, remaining)
                emit.assert_not_called()

    def test_dense_contact_samples_nine_real_ordinals_with_actual_pts_in_three_by_three(self):
        png = b'\x89PNG\r\n\x1a\nfixture'
        stderr = ''.join(f'n:{i} pts_time:{i / 2}\n' for i in range(9)).encode()
        with patch.object(ui.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, png, stderr)) as run, patch.object(ui, 'emit_png'), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(ui.interaction_contact(self.folder / '01-root-navigation.mp4', '01-root-navigation', 18, 100, dense=True), len(png))
        command = run.call_args.args[0]
        self.assertIn('tile=3x3', command[command.index('-vf') + 1])
        self.assertIn('"decodedFrameIndices": [0, 2, 4, 6, 8, 10, 12, 14, 17]', output.getvalue())
        self.assertIn('"actualDecodedPtsSeconds": [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]', output.getvalue())
        self.assertNotIn('-r', command)
        self.assertNotIn('-ss', command)

    def test_dense_contact_rejects_too_few_frames_and_missing_nine_distinct_pts(self):
        png = b'\x89PNG\r\n\x1a\nfixture'
        for frame_count, stderr in ((8, b''), (18, b'n:0 pts_time:0\nn:1 pts_time:1\nn:2 pts_time:2\n')):
            with patch.object(ui.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, png, stderr)), patch.object(ui, 'emit_png') as emit:
                with self.assertRaises(ValueError):
                    ui.interaction_contact(self.folder / '01-root-navigation.mp4', '01-root-navigation', frame_count, 100, dense=True)
                emit.assert_not_called()

    def test_contact_is_never_sampled_after_failed_original_whole_decode(self):
        def run(command, **kwargs):
            if command[0] == 'ffmpeg': raise subprocess.CalledProcessError(1, command, stderr='corrupt AVC')
            return self.result(self.packets if '-show_packets' in command else self.metadata)
        with patch.object(ui.subprocess, 'run', side_effect=run), patch.object(ui, 'interaction_contact') as contact, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ValueError): ui.inspect_interaction_recordings({'interactionMotionDiagnostic': True, 'interactionContactNames': [ui.INTERACTION_RECORDINGS[0]]}, self.report)
            contact.assert_not_called()


class NativeProfileResourceInspection(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.folder = self.root / 'performance'
        self.folder.mkdir()
        self.patcher = patch.object(ui, 'ROOT', self.root)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def inspect(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            ui.inspect_native_profile_resources()
        return [json.loads(line.split(' ', 1)[1]) for line in output.getvalue().splitlines()]

    def test_exact_whitelist_preserves_zero_counts_hashes_and_memory_scope(self):
        graphics = b'Total frames rendered: 0\nJanky frames: 0 (0.00%)\n95th percentile: 0ms\nFrameCompleted 123456\nPRIVATE_DEVICE_IDENTIFIER\n'
        memory = b' Native Heap 100 20 30 40 50 60 70\n Graphics: 88 99\n TOTAL PSS: 1234 TOTAL RSS: 4567 TOTAL SWAP PSS: 0\npid: PRIVATE_DEVICE_IDENTIFIER\n'
        (self.folder / 'home-ambient-visible-android-framestats.txt').write_bytes(graphics)
        (self.folder / 'home-ambient-visible-memory-before.txt').write_bytes(memory)
        values = self.inspect()
        self.assertEqual(len(values), 9)
        self.assertEqual(values[0]['summaryLines'], ['Total frames rendered: 0', 'Janky frames: 0 (0.00%)', '95th percentile: 0ms'])
        self.assertEqual(values[0]['sha256'], hashlib.sha256(graphics).hexdigest())
        self.assertEqual(values[0]['bytes'], len(graphics))
        self.assertIn('Graphics: 88 99', values[1]['summaryLines'])
        self.assertIn('not peak', values[1]['scope'])
        self.assertIn('not Flutter Surface', values[0]['scope'])
        self.assertNotIn('PRIVATE_DEVICE_IDENTIFIER', json.dumps(values))

    def test_missing_and_unavailable_are_explicit_never_inferred_zero(self):
        (self.folder / 'home-ambient-visible-memory-after.txt').write_text('Process unavailable\n')
        values = self.inspect()
        self.assertFalse(values[0]['available'])
        self.assertEqual(values[0]['reason'], 'missing')
        self.assertEqual(values[2]['summaryLines'], [])
        self.assertEqual(values[2]['summaryStatus'], 'unavailable_no_matching_summary')

    def test_oversized_symlink_and_directory_are_rejected(self):
        path = self.folder / 'home-ambient-visible-android-framestats.txt'
        path.write_bytes(b'x' * 65_537)
        with self.assertRaises(ValueError): self.inspect()
        path.unlink()
        path.symlink_to(self.root / 'private')
        with self.assertRaises(ValueError): self.inspect()
        path.unlink()
        path.mkdir()
        with self.assertRaises(ValueError): self.inspect()

    def test_unlisted_files_are_never_opened(self):
        (self.folder / 'private-memory.txt').symlink_to(self.root / 'private')
        self.assertTrue(all(not result['available'] for result in self.inspect()))


class TransitionRecordingSelection(unittest.TestCase):
    setUp = OriginalInteractionInspection.setUp
    result = OriginalInteractionInspection.result

    def subset(self):
        names = ['01-root-navigation', '06-reduced-motion']
        self.report.update(transitionCaptureOnly=True, normalFullCapturePassed=False)
        self.report['events'] = [item for item in self.report['events'] if item['name'] in names]
        return {'interactionMotionDiagnostic': True, 'interactionRecordingNames': names}

    def test_exact_declared_subset_decodes_only_original_two_recordings(self):
        request = self.subset()
        def run(command, **kwargs):
            return self.result({} if command[0] == 'ffmpeg' else self.packets if '-show_packets' in command else self.metadata)
        with patch.object(ui.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(io.StringIO()) as output:
            ui.inspect_interaction_recordings(request, self.report)
        self.assertEqual(output.getvalue().count('"wholeVideoDecodePassed": true'), 2)
        self.assertIn('UNACCEPTED_DIAGNOSTIC_ONLY', output.getvalue())

    def test_wrong_selection_or_undeclared_full_capture_cannot_narrow_inspection(self):
        request = self.subset()
        for names in ([], ['01-root-navigation'], ['../private', '06-reduced-motion'], ['06-reduced-motion', '01-root-navigation']):
            with self.assertRaises(ValueError): ui.inspect_interaction_recordings(request | {'interactionRecordingNames': names}, self.report)
        self.report['transitionCaptureOnly'] = False
        with self.assertRaises(ValueError): ui.inspect_interaction_recordings(request, self.report)

    def test_contact_for_uninspected_clip_is_rejected_before_any_probe(self):
        request = self.subset() | {'interactionContactNames': ['03-paper-sheet']}
        with patch.object(ui.subprocess, 'run') as run:
            with self.assertRaises(ValueError): ui.inspect_interaction_recordings(request, self.report)
            run.assert_not_called()


class GraphiteEvidenceInspection(unittest.TestCase):
    """Original-file guard fixtures, not native runtime or performance proof."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for folder in ('recordings', 'screenshots', 'performance'): (self.root/folder).mkdir()
        self.patch = patch.object(ui, 'ROOT', self.root); self.patch.start(); self.addCleanup(self.patch.stop)
        self.report = {'passed': True, 'graphiteCapture': True, 'graphiteSubsetPassed': True,
            'normalFullCapturePassed': False, 'reportSource': 'capture-report.json',
            'source': {'label': 'after', 'graphiteCapture': True,
                       'productSourceSha': 'a'*40, 'productTreeSha': 'b'*40, 'captureHarnessSourceSha': 'c'*40},
            'appMetadata': {'captureMode': 'graphite-reference-capture'},
            'finalSystemMotionReadbacks': {key:'1.0' for key in ui.MOTION_SETTINGS}, 'events': []}
        all_witnesses = {key:True for names in ui.GRAPHITE_WITNESSES.values() for key in names}
        for i,(operation,name) in enumerate(ui.GRAPHITE_EVENTS):
            event = {'operation':operation, 'name':name, 'sequence':i+1}
            self.report['events'].append(event)
            if operation == 'record_stop':
                data = (name.encode()+b'original-owned-fixture')*100
                (self.root/'recordings'/(name+'.mp4')).write_bytes(data)
                event.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), wholeVideoDecode={'passed':True})
            elif operation == 'snapshot':
                data=b'\x89PNG\r\n\x1a\noriginal-fixture';(self.root/'screenshots'/(name+'.png')).write_bytes(data)
                event.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                    snapshotCaptureState={'ownedRecorderActive':False,'profileActive':False}, screenshotReadiness={
                    'expectedScene':name,'matchedEngineFrameNumber':i+1,'rasterFrameNumber':i+1})
            elif operation == 'graphite_opening':
                self.write_json('graphite-opening.json', event, {'productionEntryPoint':'lib/main.dart', 'showWelcome':True,
                    'fixtureGuideAlreadyCompleted':True,'firstFrameRasterized':True,'readyHomeRendered':True,'launchEndedWithoutInput':True,
                    'observations':[{'elapsedUs':1,'engineFrameNumber':1,'controllerValue':.1},
                                    {'elapsedUs':2,'engineFrameNumber':2,'controllerValue':.8}]})
                event['actualControllerSamples']=2
            elif operation == 'graphite_trace':
                actions=[{'action':tag,'tapElapsedUs':j+1,'engineFrameNumber':j+1,
                          'reducedMotion':name==ui.GRAPHITE_RECORDINGS[-1], 'targetBounds':[0,0,48,48]}
                         for j,tag in enumerate(ui.GRAPHITE_ACTIONS[name])]
                self.write_json('graphite-'+name+'.json', event, {'actions':actions,'actualElapsedUs':1000,'witnesses':all_witnesses})
                event['actionCount']=len(actions)
            elif operation == 'system_motion':
                event['actualSystemReadbacks']={key:'0.0' if name=='reduced' else '1.0' for key in ui.MOTION_SETTINGS}
            elif operation == 'perf_finish':
                frames=[{'frameNumber':1,'vsyncUs':1,'rasterFinishWallUs':10,'buildUs':1000,'rasterUs':2000,'totalUs':3000},
                        {'frameNumber':2,'vsyncUs':2,'rasterFinishWallUs':20,'buildUs':2000,'rasterUs':22000,'totalUs':24000}]
                result={'refreshHz':60,'frameBudgetUs':1_000_000/60,'rawFrames':frames,
                        'visibleScope':{'screenRecordingActive':False,'graphiteProductionInteractions':True},
                        'eitherUiOrRasterOverBudgetFrames':1}
                for key,field in (('uiBuild','buildUs'),('raster','rasterUs'),('totalSpan','totalUs')):
                    values=sorted(f[field] for f in frames)
                    result[key]={'count':2,'maxUs':values[-1],'overBudgetFrames':sum(v>1_000_000/60 for v in values),
                        **{label:values[int((len(values)-1)*p+.5)] for label,p in (('p50Us',.5),('p90Us',.9),('p95Us',.95),('p99Us',.99))}}
                self.write_json('performance/graphite-interactions-unrecorded.json', event, result)
                event.update(recordingDuringMeasurement=False, frameSamples=2)
        self.request={'graphiteCaptureDiagnostic':True,'interactionMotionDiagnostic':True}
        self.metadata={'format':{'duration':'1.0'},'streams':[{'codec_name':'h264','width':720,'height':1600,'nb_read_frames':'9'}]}
        self.packets={'packets':[{'pts_time':str(i/9),'dts_time':str(i/9)} for i in range(9)]}

    def write_json(self, relative, event, value):
        data=(json.dumps(value,indent=2)+'\n').encode();(self.root/relative).write_bytes(data)
        event.update(evidenceFile=relative,evidenceBytes=len(data),evidenceSha256=hashlib.sha256(data).hexdigest())

    def inspect(self):
        with contextlib.redirect_stdout(io.StringIO()) as output: ui.inspect_graphite_evidence(self.report)
        return output.getvalue()

    def event(self, operation, name=None):
        return next(e for e in self.report['events'] if e['operation']==operation and (name is None or e['name']==name))

    def test_producer_and_reader_protocols_agree_and_recompute_original_raw_timings(self):
        spec=importlib.util.spec_from_file_location('graphite_producer',Path(__file__).with_name('capture-android-ui.py'))
        producer=importlib.util.module_from_spec(spec);spec.loader.exec_module(producer)
        self.assertEqual(ui.GRAPHITE_EVENTS,producer.GRAPHITE_EVENTS)
        self.assertEqual(ui.GRAPHITE_RECORDINGS,producer.GRAPHITE_CLIPS)
        self.assertEqual(ui.GRAPHITE_SHOTS,producer.GRAPHITE_SHOTS)
        self.assertEqual(ui.GRAPHITE_ACTIONS,producer.GRAPHITE_ACTIONS)
        text=self.inspect()
        self.assertIn('UI_GRAPHITE_OPENING ',text)
        self.assertEqual(text.count('UI_GRAPHITE_ACTION_TRACE '),4)
        self.assertIn('"actualSummaryRecomputed": true',text)
        self.assertIn('physical smoothness/audio/iOS',text)

    def test_all_five_originals_decode_without_trim_or_retiming_and_contacts_are_dense(self):
        calls=[]
        def run(command,**kwargs):
            calls.append((command,kwargs))
            return subprocess.CompletedProcess([],0,json.dumps({} if command[0]=='ffmpeg' else self.packets if '-show_packets' in command else self.metadata),'')
        request=self.request|{'interactionContactNames':[ui.GRAPHITE_RECORDINGS[0],ui.GRAPHITE_RECORDINGS[2]]}
        with patch.object(ui.subprocess,'run',side_effect=run),patch.object(ui,'interaction_contact',return_value=100) as contacts,contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(ui.inspect_interaction_recordings(request,self.report),200)
        self.assertEqual(output.getvalue().count('"wholeVideoDecodePassed": true'),5)
        self.assertEqual(contacts.call_count,2)
        self.assertTrue(all(call.kwargs['dense'] is True for call in contacts.call_args_list))
        decodes=[c for c,_ in calls if c[0]=='ffmpeg'];self.assertEqual(len(decodes),5)
        for command in decodes:
            for forbidden in ('-t','-ss','-r','-vsync'):self.assertNotIn(forbidden,command)
            self.assertIn('-xerror',command);self.assertIn('explode',command)
        self.assertTrue(all(k['timeout']==30 for _,k in calls))

    def test_completed_source_inventory_and_restoration_cannot_be_forged_by_partial_labels(self):
        original=copy.deepcopy(self.report)
        for change in ('passed','source','subset','partial','sequence','inventory','restoration','decode','screenshot','recorder-active','profile-active','idle-missing'):
            self.report=copy.deepcopy(original)
            if change=='passed':self.report['passed']=False
            if change=='source':self.report['source']['graphiteCapture']=False
            if change=='subset':self.report['graphiteSubsetPassed']=False
            if change=='partial':self.report['reportSource']='capture-progress.json'
            if change=='sequence':self.report['events'][1]['sequence']=1
            if change=='inventory':self.report['events'].pop()
            if change=='restoration':self.report['finalSystemMotionReadbacks']['animator_duration_scale']='0.0'
            if change=='decode':self.event('record_stop')['wholeVideoDecode']['passed']=False
            if change=='screenshot':self.event('snapshot')['screenshotReadiness']['rasterFrameNumber']=-1
            if change=='recorder-active':self.event('snapshot')['snapshotCaptureState']['ownedRecorderActive']=True
            if change=='profile-active':self.event('snapshot')['snapshotCaptureState']['profileActive']=True
            if change=='idle-missing':self.event('snapshot').pop('snapshotCaptureState')
            with self.assertRaises(ValueError):ui.validate_graphite_report(self.report)

    def test_exact_five_clip_selection_and_contacts_reject_paths_before_subprocess(self):
        for request in (self.request|{'interactionRecordingNames':[]},self.request|{'interactionRecordingNames':['01-root-navigation']},
                        self.request|{'interactionRecordingNames':list(reversed(ui.GRAPHITE_RECORDINGS))},
                        self.request|{'interactionContactNames':['../private']},self.request|{'interactionContactNames':['03-paper-sheet']},
                        self.request|{'graphiteCaptureDiagnostic':1}):
            with patch.object(ui.subprocess,'run') as run:
                with self.assertRaises(ValueError):ui.inspect_interaction_recordings(request,self.report)
                run.assert_not_called()
        for request in ({'graphiteCaptureDiagnostic':True},{'graphiteCaptureDiagnostic':'yes'}):
            with self.assertRaises(ValueError):ui.graphite_requested(request)

    def test_original_trace_hash_path_size_and_actions_are_required(self):
        event=self.event('graphite_trace',ui.GRAPHITE_RECORDINGS[1]);relative=event['evidenceFile'];path=self.root/relative
        original=path.read_bytes()
        path.write_bytes(original+b' ')
        with self.assertRaises(ValueError):self.inspect()
        path.write_bytes(original);event['evidenceFile']='../../private'
        with self.assertRaises(ValueError):self.inspect()
        event['evidenceFile']=relative;path.rename(self.root/'private');path.symlink_to(self.root/'private')
        with self.assertRaises(ValueError):self.inspect()
        path.unlink();(self.root/'private').rename(path)
        value=json.loads(original);value['actions'][0]['reducedMotion']=True;self.write_json(relative,event,value)
        with self.assertRaises(ValueError):self.inspect()
        value=json.loads(original);value['witnesses']['warmLaunchNotReplayed']=False;self.write_json(relative,event,value)
        with self.assertRaises(ValueError):self.inspect()

    def test_altered_summary_or_recorded_profile_cannot_be_reported_as_verified(self):
        event=self.event('perf_finish');relative=event['evidenceFile'];original=json.loads((self.root/relative).read_text())
        for change in ('summary','recorded','raw','budget'):
            value=copy.deepcopy(original)
            if change=='summary':value['raster']['p95Us']=1
            if change=='recorded':value['visibleScope']['screenRecordingActive']=True
            if change=='raw':value['rawFrames']=[]
            if change=='budget':value['frameBudgetUs']=1
            self.write_json(relative,event,value)
            with self.assertRaises(ValueError):self.inspect()

    def test_graphite_contact_and_original_png_bytes_share_the_existing_combined_cap(self):
        data=b'\x89PNG\r\n\x1a\n'+b'x'*100_000
        (self.root/'screenshots/01-home.png').write_bytes(data)
        request=self.request|{'screenshots':['01-home.png']}
        with tempfile.TemporaryDirectory() as cwd:
            folder=Path(cwd)/'cloud';folder.mkdir();(folder/'ui-capture-inspect.json').write_text(json.dumps(request))
            old=os.getcwd()
            try:
                os.chdir(cwd)
                with patch.object(ui,'load_capture_report',return_value=self.report),patch.object(ui,'inspect_graphite_evidence'),\
                     patch.object(ui,'inspect_native_profile_resources'),patch.object(ui,'inspect_ambient_recording'),\
                     patch.object(ui,'inspect_interaction_recordings',return_value=1_400_000),patch.object(ui,'emit_png') as emit,\
                     contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaisesRegex(ValueError,'Combined original graphite PNG/contact batch exceeds1.5MB'):ui.main()
                    emit.assert_not_called()
            finally:os.chdir(old)


class CaptureTransportInspectionTest(unittest.TestCase):
    def test_fixed_host_counters_emit_without_commands_or_unrelated_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report = {'stage': 'failure', 'evidenceOnly': True, 'qemuVerified': False,
                      'host': {'memory': {'MemAvailable': '128kB'}, 'cgroup': {'memory.events': 'oom_kill 1'},
                               'ownCgroup': {'memberships': [{'controller': 'v2', 'counters': {'memory.max': '1000000'}}]},
                               'kernelTermination': {'signals': [{'signals': ['segfault'], 'process': 'qemu-system-x86'}]},
                               'processes': [{'pid': 12, 'name': 'java', 'VmRSS': '2000kB', 'cmdline': 'NEVER_PRINT_COMMAND'}],
                               'unrelated': 'NEVER_PRINT_FIELD'}}
            (root / 'runtime-transport-failure.json').write_text(json.dumps(report))
            (root / 'unrelated.txt').write_text('NEVER_PRINT_FILE')
            out = io.StringIO()
            with patch.object(ui, 'ROOT', root), contextlib.redirect_stdout(out):
                ui.inspect_capture_transport_resources()
            value = out.getvalue()
            self.assertIn('oom_kill 1', value)
            self.assertIn('128kB', value)
            self.assertIn('1000000', value)
            self.assertIn('qemu-system-x86', value)
            self.assertIn('segfault', value)
            self.assertIn('UNACCEPTED_DIAGNOSTIC_ONLY', value)
            self.assertNotIn('NEVER_PRINT', value)

    def test_capture_transport_reader_rejects_symlinks_and_oversized_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / 'unrelated.json'
            target.write_text('{}')
            path = root / 'runtime-transport-before.json'
            path.symlink_to(target)
            with patch.object(ui, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, 'Unsafe or oversized'):
                    ui.inspect_capture_transport_resources()
                path.unlink()
                path.write_bytes(b' ' * 131_073)
                with self.assertRaisesRegex(ValueError, 'Unsafe or oversized'):
                    ui.inspect_capture_transport_resources()


if __name__ == '__main__':
    unittest.main()
