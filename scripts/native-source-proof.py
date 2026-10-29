#!/usr/bin/env python3
"""Reuse one accepted native result only for unchanged protected source inputs.

This never replaces current core/JVM/lint/build gates and never describes reuse
as a newly executed emulator test. Only this file's literal exclusions apply.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

REPOSITORY = 'Imran-shisheo/DrawMusic'
ACCEPTED_SOURCE = '6f80572a5432469ecbbb37059dc2a25bb2cc11e0'
ACCEPTED_RUN = 40662060004
REVIEWED_ANDROID_WORKFLOW_SHA256 = '0c1c99efe4d890fb4b05c7d6cd8ea0b24af99e62e037fc8e8b46298c82e1dd4d'
WORKFLOW = '.github/workflows/android.yml'
# Auditable exact capture/inspection-only exclusions. There is no scripts/**,
# test/** or workflow/** wildcard. Setup, functional tests and native validators
# remain protected even when they happen to mention screenshots/media.
CAPTURE_ONLY = frozenset({
    'README.md',
    'cloud/ui-capture-request.json',
    'cloud/ui-capture-inspect.json',
    'integration_test/ui_visual_capture_test.dart',
    'integration_test/support/ui_capture_metrics.dart',
    'integration_test/support/ui_frame_clock.dart',
    'integration_test/support/ui_presentation_fence.dart',
    'integration_test/support/ui_static_backdrop_probe.dart',
    'test_driver/ui_visual_capture_driver.dart',
    'test/ui_visual_capture_test.dart',
    'test/ui_frame_clock_test.dart',
    'test/ui_presentation_fence_test.dart',
    'test/ui_static_backdrop_probe_test.dart',
    'scripts/capture-android-ui.py',
    'scripts/prepare-ui-capture-source.py',
    'scripts/check-android-visuals.sh',
    'scripts/ui_capture_mp4.py',
    'scripts/test-ui-capture-host.py',
    'scripts/test-ui-capture-mp4.py',
    'scripts/inspect-ui-capture.py',
    'scripts/inspect-runtime-artifact.py',
    'scripts/test-runtime-artifact-inspect.py',
    'scripts/native-source-proof.py',
    'scripts/test-native-source-proof.py',
    '.github/workflows/ui-visuals.yml',
    '.github/workflows/ui-capture-inspect.yml',
})
REQUIRED_ANDROID_STEPS = frozenset({
    'Format, analyze, test and build',
    'Verify product APK signature',
    'Exercise real Android audio and video APIs',
    'Inspect encoded audio, video and cursor timing',
})
SWIFT_JOB = 'Pure Swift audio state (Linux; not iOS runtime)'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, url):
        raise ValueError('Unexpected Actions API redirect')


def read_actions_json(suffix, token):
    # Only internal, fixed suffixes reach this function; never request an input
    # URL or expose authorization in error/status output. TLS stays enabled.
    if suffix not in (f'/runs/{ACCEPTED_RUN}', f'/runs/{ACCEPTED_RUN}/jobs?per_page=100'):
        raise ValueError('Unrecognized fixed Actions resource')
    request = urllib.request.Request(
        'https://api.github.com/repos/' + REPOSITORY + '/actions' + suffix,
        headers={'Authorization': 'Bearer ' + token,
                 'Accept': 'application/vnd.github+json',
                 'X-GitHub-Api-Version': '2022-11-28'},
    )
    opener = urllib.request.build_opener(NoRedirect())
    with opener.open(request, timeout=8) as response:
        data = response.read(1_000_001)
    if len(data) > 1_000_000:
        raise ValueError('Actions response exceeds bounded proof size')
    return json.loads(data)


def accepted_gate_verified(token):
    if not isinstance(token, str) or not token:
        return False
    try:
        run = read_actions_json(f'/runs/{ACCEPTED_RUN}', token)
        if (type(run.get('id')) is not int or run['id'] != ACCEPTED_RUN
                or run.get('repository', {}).get('full_name') != REPOSITORY
                or run.get('head_sha') != ACCEPTED_SOURCE
                or run.get('path') != WORKFLOW
                or run.get('status') != 'completed'
                or run.get('conclusion') != 'success'):
            return False
        report = read_actions_json(f'/runs/{ACCEPTED_RUN}/jobs?per_page=100', token)
        jobs = report.get('jobs')
        if not isinstance(jobs, list) or type(report.get('total_count')) is not int or not 2 <= report['total_count'] <= 100 or report['total_count'] != len(jobs):
            return False
        def unique_job(name):
            matches = [job for job in jobs if job.get('name') == name]
            if len(matches) != 1:
                return None
            job = matches[0]
            if type(job.get('run_id')) is not int or job['run_id'] != ACCEPTED_RUN or job.get('status') != 'completed' or job.get('conclusion') != 'success':
                return None
            return job
        android = unique_job('Analyze, test and build Android')
        swift = unique_job(SWIFT_JOB)
        if not android or not swift:
            return False
        def steps_passed(job, required):
            steps = job.get('steps')
            if not isinstance(steps, list):
                return False
            for name in required:
                matches = [step for step in steps if step.get('name') == name]
                if len(matches) != 1 or matches[0].get('status') != 'completed' or matches[0].get('conclusion') != 'success':
                    return False
            return True
        return steps_passed(android, REQUIRED_ANDROID_STEPS) and steps_passed(swift, {'Execute render-used scheduling and reset policy regressions'})
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        return False


def evaluate(repository, token, cwd=None, *, expected_workflow_sha256=None):
    """Default uses a reviewed constant; explicit hash exists only for unit tests.

    No runtime environment/CLI override can change the anchor, run, exclusions
    or expected workflow hash. Unknown ancestry/auth/API/path always runs native.
    """
    result = {'native_required': True, 'native_reused_source': '', 'native_reused_run': '',
              'reason': 'unverified', 'scope': 'Native acceptance reuse only; current core/JVM/lint/build remain required.'}
    if repository != REPOSITORY or not isinstance(token, str) or not token:
        result['reason'] = 'repository-or-auth-unavailable'
        return result
    expected = REVIEWED_ANDROID_WORKFLOW_SHA256 if expected_workflow_sha256 is None else expected_workflow_sha256
    if not isinstance(expected, str) or not re.fullmatch(r'[0-9a-f]{64}', expected):
        result['reason'] = 'workflow-hash-unreviewed'
        return result
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=cwd, stderr=subprocess.DEVNULL, timeout=5)
    try:
        head = git('rev-parse', '--verify', 'HEAD^{commit}').decode().strip()
        anchor = git('rev-parse', '--verify', ACCEPTED_SOURCE + '^{commit}').decode().strip()
        if not re.fullmatch(r'[0-9a-f]{40}', head) or anchor != ACCEPTED_SOURCE:
            raise ValueError('Missing exact source history')
        git('merge-base', '--is-ancestor', ACCEPTED_SOURCE, head)
        tracked_workflow = git('show', 'HEAD:' + WORKFLOW)
        actual_workflow = (Path(cwd or '.') / WORKFLOW).read_bytes()
        if hashlib.sha256(tracked_workflow).hexdigest() != expected or actual_workflow != tracked_workflow:
            result['reason'] = 'workflow-hash-mismatch'
            return result
        committed = git('diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', ACCEPTED_SOURCE, head)
        working = git('diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', 'HEAD')
        names = set((committed + working).decode('utf-8').split('\0')) - {''}
        if any(not (name.startswith('docs/') or name in CAPTURE_ONLY or name == WORKFLOW) for name in names):
            result['reason'] = 'protected-tracked-input-changed'
            return result
    except (OSError, ValueError, UnicodeError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        result['reason'] = 'history-or-working-tree-unavailable'
        return result
    if not accepted_gate_verified(token):
        result['reason'] = 'exact-native-acceptance-not-verified'
        return result
    result.update(native_required=False, native_reused_source=ACCEPTED_SOURCE,
                  native_reused_run=str(ACCEPTED_RUN), reason='protected-inputs-unchanged-and-exact-native-gate-verified')
    return result


def main():
    result = evaluate(os.environ.get('GITHUB_REPOSITORY', ''), os.environ.get('DRAWMUSIC_GATE_TOKEN', ''))
    print(json.dumps(result, sort_keys=True))
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with Path(output).open('a') as file:
            for name in ('native_required', 'native_reused_source', 'native_reused_run'):
                value = str(result[name]).lower() if isinstance(result[name], bool) else result[name]
                file.write(f'{name}={value}\n')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with Path(summary).open('a') as file:
            if result['native_required']:
                file.write('Native emulator gate required: source/acceptance proof was not established. Current core/JVM/lint/build remain required.\n')
            else:
                file.write(f'Native acceptance **reused, not executed again**: [accepted source `{ACCEPTED_SOURCE}`](https://github.com/{REPOSITORY}/commit/{ACCEPTED_SOURCE}) and [full successful Android/native inspection + Swift run {ACCEPTED_RUN}](https://github.com/{REPOSITORY}/actions/runs/{ACCEPTED_RUN}). Current protected tracked inputs match; current core/JVM/lint/build remain required.\n')


if __name__ == '__main__':
    main()
