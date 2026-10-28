#!/usr/bin/env python3
import importlib.util
import contextlib
import io
import subprocess
import hashlib
import json
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


if __name__ == '__main__':
    unittest.main()
