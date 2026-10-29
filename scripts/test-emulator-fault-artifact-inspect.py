#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('fault_reader', Path(__file__).with_name('inspect-emulator-fault-artifact.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
REQUEST = {'mode': 'emulator-fault', 'runId': 40878922617, 'artifactId': 12901105053,
           'artifactName': 'drawmusic-emulator-fault-trace-' + 'd' * 40}


class FaultReaderTest(unittest.TestCase):
    def test_rejects_arbitrary_input_and_accepted_artifact_names(self):
        module.validate_request(REQUEST)
        for change in ({'path': '/etc/passwd'}, {'runId': True}, {'artifactId': 0}, {'mode': 'ui'},
                       {'artifactName': 'drawmusic-ui-visuals-' + 'd' * 40}):
            with self.assertRaises(ValueError):
                module.validate_request(REQUEST | change)

    def test_actual_fixed_metadata_does_not_dump_unknown_fields_or_console(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / module.PREFIX
            folder.mkdir(parents=True)
            (folder / 'lifecycle.json').write_text(json.dumps({'wrapperSignals': [], 'debuggerReturncode': 0,
                'stdout': {'eof': True, 'bytesDrained': 10, 'unknown': 'SECRET-STREAM'},
                'stderr': {'eof': True}, 'environment': 'SECRET-ENV'}))
            (folder / 'faults.json').write_text(json.dumps({'phase': 'finished', 'actualExitStatus': -1, 'arguments': 'SECRET-ARGV'}))
            (folder / 'stderr-tail.log').write_text('unable to read rendezvous\nSECRET-ENVIRONMENT\n')
            (root / 'arbitrary').write_text('SECRET-UNRELATED')
            emitted = []
            result = module.inspect(root, REQUEST, emitted.append)
            text = '\n'.join(emitted)
            self.assertNotIn('SECRET-', text)
            self.assertFalse(result['acceptanceEligible'])
            self.assertIn('"actualExitStatus": -1', text)
            console = next(file for file in result['files'] if file['file'].endswith('stderr-tail.log'))
            self.assertEqual(console['diagnosticTokenCounts']['rendezvous'], 1)
            lifecycle = next(file for file in result['files'] if file['file'].endswith('lifecycle.json'))
            self.assertEqual(lifecycle['wrapperSignals'], [])
            self.assertTrue(lifecycle['drains']['stdout']['eof'])
            self.assertTrue(result['missing'])

    def test_missing_files_are_not_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                module.inspect(Path(tmp), REQUEST)

    def test_symlink_or_oversized_console_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / module.PREFIX
            folder.mkdir(parents=True)
            target = root / 'private'
            target.write_text('SECRET')
            path = folder / 'stderr-tail.log'
            path.symlink_to(target)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST)
            path.unlink()
            with path.open('wb') as file:
                file.truncate(262145)
            with self.assertRaises(ValueError):
                module.inspect(root, REQUEST)


if __name__ == '__main__':
    unittest.main()
