#!/usr/bin/env python3
"""Pin capture product source separately from the new diagnostic harness."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

FILES = ['integration_test/ui_visual_capture_test.dart', 'integration_test/support/ui_capture_metrics.dart',
         'test_driver/ui_visual_capture_driver.dart', 'scripts/capture-android-ui.py', 'scripts/check-android-visuals.sh',
         'scripts/test-ui-capture-host.py', 'scripts/prepare-runtime-inspectors.sh']

def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()

def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Refusing to change a developer checkout; this is a disposable Actions-only preparation')
    request = json.loads(Path('cloud/ui-capture-request.json').read_text())
    source, label = request.get('sourceRef'), request.get('label')
    if request.get('schema') != 1 or not isinstance(source, str) or not re.fullmatch(r'[0-9a-f]{40}', source) or label not in ('before', 'after'):
        raise ValueError('Expected a full commit SHA and before/after label')
    harness = git('rev-parse', 'HEAD')
    if git('cat-file', '-t', source) != 'commit':
        raise ValueError('Requested source is not an available repository commit')
    with tempfile.TemporaryDirectory(prefix='drawmusic-ui-harness-') as scratch:
        for item in FILES:
            target = Path(scratch) / item
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(item, target)
        git('checkout', '--detach', source)
        if git('rev-parse', 'HEAD') != source:
            raise RuntimeError('Pinned product checkout did not match request')
        tree = git('rev-parse', 'HEAD^{tree}')
        for item in FILES:
            target = Path(item)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(Path(scratch) / item, target)
    output = Path('work/ui-capture'); output.mkdir(parents=True, exist_ok=True)
    (output / 'source-provenance.json').write_text(json.dumps({
        'label': label, 'productSourceSha': source, 'productTreeSha': tree,
        'captureHarnessSourceSha': harness, 'instrumentationFiles': FILES,
        'scope': 'Actual pinned production widget/native source plus separately identified diagnostic target. Not a substitute for full functional acceptance.'
    }, indent=2) + '\n')
    print(f'Capture product source {source}; diagnostic harness {harness}; label {label}', flush=True)

if __name__ == '__main__':
    main()
