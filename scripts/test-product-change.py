#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

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
                git('reset', '--hard', previous)
            self.assertTrue(module.product_changed('pull_request', {'action': 'opened', 'before': previous}, path))
            self.assertTrue(module.product_changed('pull_request', {'action': 'synchronize', 'before': 'f' * 40}, path))
            self.assertTrue(module.product_changed('pull_request', {'action': 'synchronize'}, path))
            self.assertTrue(module.product_changed('push', event, path))

if __name__ == '__main__':
    unittest.main()
