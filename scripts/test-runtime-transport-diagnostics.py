#!/usr/bin/env python3
"""Host fakes prove diagnostics preserve failures; never native runtime proof."""
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import runtime_transport_diagnostics as diagnostics
spec = importlib.util.spec_from_file_location('ui_driver', Path(__file__).with_name('run-android-ui.py'))
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)


class TransportDiagnosticsTest(unittest.TestCase):
    def test_timeout_and_missing_adb_are_bounded_safe_statuses(self):
        with patch.object(diagnostics.subprocess, 'run', side_effect=subprocess.TimeoutExpired(['secret-command'], 3)):
            self.assertEqual(diagnostics.command(['adb', 'devices']), {'error': 'timeout after3s'})
        with patch.object(diagnostics.subprocess, 'run', side_effect=FileNotFoundError('secret-path')):
            self.assertEqual(diagnostics.command(['adb', 'devices']), {'error': 'FileNotFoundError'})

    def test_strict_actions_and_stage_namespace(self):
        with patch.dict(os.environ, {'GITHUB_ACTIONS': 'false'}), patch.object(diagnostics, 'command') as command:
            with self.assertRaises(RuntimeError): diagnostics.snapshot('before')
            command.assert_not_called()
        with patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), patch.object(diagnostics, 'command') as command:
            with self.assertRaises(ValueError): diagnostics.snapshot('../arbitrary')
            command.assert_not_called()

    def test_unknown_qemu_or_disconnected_adb_never_reads_package_or_logcat(self):
        for identity in ({'returncode': 0, 'stdout': '0'}, {'error': 'timeout after3s'}):
            with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), patch.object(diagnostics, 'host_resources', return_value={'memory': 'fixture'}), patch.object(diagnostics, 'command', side_effect=[{'returncode': 0}, {'returncode': 0}, identity]) as command:
                result = diagnostics.snapshot('failure', output=Path(tmp))
                self.assertIn('deviceReadsSkipped', result)
                self.assertEqual(command.call_count, 3)
                self.assertFalse(any('pidof' in call.args[0] or 'logcat' in call.args[0] for call in command.call_args_list))
                self.assertFalse(any('meminfo' in call.args[0] or '/proc/meminfo' in call.args[0] for call in command.call_args_list))
                self.assertEqual(json.loads((Path(tmp)/'runtime-transport-failure.json').read_text())['device'], 'emulator-5554')

    def test_verified_qemu_uses_only_fixed_package_and_bounded_tagged_log(self):
        def fake(args):
            return {'returncode': 0, 'stdout': '1' if 'ro.kernel.qemu' in args else ''}
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), patch.object(diagnostics, 'host_resources', return_value={}), patch.object(diagnostics, 'command', side_effect=fake) as command:
            diagnostics.snapshot('before', output=Path(tmp))
            calls = [c.args[0] for c in command.call_args_list]
            self.assertIn(['adb','-s','emulator-5554','shell','pidof','com.imranshisheo.scribblesong'], calls)
            self.assertIn(['adb','-s','emulator-5554','shell','cat','/proc/meminfo'], calls)
            self.assertIn(['adb','-s','emulator-5554','shell','dumpsys','meminfo','com.imranshisheo.scribblesong'], calls)
            log = next(args for args in calls if 'logcat' in args)
            self.assertEqual(log[log.index('-t')+1], '200')
            self.assertEqual(log[-1], '*:S')
            self.assertFalse(any('kill' in arg or 'retry' in arg for args in calls for arg in args))

    def test_diagnostic_timeout_does_not_replace_original_flutter_failure(self):
        process = SimpleNamespace(returncode=1, poll=lambda: 1)
        def adb(*args, **kwargs):
            return SimpleNamespace(stdout='1' if 'ro.kernel.qemu' in args else '', returncode=0)
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), patch.object(ui, 'OUTPUT', Path(tmp)), patch.object(ui, 'adb', side_effect=adb), patch.object(ui.subprocess, 'Popen', return_value=process), patch.object(diagnostics, 'snapshot', side_effect=TimeoutError('diagnostic unavailable')):
            with self.assertRaisesRegex(RuntimeError, 'Product UI test failed with exit code 1'):
                ui.main()
            report = json.loads((Path(tmp)/'hd-background-host.json').read_text())
            self.assertFalse(report['passed'])
            self.assertEqual(report['error'], 'Product UI test failed with exit code 1.')

    def test_launch_failure_preserved_even_when_diagnostics_fail(self):
        def adb(*args, **kwargs):
            return SimpleNamespace(stdout='1' if 'ro.kernel.qemu' in args else '', returncode=0)
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), patch.object(ui, 'OUTPUT', Path(tmp)), patch.object(ui, 'adb', side_effect=adb), patch.object(ui.subprocess, 'Popen', side_effect=FileNotFoundError('Flutter missing')), patch.object(diagnostics, 'snapshot', side_effect=OSError('ADB missing')):
            with self.assertRaisesRegex(FileNotFoundError, 'Flutter missing'):
                ui.main()
            self.assertEqual(json.loads((Path(tmp)/'hd-background-host.json').read_text())['error'], 'Flutter missing')


if __name__ == '__main__':
    unittest.main()
