#!/usr/bin/env python3
"""Authored child-process fakes; never real SDK/QEMU or physical runtime proof."""
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).with_name('observe-emulator-process.py').resolve()
spec = importlib.util.spec_from_file_location('emulator_observer', SCRIPT)
observer = importlib.util.module_from_spec(spec); spec.loader.exec_module(observer)

FAKE = r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
int main(int argc, char **argv) {
  const char *mode = getenv("OBSERVER_FAKE_MODE");
  if (mode && !strcmp(mode, "stream")) {
    char block[4096]; memset(block, 'X', sizeof(block));
    for (int i=0;i<180;i++) { if (write(1,block,sizeof(block))<0) return 30; if(write(2,block,sizeof(block))<0) return 31; }
  } else if (mode && !strcmp(mode, "signal")) { raise(SIGTERM); }
  else if (mode && !strcmp(mode, "wait")) { while(1) pause(); }
  else if (mode && !strcmp(mode, "exec")) { execl("/bin/sleep","authored-fake-qemu","0.7",NULL); return 32; }
  else if (mode && !strcmp(mode, "args")) {
    FILE *f=fopen(getenv("OBSERVER_FAKE_WITNESS"),"w");
    for(int i=0;i<argc;i++) fprintf(f,"%s\n",argv[i]);
    fprintf(f,"%s\n",getenv("OBSERVER_FAKE_SENTINEL")); fclose(f);
  }
  fprintf(stdout,"owned fake stdout\n"); fprintf(stderr,"owned fake stderr\n");
  return mode && !strcmp(mode,"nonzero") ? 7 : 0;
}
'''


@unittest.skipUnless(shutil.which('cc'), 'Authored ELF fixture requires the standard Linux C compiler')
class EmulatorObserverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory()
        root = Path(cls.build.name); (root/'fake.c').write_text(FAKE)
        cls.binary = root/'fake-emulator'
        subprocess.run(['cc', '-o', str(cls.binary), str(root/'fake.c')], check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls): cls.build.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.sdk = self.root/'sdk'
        self.launcher = self.sdk/'emulator/emulator'; self.launcher.parent.mkdir(parents=True)
        shutil.copy2(self.binary, self.launcher)
        self.environment = {**os.environ, 'GITHUB_ACTIONS':'true', 'RUNNER_OS':'Linux', 'ANDROID_HOME':str(self.sdk)}
        self.out = self.root/'work/ui-capture/emulator-process'

    def install(self):
        result = subprocess.run([sys.executable,str(SCRIPT),'install','--mode','ui'], cwd=self.root, env=self.environment, capture_output=True, timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)

    def run_child(self, mode='normal', args=None):
        self.install()
        return subprocess.run([str(self.launcher), *(args or ['-avd','owned-fake'])], cwd=self.root,
            env={**self.environment, 'OBSERVER_FAKE_MODE':mode}, capture_output=True, timeout=8)

    def manifest(self): return json.loads((self.out/'lifecycle.json').read_text())

    def test_normal_and_nonzero_exit_status_and_logs_are_actual_child_results(self):
        for mode,code in (('normal',0),('nonzero',7)):
            with self.subTest(mode=mode):
                if (self.out/'lifecycle.json').exists():
                    (self.out/'lifecycle.json').unlink()
                    result = subprocess.run([str(self.launcher),'-avd','owned-fake'], cwd=self.root,
                        env={**self.environment,'OBSERVER_FAKE_MODE':mode}, capture_output=True, timeout=8)
                else: result = self.run_child(mode)
                self.assertEqual(result.returncode,code,result.stderr)
                state=self.manifest(); self.assertEqual(state['childReturncode'],code)
                self.assertEqual(state['state'],'exited'); self.assertTrue(state['drainsComplete'])
                self.assertEqual((self.out/'stdout-tail.log').read_bytes(),b'owned fake stdout\n')
                self.assertEqual((self.out/'stderr-tail.log').read_bytes(),b'owned fake stderr\n')
                self.assertEqual(state['binarySha256'], observer.digest(self.binary))

    def test_child_signal_status_is_not_invented_from_wrapper_returncode(self):
        result=self.run_child('signal'); self.assertEqual(result.returncode,128+signal.SIGTERM)
        state=self.manifest(); self.assertEqual(state['childReturncode'],-signal.SIGTERM)
        self.assertEqual(state['childTerminationSignal'],signal.SIGTERM)

    def test_both_streams_are_drained_after_log_caps_without_sigpipe_or_unbounded_files(self):
        result=self.run_child('stream'); self.assertEqual(result.returncode,0,result.stderr)
        state=self.manifest()
        for name in ('stdout','stderr'):
            self.assertGreater(state[name]['bytesDrained'],observer.HEAD_BYTES+observer.TAIL_BYTES)
            self.assertTrue(state[name]['eof']); self.assertTrue(state[name]['truncated'])
            self.assertLessEqual((self.out/(name+'-head.log')).stat().st_size,observer.HEAD_BYTES)
            self.assertLessEqual((self.out/(name+'-tail.log')).stat().st_size,observer.TAIL_BYTES)

    def test_argv0_options_and_environment_preserved_without_manifest_dump(self):
        self.environment.update(OBSERVER_FAKE_WITNESS=str(self.root/'witness'),OBSERVER_FAKE_SENTINEL='private-env-sentinel')
        args=['-avd','owned-fake','-gpu','swiftshader_indirect','private-option-sentinel']
        result=self.run_child('args',args); self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual((self.root/'witness').read_text().splitlines(),[str(self.launcher),*args,'private-env-sentinel'])
        encoded=json.dumps(self.manifest())
        for value in ('private-env-sentinel','private-option-sentinel','OBSERVER_FAKE_SENTINEL'):
            self.assertNotIn(value,encoded)

    def test_non_avd_invocation_execs_transparently_without_launch_manifest(self):
        result=self.run_child(args=['-version'])
        self.assertEqual(result.returncode,0); self.assertEqual(result.stdout,b'owned fake stdout\n')
        self.assertFalse((self.out/'lifecycle.json').exists())

    def test_wrapper_signal_only_forwards_to_same_owned_process_start_identity(self):
        self.install()
        process=subprocess.Popen([str(self.launcher),'-avd','owned-fake'],cwd=self.root,
            env={**self.environment,'OBSERVER_FAKE_MODE':'wait'},stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            deadline=time.monotonic()+5
            while time.monotonic()<deadline:
                if (self.out/'lifecycle.json').exists() and self.manifest().get('state')=='running': break
                time.sleep(.02)
            process.send_signal(signal.SIGTERM); stdout,stderr=process.communicate(timeout=5)
            self.assertEqual(process.returncode,143,stderr)
            state=self.manifest(); self.assertEqual(state['childReturncode'],-signal.SIGTERM)
            self.assertTrue(state['wrapperSignals'][0]['forwardedToVerifiedChild'])
        finally:
            if process.poll() is None:
                process.kill();process.communicate(timeout=3)

    def test_same_pid_exec_is_observed_not_assumed(self):
        result=self.run_child('exec'); self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('sleep',self.manifest()['observedExecutableNames'])

    def test_gates_hash_identity_symlinks_and_duplicate_install_fail_closed(self):
        for env in ({**self.environment,'GITHUB_ACTIONS':'false'},{**self.environment,'RUNNER_OS':'macOS'}):
            result=subprocess.run([sys.executable,str(SCRIPT),'install','--mode','ui'],cwd=self.root,env=env,capture_output=True,timeout=5)
            self.assertNotEqual(result.returncode,0)
        self.install()
        duplicate=subprocess.run([sys.executable,str(SCRIPT),'install','--mode','ui'],cwd=self.root,env=self.environment,capture_output=True,timeout=5)
        self.assertNotEqual(duplicate.returncode,0)
        real=self.launcher.with_name('emulator.doodimo-original'); real.write_bytes(real.read_bytes()+b'changed')
        bad=subprocess.run([str(self.launcher),'-avd','owned-fake'],cwd=self.root,env=self.environment,capture_output=True,timeout=5)
        self.assertNotEqual(bad.returncode,0); self.assertFalse((self.out/'lifecycle.json').exists())

    def test_post_action_collection_wait_is_read_only_and_bounded(self):
        self.run_child()
        result=subprocess.run([sys.executable,str(SCRIPT),'collect','--mode','ui'],cwd=self.root,env=self.environment,capture_output=True,timeout=3)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue(json.loads((self.out/'collection.json').read_text())['observerFinished'])


class CrashDatabaseScopeTests(unittest.TestCase):
    def test_pinned_capture_harness_transfers_observer_and_tests_once(self):
        spec=importlib.util.spec_from_file_location('observer_capture_prepare',SCRIPT.with_name('prepare-ui-capture-source.py'))
        prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)
        for path in ('scripts/observe-emulator-process.py','scripts/test-observe-emulator-process.py'):
            self.assertEqual(prepare.FILES.count(path),1)

    def test_pid_reuse_or_missing_start_identity_cannot_signal_another_process(self):
        child=SimpleNamespace(pid=123,poll=lambda:None,send_signal=Mock())
        with patch.object(observer,'start_identity',return_value='new-process'):
            self.assertFalse(observer.forward_to_owned_child(child,'old-process',signal.SIGTERM))
            self.assertFalse(observer.forward_to_owned_child(child,None,signal.SIGTERM))
        child.send_signal.assert_not_called()
        with patch.object(observer,'start_identity',return_value='same-process'):
            self.assertTrue(observer.forward_to_owned_child(child,'same-process',signal.SIGTERM))
        child.send_signal.assert_called_once_with(signal.SIGTERM)

    def test_missing_observer_collection_times_out_without_repairs(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(observer,'output_path',return_value=Path(tmp)), patch.object(observer.time,'monotonic',side_effect=[0,0,11]), patch.object(observer.time,'sleep') as sleep:
            observer.collect('ui')
            value=json.loads((Path(tmp)/'collection.json').read_text())
        self.assertFalse(value['observerFinished'])
        self.assertEqual(value['observedState'],'no-observer-manifest')
        sleep.assert_called_once_with(.2)

    def test_only_sdk_versioned_exact_prefix_is_eligible(self):
        self.assertIsNotNone(observer.DB_PATTERN.fullmatch(b'/tmp/android-runner/emu-crash-37.2.12.db'))
        for value in (b'/tmp/unrelated/core.db',b'/tmp/android-runner/emu-crash-37.2.12.db/../other',b'/tmp/android-runner/emu-crash-37.2.12.db-secret'):
            self.assertIsNone(observer.DB_PATTERN.fullmatch(value))

    def test_owned_fake_database_files_bounds_and_symlinks_have_explicit_outcomes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); db=root/'emu-crash-37.2.12.db'; db.mkdir(); out=root/'output';out.mkdir()
            pattern=re.compile(re.escape(str(db)).encode())
            (db/'metadata').write_bytes(b'owned fake metadata')
            (db/'report.dmp').write_bytes(b'owned fake related report')
            (root/'unrelated').write_bytes(b'do not read');(db/'link').symlink_to(root/'unrelated')
            with patch.object(observer,'DB_PATTERN',pattern): result=observer.retain_crash_db([str(db)],out)
            self.assertEqual(len(result['files']),2)
            self.assertIn({'reason':'NotRegularDatabaseFile'},result['skipped'])
            self.assertFalse((out/'crash-db'/db.name/'link').exists())
            self.assertEqual((out/'crash-db'/db.name/'report.dmp').read_bytes(),b'owned fake related report')
            with patch.object(observer,'DB_PATTERN',pattern),patch.object(observer,'DB_BYTES',4):
                bounded=observer.retain_crash_db([str(db)],out)
            self.assertFalse(bounded['files']);self.assertTrue(any(item['reason']=='DatabaseByteBound' for item in bounded['skipped']))
            with patch.object(observer,'DB_PATTERN',pattern),patch.object(observer,'DB_FILES',1):
                counted=observer.retain_crash_db([str(db)],out)
            self.assertEqual(len(counted['files']),1)
            self.assertIn({'reason':'DatabaseFileCountBound'},counted['skipped'])


if __name__=='__main__': unittest.main()
