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
    def test_source_pinning_transfers_diagnostic_helper_and_its_regression_tests(self):
        spec = importlib.util.spec_from_file_location('capture_prepare_diagnostics', Path(__file__).with_name('prepare-ui-capture-source.py'))
        prepare = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(prepare)
        for path in ('scripts/runtime_transport_diagnostics.py', 'scripts/test-runtime-transport-diagnostics.py'):
            self.assertEqual(prepare.FILES.count(path), 1)

    def test_nested_v2_reads_own_membership_counters_not_missing_cgroup_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); own = root/'job.slice'/'runner'; own.mkdir(parents=True)
            (own/'memory.events').write_text('oom 1\noom_kill 0\n')
            (own/'cpu.stat').write_text('usage_usec 123\n')
            original = diagnostics.read_fixed
            def read(path):
                return '0::/job.slice/runner\n' if str(path) == '/proc/self/cgroup' else original(path)
            with patch.object(diagnostics, 'CGROUP_ROOT', root), patch.object(diagnostics, 'read_fixed', side_effect=read):
                value = diagnostics.own_cgroup_resources()
            own = value['memberships'][0]
            self.assertEqual(own['controller'], 'v2')
            self.assertEqual(own['counters']['memory.events'], 'oom 1\noom_kill 0\n')
            self.assertEqual(own['counters']['cpu.stat'], 'usage_usec 123\n')
            self.assertEqual(own['counters']['memory.max'], {'unavailable':'FileNotFoundError'})

    def test_v1_memory_and_combined_cpu_memberships_have_fixed_counter_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ('memory', 'cpu,cpuacct'):
                (root/name/'job').mkdir(parents=True)
            (root/'memory/job/memory.oom_control').write_text('under_oom 0\noom_kill 2\n')
            (root/'cpu,cpuacct/job/cpu.stat').write_text('nr_throttled 3\n')
            (root/'cpu,cpuacct/job/cpuacct.usage').write_text('987\n')
            original = diagnostics.read_fixed
            def read(path):
                return '5:memory:/job\n4:cpu,cpuacct:/job\n3:devices:/job\n' if str(path) == '/proc/self/cgroup' else original(path)
            with patch.object(diagnostics, 'CGROUP_ROOT', root), patch.object(diagnostics, 'read_fixed', side_effect=read):
                groups = {item['controller']:item['counters'] for item in diagnostics.own_cgroup_resources()['memberships']}
            self.assertEqual(set(groups), {'memory','cpu','cpuacct'})
            self.assertEqual(groups['memory']['memory.oom_control'], 'under_oom 0\noom_kill 2\n')
            self.assertEqual(groups['cpu']['cpu.stat'], 'nr_throttled 3\n')
            self.assertEqual(groups['cpuacct']['cpuacct.usage'], '987\n')

    def test_cgroup_traversal_and_escaping_symlinks_never_read_other_files(self):
        with tempfile.TemporaryDirectory() as tmp, tempfile.TemporaryDirectory() as outside:
            root = Path(tmp); (root/'escape').symlink_to(outside)
            original = diagnostics.read_fixed
            for member in ('/../../other-job', '/escape'):
                reads = []
                def read(path):
                    reads.append(str(path))
                    return '0::'+member+'\n' if str(path) == '/proc/self/cgroup' else original(path)
                with patch.object(diagnostics, 'CGROUP_ROOT', root), patch.object(diagnostics, 'read_fixed', side_effect=read):
                    group = diagnostics.own_cgroup_resources()['memberships'][0]
                self.assertIn('unavailable', group)
                self.assertEqual(reads, ['/proc/self/cgroup'])
            (root/'own').mkdir(); (root/'own/memory.events').symlink_to(Path(outside)/'secret')
            def read(path):
                return '0::/own\n' if str(path) == '/proc/self/cgroup' else original(path)
            with patch.object(diagnostics, 'CGROUP_ROOT', root), patch.object(diagnostics, 'read_fixed', side_effect=read):
                counters = diagnostics.own_cgroup_resources()['memberships'][0]['counters']
            self.assertEqual(counters['memory.events'], {'unavailable':'CgroupPathOutsideExpectedFilesystem'})

    def test_kernel_permission_denial_falls_back_without_publishing_raw_commands_or_secrets(self):
        raw = 'Out of memory: Killed process 7171 (qemu-system-x86) SECRET_ENV=hidden /private/path\n'
        with patch.dict(os.environ, {'GITHUB_ACTIONS':'true'}), patch.object(diagnostics, 'command', side_effect=[{'returncode':1,'stderr':'permission denied SECRET'}, {'returncode':1,'stderr':'sudo denied SECRET'}, {'returncode':0,'stdout':raw}]) as command:
            value = diagnostics.kernel_termination_signals()
        self.assertEqual(value['attempts'][0]['unavailable'], 'ReadDeniedOrUnsupported')
        self.assertEqual(value['signals'], [{'signals':['oom','killed-process'], 'pid':7171, 'process':'qemu-system-x86'}])
        encoded = json.dumps(value)
        for hidden in ('SECRET', '/private/path', 'permission denied', 'hidden'):
            self.assertNotIn(hidden, encoded)
        self.assertEqual(command.call_args_list[0].args[0][0], 'dmesg')
        self.assertEqual(command.call_args_list[1].args[0], ['sudo','-n',*command.call_args_list[0].args[0]])
        self.assertEqual(command.call_args_list[2].args[0][0], 'journalctl')
        self.assertIn('--lines=200', command.call_args_list[2].args[0])
        with patch.object(diagnostics, 'command', return_value={'returncode':0,'stdout':'qemu-system-x86[7171]: segfault at SECRET_ADDRESS in libvulkan.so.1[PRIVATE_OFFSET] ENV=SECRET'}):
            value = diagnostics.kernel_termination_signals()
        self.assertEqual(value['signals'], [{'signals':['segfault'], 'pid':7171, 'process':'qemu-system-x86', 'moduleBasename':'libvulkan.so.1'}])
        self.assertNotIn('SECRET', json.dumps(value))
        self.assertNotIn('PRIVATE_OFFSET', json.dumps(value))

    def test_kernel_signal_output_is_bounded_and_unsupported_reads_explicit(self):
        with patch.object(diagnostics, 'command', return_value={'returncode':0,'stdout':('qemu-system-x86 segfault SECRET\n'*500)}):
            value = diagnostics.kernel_termination_signals()
        self.assertEqual(len(value['signals']), 40)
        self.assertLess(len(json.dumps(value).encode()), 8192)
        self.assertNotIn('SECRET', json.dumps(value))
        with patch.dict(os.environ, {'GITHUB_ACTIONS':'false'}), patch.object(diagnostics, 'command', side_effect=[{'error':'FileNotFoundError'}, {'error':'timeout after3s'}]) as command:
            value = diagnostics.kernel_termination_signals()
        self.assertEqual(value['unavailable'], 'NoSupportedReadableKernelSource')
        self.assertEqual([item['unavailable'] for item in value['attempts']], ['FileNotFoundError','timeout after3s'])
        self.assertFalse(any(call.args[0][0] == 'sudo' for call in command.call_args_list))

    def test_oversized_snapshot_is_not_written_and_safe_wrapper_preserves_failure(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'GITHUB_ACTIONS':'true'}), patch.object(diagnostics, 'host_resources', return_value={'oversize':'x'*(128*1024)}), patch.object(diagnostics, 'command', return_value={'returncode':1}):
            self.assertIsNone(diagnostics.safe_snapshot('failure', output=Path(tmp)))
            self.assertFalse((Path(tmp)/'runtime-transport-failure.json').exists())

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
