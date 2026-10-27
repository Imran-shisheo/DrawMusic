#!/usr/bin/env python3
"""Read-only inspection of this repository's diagnostic UI artifact.

Optional PNGs are the exact ADB screenshots, not regenerated widgets. Their SHA
must match the capture host's report. Only original fixture content is captured;
this does not read an owner's phone or arbitrary files from the runner.
"""
import base64
import hashlib
import json
from pathlib import Path
import re

ROOT = Path('work/ui-capture-inspect')


def main():
    request = json.loads(Path('cloud/ui-capture-inspect.json').read_text())
    for name in ('source-provenance.json', 'capture-report.json', 'flutter-drive.log'):
        path = ROOT / name
        print(f'UI_INSPECT_START {name}', flush=True)
        value = path.read_text(errors='replace') if path.exists() else 'Missing diagnostic file'
        for line in value.splitlines()[-180:]:
            if 'UI_CAPTURE_TOKEN=' not in line:
                print(line, flush=True)
        print(f'UI_INSPECT_END {name}', flush=True)
    for path in sorted((ROOT / 'performance').glob('*.json')):
        value = json.loads(path.read_text())
        value.pop('rawFrames', None)
        print(f'UI_PERFORMANCE_SUMMARY {path.name} {json.dumps(value)}', flush=True)
    screenshots = request.get('screenshots', [])
    if not isinstance(screenshots, list) or len(screenshots) > 4:
        raise ValueError('Select at most four exact PNG names per read-only inspection')
    report = json.loads((ROOT / 'capture-report.json').read_text())
    expected = {item['name'] + '.png': item['sha256'] for item in report.get('events', []) if item.get('operation') == 'snapshot'}
    total = 0
    for name in screenshots:
        if not isinstance(name, str) or not re.fullmatch(r'[0-9]{2}-[a-z0-9-]{1,70}\.png', name):
            raise ValueError('Screenshot name rejected')
        data = (ROOT / 'screenshots' / name).read_bytes()
        total += len(data)
        if not data.startswith(b'\x89PNG\r\n\x1a\n') or total > 1_000_000:
            raise ValueError('PNG signature/inspection batch size rejected')
        digest = hashlib.sha256(data).hexdigest()
        if digest != expected.get(name):
            raise ValueError('Screenshot bytes do not match the actual capture report')
        print(f'UI_CAPTURE_PNG_BEGIN|{name}|{digest}|{len(data)}', flush=True)
        encoded = base64.b64encode(data).decode('ascii')
        for offset in range(0, len(encoded), 160):
            print('UI_CAPTURE_PNG_DATA|' + encoded[offset:offset + 160], flush=True)
        print(f'UI_CAPTURE_PNG_END|{name}', flush=True)


if __name__ == '__main__':
    main()
