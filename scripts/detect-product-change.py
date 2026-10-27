#!/usr/bin/env python3
"""Avoid repeating product gates for proven documentation-only PR synchronizes.

Unknown event/history/path or unverified preceding gate always runs the full gate. No accepted product checks
are replaced: first runs and every product/test/tool/workflow change run it.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request


def product_changed(event_name, event, cwd=None):
    before = event.get('before', '')
    if event_name != 'pull_request' or event.get('action') != 'synchronize' or not isinstance(before, str) or not re.fullmatch(r'[a-f0-9]{40}', before):
        return True
    try:
        result = subprocess.run(['git', 'diff', '--name-only', '-z', before, 'HEAD'], cwd=cwd, capture_output=True, check=True)
        names = result.stdout.decode('utf-8').split('\0')
    except (OSError, subprocess.CalledProcessError, UnicodeError):
        return True
    names = [name for name in names if name]
    def documentation(name):
        return name.startswith('docs/') or name in ('README.md', 'cloud/ui-capture-request.json', 'cloud/ui-capture-inspect.json')
    return not names or not all(documentation(name) for name in names)


def comparison_event(event, cwd=None):
    # Some PR payloads omit before. Use only the actual head's first parent,
    # never the synthetic merge's base, and still require that exact gate proof.
    if event.get('before') or event.get('action') != 'synchronize':
        return event
    head = event.get('pull_request', {}).get('head', {}).get('sha')
    if not isinstance(head, str) or not re.fullmatch(r'[a-f0-9]{40}', head):
        return event
    try:
        parent = subprocess.check_output(['git', 'rev-parse', head + '^'], cwd=cwd, stderr=subprocess.DEVNULL, text=True).strip()
        if re.fullmatch(r'[a-f0-9]{40}', parent):
            return {**event, 'before': parent}
    except (OSError, subprocess.CalledProcessError):
        pass
    return event


def previous_gate_passed(before, repository, token):
    """A docs-only diff cannot stand in for an unfinished/canceled gate."""
    if repository != 'Imran-shisheo/DrawMusic' or not token or not isinstance(before, str) or not re.fullmatch(r'[a-f0-9]{40}', before):
        return False
    base = 'https://api.github.com/repos/' + repository + '/actions'
    def read(url):
        request = urllib.request.Request(url, headers={
            'Authorization': 'Bearer ' + token,
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
        })
        with urllib.request.urlopen(request, timeout=8) as response:
            return json.load(response)
    try:
        runs = read(base + '/workflows/android.yml/runs?head_sha=' + before + '&status=success&per_page=5')
        for run in runs.get('workflow_runs', []):
            if run.get('head_sha') != before or run.get('status') != 'completed' or run.get('conclusion') != 'success':
                continue
            jobs = read(base + '/runs/' + str(int(run['id'])) + '/jobs?per_page=100')
            passed = {job.get('name') for job in jobs.get('jobs', []) if job.get('conclusion') == 'success'}
            if {'Analyze, test and build Android', 'Pure Swift audio state (Linux; not iOS runtime)'}.issubset(passed):
                return True
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return False
    return False


def main():
    try:
        event = comparison_event(json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text()))
        changed = product_changed(os.environ.get('GITHUB_EVENT_NAME'), event)
        prior_verified = False
        if os.environ.get('GITHUB_EVENT_NAME') == 'pull_request' and event.get('action') == 'synchronize':
            prior_verified = previous_gate_passed(
                event.get('before', ''), os.environ.get('GITHUB_REPOSITORY', ''),
                os.environ.get('DRAWMUSIC_GATE_TOKEN', ''),
            )
        changed = changed or not prior_verified
        print('Previous exact-head full gate verified: ' + str(prior_verified).lower())
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        changed = True
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
        output.write(f'product_changed={str(changed).lower()}\n')
    print('Full product gate required.' if changed else 'Documentation/capture request only; the preceding exact head has a completed successful full Android and Swift gate.')


if __name__ == '__main__':
    main()
