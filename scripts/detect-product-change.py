#!/usr/bin/env python3
"""Avoid repeating product gates for proven documentation-only PR synchronizes.

Unknown event/history/path always runs the full gate. No accepted product checks
are replaced: first runs and every product/test/tool/workflow change run it.
"""
import json
import os
from pathlib import Path
import re
import subprocess


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


def main():
    try:
        event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
        changed = product_changed(os.environ.get('GITHUB_EVENT_NAME'), event)
    except (OSError, ValueError, KeyError, TypeError):
        changed = True
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
        output.write(f'product_changed={str(changed).lower()}\n')
    print('Full product gate required.' if changed else 'Only documentation/capture request changed; product source remains unchanged from the preceding head.')


if __name__ == '__main__':
    main()
