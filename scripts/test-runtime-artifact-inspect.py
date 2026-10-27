#!/usr/bin/env python3
import importlib.util
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


if __name__ == '__main__':
    unittest.main()
