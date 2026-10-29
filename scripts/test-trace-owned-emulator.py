#!/usr/bin/env python3
"""Authored fake SDK/debugger only; no actual emulator launch or host policy changes."""
import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import signal
from types import SimpleNamespace
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock,patch

SCRIPTS=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('owned_emulator_trace',SCRIPTS/'trace-owned-emulator.py')
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)

@unittest.skipUnless(shutil.which('cc'),'Authored ELF fixture requires the standard C compiler')
class OwnedTraceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build=tempfile.TemporaryDirectory();root=Path(cls.build.name)
        source=root/'fake.c';source.write_text('#include <stdio.h>\nint main(){puts("authored fake SDK");return 0;}\n')
        cls.elf=root/'fake-sdk';subprocess.run(['cc','-o',str(cls.elf),str(source)],check=True,capture_output=True)
    @classmethod
    def tearDownClass(cls):cls.build.cleanup()

    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);prior=Path.cwd();os.chdir(self.root);self.addCleanup(os.chdir,prior)
        self.sdk=self.root/'sdk';self.original=self.sdk/'emulator/emulator';self.original.parent.mkdir(parents=True)
        shutil.copy2(self.elf,self.original)
        self.env=patch.dict(os.environ,{'GITHUB_ACTIONS':'true','RUNNER_OS':'Linux',
            'DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC':'1','ANDROID_HOME':str(self.sdk)})
        self.env.start();self.addCleanup(self.env.stop)
        self.sha=patch.object(tool,'EXPECTED_SDK_SHA',tool.READY.sha(self.original));self.sha.start();self.addCleanup(self.sha.stop)
        self.fake=self.root/'owned-fake-debugger'
        self.fake.write_text('''#!/usr/bin/env python3
import json,os,re,sys
text=' '.join(sys.argv[1:]);fd=int(re.search(r'observe\\((\\d+)\\)',text).group(1))
with os.fdopen(fd) as stream:config=json.loads(stream.read(4096))
with open(config['output'],'w') as stream:json.dump({'schema':1,'diagnosticOnly':True,'acceptanceEligible':False,'phase':'finished','actualExitStatus':11,'faults':[]},stream)
for i in range(100):
 os.write(1,b'A'*4096);os.write(2,b'B'*4096)
''');self.fake.chmod(0o755)
        self.ready={'binary':str(self.fake),'server':str(self.root/'fake-server'),'version':'17.0.0',
            'debuggerSha256':'a'*64,'serverSha256':'b'*64,'readinessReportSha256':'c'*64}
        self.out=self.root/tool.OUTPUT

    def installed(self):
        with patch.object(tool,'load_ready',return_value=self.ready):tool.install()
        return self.original.with_name('emulator.doodimo-lldb-trace.json')

    def test_install_gates_and_baseline_sha_before_any_sdk_mutation(self):
        with patch.dict(os.environ,{'DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC':'0'}),patch.object(tool,'load_ready') as load:
            with self.assertRaises(RuntimeError):tool.install()
            load.assert_not_called()
        original=self.original.read_bytes()
        with patch.object(tool,'load_ready',return_value=self.ready),patch.object(tool,'EXPECTED_SDK_SHA','0'*64):
            with self.assertRaises(ValueError):tool.install()
        self.assertEqual(self.original.read_bytes(),original)
        config=self.installed()
        self.assertTrue(config.is_file())
        self.assertEqual(tool.READY.sha(self.original.with_name('emulator.doodimo-lldb-original')),tool.EXPECTED_SDK_SHA)
        with patch.object(tool,'load_ready',return_value=self.ready):
            with self.assertRaises((ValueError,RuntimeError)):tool.install()

    def test_version_help_exec_is_transparent_and_tampered_sdk_never_executes(self):
        config=self.installed()
        for arguments in (['--version'],['-help'],['-list-avds']):
            with patch.object(tool.os,'execve',side_effect=SystemExit) as execute:
                with self.assertRaises(SystemExit):tool.launch(config,arguments)
                self.assertEqual(execute.call_args.args[1],[str(self.original),*arguments])
                self.assertEqual(dict(execute.call_args.args[2]),dict(os.environ))
        real=self.original.with_name('emulator.doodimo-lldb-original');real.write_bytes(real.read_bytes()+b'changed')
        with patch.object(tool.os,'execve') as execute:
            with self.assertRaises(ValueError):tool.launch(config,['--version'])
            execute.assert_not_called()

    def test_fake_debugger_streams_drain_beyond_caps_and_statuses_are_separate(self):
        config=self.installed()
        with patch.object(tool,'load_ready',return_value=self.ready),patch.object(tool.READY,'debugger_environment',side_effect=lambda binary,env:dict(env)):
            self.assertEqual(tool.launch(config,['-avd','owned-fake']),0)
        value=json.loads((self.out/'lifecycle.json').read_text())
        self.assertEqual(value['debuggerReturncode'],0)
        self.assertTrue(value['diagnosticOnly']);self.assertFalse(value['acceptanceEligible'])
        self.assertIn('raw inferior LLDB status',value['statusScope'])
        self.assertEqual(json.loads((self.out/'faults.json').read_text())['actualExitStatus'],11)
        for name in ('stdout','stderr'):
            self.assertGreater(value[name]['bytesDrained'],tool.HEAD+tool.TAIL)
            self.assertTrue(value[name]['eof']);self.assertTrue(value[name]['truncated'])
            self.assertLessEqual((self.out/(name+'-head.log')).stat().st_size,tool.HEAD)
            self.assertLessEqual((self.out/(name+'-tail.log')).stat().st_size,tool.TAIL)
        tool.collect();self.assertTrue(json.loads((self.out/'collection.json').read_text())['debuggerFinished'])
        with patch.object(tool,'load_ready',return_value=self.ready):
            with self.assertRaises(RuntimeError):tool.launch(config,['-avd','second-launch-rejected'])

    def test_ready_report_requires_actual_trusted_identities_and_both_probes(self):
        binary=self.root/'host/lldb';binary.parent.mkdir();shutil.copy2(self.elf,binary)
        server=binary.with_name('lldb-server');shutil.copy2(self.elf,server)
        report=self.root/tool.READY_REPORT;report.parent.mkdir(parents=True)
        attempt={'debugger':str(binary),'server':str(server),'matchingVersion':'21.0.0',
            'debuggerSha256':tool.READY.sha(binary),'serverSha256':tool.READY.sha(server),
            'versionChecks':{role:{'returncode':0,'parsedVersion':'21.0.0'} for role in ('debugger','server')},
            'handled':{'ready':True,'stops':5,'actualExitStatus':0,'aslrEnabled':True,'sentinelMatches':True},
            'fatal':{'ready':True,'stops':1,'actualExitStatus':11,'aslrEnabled':True,'sentinelMatches':True}}
        value={'schema':1,'ready':True,'diagnosticOnly':True,'acceptanceEligible':False,'selectedDebugger':str(binary),'attempts':[attempt]}
        report.write_text(json.dumps(value))
        with patch.object(tool.READY,'trusted',return_value=True):
            self.assertEqual(tool.load_ready()['version'],'21.0.0')
            attempt['handled']['aslrEnabled']=False;report.write_text(json.dumps(value))
            with self.assertRaises(ValueError):tool.load_ready()
            attempt['handled']['aslrEnabled']=True;report.write_text(json.dumps(value))
            server.write_bytes(server.read_bytes()+b'tampered')
            with self.assertRaises(ValueError):tool.load_ready()

    def test_signal_forwarding_checks_only_owned_debugger_identity(self):
        process=SimpleNamespace(pid=123,poll=lambda:None,send_signal=Mock())
        with patch.object(tool,'identity',return_value='different'):
            self.assertFalse(tool.forward_owned(process,'original',signal.SIGTERM))
        process.send_signal.assert_not_called()
        with patch.object(tool,'identity',return_value='original'):
            self.assertTrue(tool.forward_owned(process,'original',signal.SIGTERM))
        process.send_signal.assert_called_once_with(signal.SIGTERM)

    def test_collector_emits_only_owned_mapping_allowlist(self):
        self.out.mkdir(parents=True)
        tool.json_write(self.out/'lifecycle.json',{'phase':'finished'})
        tool.json_write(self.out/'faults.json',{'phase':'finished','faults':[{
            'signal':11,'ownedPidMatches':True,'frames':[],
            'targets':{'process':{'executableBasename':'owned-worker','moduleCount':5,'private':'SECRET-TARGET'}},
            'ownedPcMapping':{'status':'MappedPath','mappingBasename':'libowned.so','pcFileOffset':4361,
                'rawMaps':'SECRET-MAPS','backingFile':{'status':'VerifiedBackingElf','sha256':'a'*64,'private':'SECRET-FILE'}}}]})
        captured=io.StringIO()
        with contextlib.redirect_stdout(captured):tool.collect()
        text=captured.getvalue()
        self.assertNotIn('SECRET-',text)
        marker=json.loads(text.split('SDK_FAULT_STACK_DIAGNOSTIC ',1)[1])
        self.assertFalse(marker['acceptanceEligible'])
        mapping=marker['faults'][0]['ownedPcMapping']
        self.assertEqual(mapping['mappingBasename'],'libowned.so')
        self.assertEqual(mapping['pcFileOffset'],4361)
        self.assertEqual(mapping['backingFile']['sha256'],'a'*64)

class LastFaultBoundTests(unittest.TestCase):
    def test_byte_bound_drops_oldest_stack_and_keeps_newest_signal(self):
        spec=importlib.util.spec_from_file_location('bounded_lldb_controller',SCRIPTS/'emulator_lldb_trace.py')
        controller=importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules,{'lldb':SimpleNamespace()}):spec.loader.exec_module(controller)
        state={'sigsegvStopsObserved':5,'faults':[{'signalStopNumber':number,'frames':[
            {'frame':index,'function':'界'*80,'module':'界'*80} for index in range(24)]} for number in (2,3,4,5)]}
        data=controller.encode_bounded(state)
        self.assertLessEqual(len(data),32768)
        self.assertEqual(state['faults'][-1]['signalStopNumber'],5)
        self.assertGreater(state['faultStacksDroppedForByteBound'],0)
        self.assertEqual(json.loads(data)['faults'][-1]['signalStopNumber'],5)

if __name__=='__main__':unittest.main()
