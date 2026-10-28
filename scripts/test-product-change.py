#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from io import BytesIO
import json

spec = importlib.util.spec_from_file_location('product_changes', Path(__file__).with_name('detect-product-change.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class RealGitChanges(unittest.TestCase):
    def test_documentation_is_skipped_but_source_tests_and_unknown_paths_are_not(self):
        with tempfile.TemporaryDirectory() as path:
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=path, stderr=subprocess.DEVNULL, text=True).strip()
            git('init'); git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.invalid')
            Path(path, 'app.dart').write_text('baseline')
            git('add', '.'); git('commit', '-m', 'baseline')
            previous = git('rev-parse', 'HEAD')
            event = {'action': 'synchronize', 'before': previous}
            for name, expected in [('docs/status.md', False), ('cloud/ui-capture-request.json', False), ('lib/app.dart', True), ('test/contract.dart', True), ('.github/workflows/android.yml', True), ('unknown.txt', True)]:
                target = Path(path, name); target.parent.mkdir(parents=True, exist_ok=True); target.write_text('changed')
                git('add', '.'); git('commit', '-m', name)
                self.assertEqual(module.product_changed('pull_request', event, path), expected, name)
                no_before = {'action': 'synchronize', 'pull_request': {'head': {'sha': git('rev-parse', 'HEAD')}}}
                resolved = module.comparison_event(no_before, path)
                self.assertEqual(resolved['before'], previous)
                self.assertEqual(module.product_changed('pull_request', resolved, path), expected, name)
                git('reset', '--hard', previous)
            self.assertTrue(module.product_changed('pull_request', {'action': 'opened', 'before': previous}, path))
            self.assertTrue(module.product_changed('pull_request', {'action': 'synchronize', 'before': 'f' * 40}, path))
            self.assertTrue(module.product_changed('pull_request', {'action': 'synchronize'}, path))
            self.assertTrue(module.product_changed('push', event, path))

class AcceptedGateProof(unittest.TestCase):
    before = 'a' * 40
    repo = 'Imran-shisheo/DrawMusic'

    def responses(self, values):
        return [BytesIO(json.dumps(value).encode()) for value in values]

    def test_success_requires_actual_android_and_swift_jobs(self):
        run = {'workflow_runs': [{'id': 5, 'head_sha': self.before, 'status': 'completed', 'conclusion': 'success'}]}
        for jobs, expected in [
            ([{'name': 'Analyze, test and build Android', 'conclusion': 'success'}, {'name': 'Pure Swift audio state (Linux; not iOS runtime)', 'conclusion': 'success'}], True),
            ([{'name': 'Validate setup and detect Flutter project', 'conclusion': 'success'}, {'name': 'Analyze, test and build Android', 'conclusion': 'skipped'}], False),
            ([{'name': 'Analyze, test and build Android', 'conclusion': 'cancelled'}], False),
        ]:
            with patch.object(module.urllib.request, 'urlopen', side_effect=self.responses([run, {'jobs': jobs}])):
                self.assertEqual(module.previous_gate_passed(self.before, self.repo, 'fixture-token'), expected)

    def test_running_missing_failed_lookup_and_wrong_repository_never_skip(self):
        with patch.object(module.urllib.request, 'urlopen', side_effect=self.responses([{'workflow_runs': []}])):
            self.assertFalse(module.previous_gate_passed(self.before, self.repo, 'fixture-token'))
        with patch.object(module.urllib.request, 'urlopen', side_effect=OSError('unavailable')):
            self.assertFalse(module.previous_gate_passed(self.before, self.repo, 'fixture-token'))
        with patch.object(module.urllib.request, 'urlopen') as request:
            self.assertFalse(module.previous_gate_passed(self.before, self.repo, ''))
            self.assertFalse(module.previous_gate_passed(self.before, 'another/repository', 'fixture-token'))
            request.assert_not_called()

if __name__ == '__main__':
    unittest.main()
