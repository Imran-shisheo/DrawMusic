#!/usr/bin/env python3
"""Real Git + mocked bounded Actions proof; not a native execution claim."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('native_proof', Path(__file__).with_name('native-source-proof.py'))
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)


def accepted_responses():
    run = {'id': proof.ACCEPTED_RUN, 'repository': {'full_name': proof.REPOSITORY},
           'head_sha': proof.ACCEPTED_SOURCE, 'path': proof.WORKFLOW,
           'status': 'completed', 'conclusion': 'success'}
    def passed_step(name):
        return {'name': name, 'status': 'completed', 'conclusion': 'success'}
    jobs = {'total_count': 2, 'jobs': [
        {'run_id': proof.ACCEPTED_RUN, 'name': 'Analyze, test and build Android', 'status': 'completed', 'conclusion': 'success',
         'steps': [passed_step(name) for name in proof.REQUIRED_ANDROID_STEPS]},
        {'run_id': proof.ACCEPTED_RUN, 'name': proof.SWIFT_JOB, 'status': 'completed', 'conclusion': 'success',
         'steps': [passed_step('Execute render-used scheduling and reset policy regressions')]},
    ]}
    return run, jobs


class ActionsAcceptanceProof(unittest.TestCase):
    def test_exact_success_requires_full_core_native_inspection_and_swift_steps(self):
        with patch.object(proof, 'read_actions_json', side_effect=accepted_responses()):
            self.assertTrue(proof.accepted_gate_verified('private-fixture-token'))
        for field, value in [('id', 1), ('head_sha', 'f' * 40), ('path', '.github/workflows/ui-visuals.yml'), ('status', 'in_progress'), ('conclusion', 'skipped'), ('repository', {'full_name': 'another/repository'})]:
            run, jobs = accepted_responses()
            run[field] = value
            with self.subTest(field=field), patch.object(proof, 'read_actions_json', side_effect=[run, jobs]):
                self.assertFalse(proof.accepted_gate_verified('private-fixture-token'))
        for name in proof.REQUIRED_ANDROID_STEPS:
            for outcome in ('skipped', 'failure', 'cancelled'):
                run, jobs = accepted_responses()
                next(step for step in jobs['jobs'][0]['steps'] if step['name'] == name)['conclusion'] = outcome
                with self.subTest(step=name, outcome=outcome), patch.object(proof, 'read_actions_json', side_effect=[run, jobs]):
                    self.assertFalse(proof.accepted_gate_verified('private-fixture-token'))
        for mutate in (
            lambda jobs: jobs['jobs'][0].update(run_id=1),
            lambda jobs: jobs['jobs'][1].update(conclusion='skipped'),
            lambda jobs: jobs['jobs'][1]['steps'][0].update(conclusion='failure'),
            lambda jobs: jobs.update(total_count=101),
            lambda jobs: jobs['jobs'].append(copy.deepcopy(jobs['jobs'][0])),
        ):
            run, jobs = accepted_responses()
            mutate(jobs)
            with patch.object(proof, 'read_actions_json', side_effect=[run, jobs]):
                self.assertFalse(proof.accepted_gate_verified('private-fixture-token'))

    def test_api_timeout_malformed_auth_and_wrong_suffix_fail_closed(self):
        for error in (OSError('network'), ValueError('malformed'), TimeoutError('timeout')):
            with patch.object(proof, 'read_actions_json', side_effect=error):
                self.assertFalse(proof.accepted_gate_verified('private-fixture-token'))
        with patch.object(proof, 'read_actions_json') as request:
            self.assertFalse(proof.accepted_gate_verified(''))
            request.assert_not_called()
        with self.assertRaises(ValueError):
            proof.read_actions_json('https://arbitrary.invalid/', 'private-fixture-token')


class RealGitNativeInputs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.write(proof.WORKFLOW, 'reviewed workflow bytes\n')
        self.write('lib/app.dart', 'accepted product')
        self.anchor = self.commit()
        self.expected_hash = hashlib.sha256((self.root / proof.WORKFLOW).read_bytes()).hexdigest()
        self.anchor_patch = patch.object(proof, 'ACCEPTED_SOURCE', self.anchor)
        self.anchor_patch.start()
        self.addCleanup(self.anchor_patch.stop)

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, stderr=subprocess.DEVNULL, text=True).strip()

    def write(self, name, text):
        file = self.root / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-m', 'fixture')
        return self.git('rev-parse', 'HEAD')

    def evaluate(self, **kwargs):
        return proof.evaluate(proof.REPOSITORY, 'private-fixture-token', self.root, expected_workflow_sha256=self.expected_hash, **kwargs)

    def test_only_literal_docs_and_capture_exclusions_reuse_verified_anchor(self):
        for name in ('docs/status.md', 'README.md', 'integration_test/ui_visual_capture_test.dart',
                     'cloud/ui-capture-request.json', 'scripts/capture-android-ui.py',
                     'integration_test/support/ui_static_backdrop_probe.dart',
                     'test/ui_static_backdrop_probe_test.dart',
                     'scripts/prepare-ui-capture-source.py', '.github/workflows/ui-visuals.yml',
                     'scripts/native-source-proof.py', '.github/workflows/ui-capture-inspect.yml'):
            self.write(name, 'capture/docs-only change')
        self.commit()
        with patch.object(proof, 'read_actions_json', side_effect=accepted_responses()):
            result = self.evaluate()
        self.assertFalse(result['native_required'])
        self.assertEqual(result['native_reused_source'], self.anchor)
        self.assertEqual(result['native_reused_run'], str(proof.ACCEPTED_RUN))
        self.assertNotIn('private-fixture-token', json.dumps(result))
        with patch.object(proof, 'read_actions_json', side_effect=OSError('unavailable')):
            self.assertTrue(self.evaluate()['native_required'])

    def test_protected_product_functional_setup_dependencies_and_unknown_always_run(self):
        for name in ('lib/app.dart', 'android/native.kt', 'ios/native.swift', 'assets/icon.png',
                     'pubspec.yaml', 'pubspec.lock', '.fvmrc', 'cloud/toolchain.env',
                     'test/localization_test.dart', 'integration_test/creation_loop_test.dart',
                     'integration_test/support/unlisted_capture_probe.dart',
                     'scripts/check-android.sh', 'scripts/check-android-runtime.sh',
                     'scripts/prepare-runtime-inspectors.sh', 'unknown.txt', ' README.md'):
            with self.subTest(path=name):
                self.git('reset', '--hard', self.anchor)
                self.write(name, 'protected change')
                self.commit()
                with patch.object(proof, 'accepted_gate_verified', return_value=True) as api:
                    self.assertTrue(self.evaluate()['native_required'])
                    api.assert_not_called()

    def test_workflow_review_hash_and_working_tree_edits_cannot_be_bypassed(self):
        self.write(proof.WORKFLOW, 'unreviewed workflow mutation')
        self.commit()
        with patch.object(proof, 'accepted_gate_verified', return_value=True) as api:
            self.assertEqual(self.evaluate()['reason'], 'workflow-hash-mismatch')
            api.assert_not_called()
        self.git('reset', '--hard', self.anchor)
        self.write('lib/app.dart', 'dirty uncommitted protected source')
        with patch.object(proof, 'accepted_gate_verified', return_value=True):
            self.assertTrue(self.evaluate()['native_required'])
        self.git('reset', '--hard', self.anchor)
        with patch.object(proof, 'REVIEWED_ANDROID_WORKFLOW_SHA256', None):
            self.assertTrue(proof.evaluate(proof.REPOSITORY, 'private-fixture-token', self.root)['native_required'])
        with patch.dict(os.environ, {'REVIEWED_ANDROID_WORKFLOW_SHA256': self.expected_hash}):
            self.assertTrue(proof.evaluate(proof.REPOSITORY, 'private-fixture-token', self.root)['native_required'])

    def test_missing_history_wrong_repository_and_auth_never_reuse(self):
        with patch.object(proof, 'ACCEPTED_SOURCE', 'f' * 40), patch.object(proof, 'accepted_gate_verified', return_value=True):
            self.assertTrue(self.evaluate()['native_required'])
        with patch.object(proof, 'accepted_gate_verified', return_value=True) as api:
            self.assertTrue(proof.evaluate('another/repository', 'private-fixture-token', self.root)['native_required'])
            self.assertTrue(proof.evaluate(proof.REPOSITORY, '', self.root)['native_required'])
            api.assert_not_called()
        # Exact source object present on another branch is not ancestry proof.
        self.git('checkout', '--orphan', 'unrelated')
        self.git('rm', '-rf', '.')
        self.write(proof.WORKFLOW, 'reviewed workflow bytes\n')
        self.commit()
        with patch.object(proof, 'accepted_gate_verified', return_value=True):
            self.assertTrue(self.evaluate()['native_required'])


if __name__ == '__main__':
    unittest.main()
