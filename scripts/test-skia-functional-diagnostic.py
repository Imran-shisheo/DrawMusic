#!/usr/bin/env python3
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('skia_functional', Path(__file__).with_name('run-skia-functional-diagnostic.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
PROVENANCE = {'productSourceSha': module.PRODUCT, 'diagnosticOnly': 'skia-functional',
              'acceptanceEligible': False, 'rendererOverride': 'skia-diagnostic-only'}


class SkiaFunctionalTest(unittest.TestCase):
    def test_runtime_flag_preserves_every_original_argument(self):
        with patch.object(module.subprocess, 'Popen', return_value='owned') as original:
            self.assertEqual(module.DiagnosticSubprocess().Popen(module.ORIGINAL_COMMAND, stdout=12), 'owned')
            original.assert_called_once_with([*module.ORIGINAL_COMMAND, '--no-enable-impeller'], stdout=12)
        with self.assertRaises(ValueError):
            module.DiagnosticSubprocess().Popen(['flutter', 'test', 'other.dart'])
        self.assertIs(module.DiagnosticSubprocess().run, module.subprocess.run)

    def test_provenance_cannot_be_normal_or_different_source(self):
        with patch.dict(os.environ, {'GITHUB_ACTIONS': 'true', 'DRAWMUSIC_SKIA_FUNCTIONAL_DIAGNOSTIC': '1'}):
            with patch.object(module.DRIVER.__class__, 'read_bytes', return_value=b'changed'):
                with self.assertRaises(ValueError):
                    module.validate(PROVENANCE)
            for edit in ({'acceptanceEligible': True}, {'rendererOverride': None}, {'productSourceSha': '0'*40}):
                with self.assertRaises(ValueError):
                    module.validate(PROVENANCE | edit)
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RuntimeError):
                module.validate(PROVENANCE)


if __name__ == '__main__':
    unittest.main()
