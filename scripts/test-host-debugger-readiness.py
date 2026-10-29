#!/usr/bin/env python3
"""Readiness guards/protocol fakes only; no host tracing or emulator launch."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('host_debugger_readiness',Path(__file__).with_name('check-host-debugger-readiness.py'))
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)

class HostReadinessTests(unittest.TestCase):
    def test_safe_version_formats_stderr_loader_failure_and_statuses_remain_explicit(self):
        for text in ('lldb version 17.0.0 (revision owned)','lldb-server version 23.0.0git (revision owned)'):
            value=tool.version_summary({'returncode':0,'stdout':'','stderr':text})
            self.assertEqual(value['category'],'VersionParsed')
            self.assertIn(value['parsedVersion'],('17.0.0','23.0.0git'))
            self.assertEqual(value['returncode'],0)
        value=tool.version_summary({'returncode':127,'stderr':'lldb: error while loading shared libraries: libpython3.13.so.1.0: cannot open shared object file\nAPI_KEY=DO_NOT_PRINT'})
        self.assertEqual(value['category'],'MissingRuntimeSharedLibrary')
        self.assertEqual(value['missingLibrary'],'libpython3.13.so.1.0')
        self.assertEqual(value['returncode'],127)
        self.assertIsNone(value['parsedVersion'])
        self.assertNotIn('DO_NOT_PRINT',json.dumps(value))
        self.assertEqual(tool.version_summary({'returncode':None,'error':'TimeoutExpired'})['category'],'VersionCommandTimedOut')
        self.assertEqual(tool.version_summary({'returncode':0,'stdout':'Usage: lldb-server v[ersion]'})['category'],'VersionInvocationReturnedUsage')
        self.assertIsNone(tool.version_summary({'returncode':1,'stdout':'lldb version 17.0.0'})['parsedVersion'])

    def test_non_actions_never_executes_or_discovers_tools(self):
        with patch.dict(os.environ,{'GITHUB_ACTIONS':'false','RUNNER_OS':'Linux'}),patch.object(tool,'candidates') as candidates,patch.object(tool,'run_bounded') as run:
            result=tool.readiness()
        self.assertFalse(result['ready']);self.assertFalse(result['acceptanceEligible'])
        candidates.assert_not_called();run.assert_not_called()

    def test_discovery_rejects_workspace_and_untrusted_binaries(self):
        self.assertFalse(tool.trusted(Path(__file__)))
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);binary=root/'systemSwift/usr/bin/lldb';binary.parent.mkdir(parents=True)
            binary.write_bytes(b'\x7fELFownedfixture');binary.chmod(0o755)
            unrelated=root/'untrusted';unrelated.write_bytes(b'\x7fELFfixture');unrelated.chmod(0o755)
            with patch.object(tool,'TRUSTED',(root/'systemSwift',)),patch.object(tool,'FIXED',(binary,unrelated)),patch.object(tool.shutil,'which',return_value=None),patch.dict(os.environ,{'GITHUB_WORKSPACE':str(root/'checkout')}):
                self.assertEqual(tool.candidates(),[binary])
            with patch.object(tool,'TRUSTED',(root/'systemSwift',)),patch.dict(os.environ,{'GITHUB_WORKSPACE':str(root)}):
                self.assertFalse(tool.trusted(binary))

    def test_probe_keeps_restore_values_private_and_requires_aslr_and_actual_handled_behavior(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);real=root/'owned-readiness-elf';real.write_bytes(b'owned fake binary')
            outputs=root/'reports';binary=root/'lldb'
            def run(arguments,**options):
                payload=json.loads(os.read(options['pass_fds'][0],4096))
                self.assertIn('--no-lldbinit',arguments)
                self.assertEqual(set(payload['restoreDebuggerEnvironment']),{'PYTHONHOME','LD_LIBRARY_PATH','LLDB_DEBUGSERVER_PATH'})
                self.assertNotIn('SECRET_UNRELATED_VARIABLE',json.dumps(payload))
                mode=payload['arguments'][0]
                witness=Path(options['environment']['DOODIMO_FAKE_WITNESS'])
                witness.write_text(json.dumps({'argv0':str(real),'aslrEnabled':True,'sentinelMatches':True}))
                Path(payload['output']).write_text(json.dumps({'diagnosticOnly':True,'acceptanceEligible':False,'phase':'finished',
                    'actualExitStatus':0,'actualExitDescription':'','sigsegvStopsObserved':5,
                    'faults':[{'frames':[{'module':'owned-fake'}]}]*4}))
                return {'returncode':0,'stdout':''}
            with patch.object(tool,'OUTPUT',outputs),patch.object(tool,'run_bounded',side_effect=run),patch.dict(os.environ,{'SECRET_UNRELATED_VARIABLE':'DO_NOT_SERIALIZE'}):
                result=tool.own_probe(binary,'handled',root)
            self.assertTrue(result['ready']);self.assertTrue(result['argv0MatchesRetainedElf'])
            self.assertFalse(result['argv0MatchesOriginal']);self.assertNotIn('DO_NOT_SERIALIZE',json.dumps(result))

    def test_one_selected_host_trace_failure_does_not_expand_to_a_debugger_matrix(self):
        with tempfile.TemporaryDirectory() as tmp:
            binary=Path(tmp)/'lldb';server=binary.with_name('lldb-server')
            binary.write_bytes(b'fake-debugger');server.write_bytes(b'fake-server')
            calls=[]
            def run(arguments,**options):
                calls.append(arguments)
                if '--version' in arguments:return {'returncode':0,'stdout':'lldb version 17.0.0'}
                if arguments[-1]=='version':return {'returncode':0,'stdout':'','stderr':'lldb version 17.0.0'}
                if 'script import lldb;' in ' '.join(arguments):return {'returncode':0,'stdout':'DOODIMO_HOST_API_READY True True'}
                return {'returncode':0,'stdout':''}
            with patch.dict(os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'Linux'}),patch.object(tool,'candidates',return_value=[binary,Path(tmp)/'other']),patch.object(tool,'trusted',return_value=True),patch.object(tool,'regular_executable',return_value=True),patch.object(tool,'run_bounded',side_effect=run),patch.object(tool,'own_probe',return_value={'ready':False,'reason':'OwnedLaunchDenied'}) as probe:
                result=tool.readiness()
            self.assertFalse(result['ready']);self.assertEqual(probe.call_count,1)
            self.assertEqual(len(result['attempts']),1)
            self.assertEqual(result['attempts'][0]['versionChecks']['server']['parsedVersion'],'17.0.0')
            self.assertEqual(result['attempts'][0]['versionChecks']['server']['returncode'],0)
            self.assertFalse(any('sudo' in arguments or 'apt' in arguments for arguments in calls))

    def test_report_size_and_symlink_guards(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            with self.assertRaises(ValueError):tool.write_report(root/'report.json',{'text':'x'*32768})
            (root/'link.json').symlink_to(root/'target')
            with self.assertRaises(ValueError):tool.write_report(root/'link.json',{'ready':False})
            tool.write_report(root/'report.json',{'ready':False,'diagnosticOnly':True})
            self.assertFalse(json.loads((root/'report.json').read_text())['ready'])

    def test_missing_sdk_or_absent_python_is_unavailable_not_a_false_ready(self):
        with patch.dict(os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'Linux'}),patch.object(tool,'candidates',return_value=[]),patch.object(tool,'run_bounded') as run:
            value=tool.readiness()
        self.assertEqual(value['reason'],'NoVerifiedPreinstalledMatchingHostDebugger')
        self.assertFalse(value['ready']);run.assert_not_called()

if __name__=='__main__':unittest.main()
