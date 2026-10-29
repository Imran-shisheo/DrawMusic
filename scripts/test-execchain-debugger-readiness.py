#!/usr/bin/env python3
"""Host21 fixture gates only; all debugger/compiler calls mocked here."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('exec_chain_readiness',Path(__file__).with_name('check-execchain-debugger-readiness.py'))
tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)

class ExecChainReadinessTests(unittest.TestCase):
    def result(self,environment,host,fixture):
        with tempfile.TemporaryDirectory() as tmp,patch.object(tool,'OUTPUT',Path(tmp)),patch.dict(os.environ,environment),patch.object(tool.TRACE,'load_ready',return_value=host) as load,patch.object(tool,'run_fixture',return_value=fixture) as run,contextlib.redirect_stdout(io.StringIO()):
            tool.main();value=json.loads((Path(tmp)/'execchain-readiness.json').read_text())
        return value,load.call_count,run.call_count
    def test_outside_owned_actions_never_discovers_or_launches_tools(self):
        value,loads,runs=self.result({'GITHUB_ACTIONS':'false','RUNNER_OS':'Linux'},{},{})
        self.assertEqual(value['reason'],'DisposableLinuxActionsOnly')
        self.assertFalse(value['ready']);self.assertEqual((loads,runs),(0,0))
    def test_other_host_version_cannot_be_claimed_as_host21_proof(self):
        value,loads,runs=self.result({'GITHUB_ACTIONS':'true','RUNNER_OS':'Linux'},{'version':'17.0.0'},{'ready':True})
        self.assertEqual(value['reason'],'VerifiedHost21Required')
        self.assertFalse(value['ready']);self.assertEqual((loads,runs),(1,0))
    def test_host21_failure_stays_false_and_success_is_diagnostic_only(self):
        host={'version':'21.0.0','debuggerSha256':'a'*64,'serverSha256':'b'*64}
        for ready in (False,True):
            value,loads,runs=self.result({'GITHUB_ACTIONS':'true','RUNNER_OS':'Linux'},host,
                {'ready':ready,'mappingVerified':True,'lldbExecTrackingObserved':ready})
            self.assertEqual(value['ready'],ready)
            self.assertTrue(value['diagnosticOnly']);self.assertFalse(value['acceptanceEligible'])
            self.assertEqual((loads,runs),(1,1))

if __name__=='__main__':unittest.main()
