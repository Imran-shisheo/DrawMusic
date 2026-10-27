#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('runtime_inspect', Path(__file__).with_name('inspect-runtime-artifact.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
REQUEST = {'mode': 'runtime', 'runId': 40525650391, 'artifactId': 12748102114, 'artifactName': 'drawmusic-runtime-evidence-' + 'a' * 40}


class RuntimeInspectionTest(unittest.TestCase):
    def test_exact_attempt_request_rejects_arbitrary_paths_and_ui_name(self):
        module.validate_request(REQUEST)
        for change in ({'artifactId': True}, {'artifactName': 'drawmusic-ui-visuals-' + 'a' * 40}, {'path': '/etc/passwd'}, {'runId': -1}):
            with self.assertRaises(ValueError):
                module.validate_request(REQUEST | change)

    def test_real_files_emit_android_signals_host_and_actual_native_cases_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            log = root / 'work/runtime-output/android.log'
            log.parent.mkdir(parents=True)
            log.write_text('native start\nFATAL EXCEPTION: main\nService connection disposed\n')
            (log.parent / 'hd-background-host.json').write_text(json.dumps({'passed': False}))
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


if __name__ == '__main__':
    unittest.main()
