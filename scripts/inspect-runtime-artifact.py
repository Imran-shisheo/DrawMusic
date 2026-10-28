#!/usr/bin/env python3
"""Bounded read-only inspection of exact repository Android runtime evidence.

No network, commands, URLs, arbitrary input paths or device operations. The
workflow downloads the explicitly requested repository artifact before this runs.
"""
import hashlib
import json
from pathlib import Path
import re
import stat
import xml.etree.ElementTree as ET

ROOT = Path('work/ui-capture-inspect')
REQUEST = Path('cloud/ui-capture-inspect.json')
MAX_TOTAL = 12 * 1024 * 1024
JUNIT_ROOT = Path('build/app/outputs/androidTest-results')
FIXED = {
    Path('work/runtime-output/android.log'): 8 * 1024 * 1024,
    Path('work/runtime-output/hd-background-host.json'): 128 * 1024,
    Path('work/runtime-output/runtime-transport-before.json'): 128 * 1024,
    Path('work/runtime-output/runtime-transport-failure.json'): 128 * 1024,
    Path('work/runtime-output/runtime-transport-final.json'): 128 * 1024,
}
SIGNALS = re.compile(r'fatal|exception|signal [0-9]+|outofmemory|low.?memory|killed|SIGABRT|SIGSEGV|DartVM|flutter|VM.?service|crash', re.I)


def validate_request(request):
    if request.get('mode') != 'runtime':
        raise ValueError('Runtime inspection requires explicit mode')
    if type(request.get('runId')) is not int or request['runId'] <= 0:
        raise ValueError('Expected positive exact run ID')
    if type(request.get('artifactId')) is not int or request['artifactId'] <= 0:
        raise ValueError('Expected positive exact artifact ID (attempts may share names)')
    if not isinstance(request.get('artifactName'), str) or not re.fullmatch(r'drawmusic-runtime-evidence-[0-9a-f]{40}', request['artifactName']):
        raise ValueError('Expected exact runtime evidence artifact name')
    if set(request) != {'mode', 'runId', 'artifactId', 'artifactName'}:
        raise ValueError('Runtime requests cannot select arbitrary paths/options')


def safe_bytes(root, relative, limit):
    current = root
    if root.is_symlink():
        raise ValueError('Artifact root cannot be a symlink')
    for component in relative.parts:
        current = current / component
        if current.is_symlink():
            raise ValueError('Artifact symlink rejected')
    info = current.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
        raise ValueError('Artifact text is not a bounded regular file')
    if not current.resolve().is_relative_to(root.resolve()):
        raise ValueError('Artifact path escaped fixed root')
    return current.read_bytes()


def inspect(root, request, emit=print):
    validate_request(request)
    emit('RUNTIME_INSPECT_REQUEST ' + json.dumps(request, sort_keys=True))
    emit('RUNTIME_INSPECT_SCOPE Exact stored emulator diagnostic text; not a test rerun, physical/iOS acceptance or proof of an unrecorded cause.')
    used = 0
    found = 0
    for relative, limit in FIXED.items():
        if not (root / relative).exists():
            emit('RUNTIME_INSPECT_MISSING ' + str(relative))
            continue
        data = safe_bytes(root, relative, limit)
        used += len(data)
        found += 1
        text = data.decode('utf-8', errors='replace')
        emit('RUNTIME_INSPECT_BEGIN ' + str(relative))
        emit('RUNTIME_INSPECT_FILE ' + json.dumps({'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}))
        if relative.name.endswith('.json'):
            emit(json.dumps(json.loads(text), sort_keys=True))
        else:
            lines = text.splitlines()
            emit('RUNTIME_LOG_SIGNAL_LINES (bounded100; duplicates may also occur in tail)')
            for line in [v for v in lines if SIGNALS.search(v)][-100:]:
                emit(line[:2000])
            emit('RUNTIME_LOG_LAST160')
            for line in lines[-160:]:
                emit(line[:2000])
        emit('RUNTIME_INSPECT_END ' + str(relative))
    directory = root / JUNIT_ROOT
    if directory.exists():
        if directory.is_symlink():
            raise ValueError('JUnit root symlink rejected')
        paths = sorted(directory.rglob('TEST-*.xml'))
        if len(paths) > 32:
            raise ValueError('JUnit file count exceeds32')
        for path in paths:
            relative = path.relative_to(root)
            if not re.fullmatch(r'TEST-[^/\\\x00-\x1f]{1,220}\.xml', path.name):
                raise ValueError('JUnit filename rejected')
            data = safe_bytes(root, relative, 256 * 1024)
            used += len(data)
            if used > MAX_TOTAL:
                raise ValueError('Total runtime text bound exceeded')
            if b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper():
                raise ValueError('JUnit external/entity declarations rejected')
            suite = ET.fromstring(data)
            found += 1
            emit('RUNTIME_JUNIT_BEGIN ' + str(relative))
            emit(json.dumps({'suite': suite.attrib}, sort_keys=True))
            cases = list(suite.iter('testcase'))
            if len(cases) > 200:
                raise ValueError('JUnit case count exceeds200')
            for case in cases:
                record = dict(case.attrib)
                for tag in ('failure', 'error', 'skipped'):
                    item = case.find(tag)
                    if item is not None:
                        record[tag] = {'attributes': item.attrib, 'text': (item.text or '')[:3000]}
                emit('RUNTIME_JUNIT_CASE ' + json.dumps(record, sort_keys=True))
            emit('RUNTIME_JUNIT_END ' + str(relative))
    if not found:
        raise ValueError('No allowed runtime evidence found; refusing false diagnostic success')
    emit('RUNTIME_INSPECT_TOTAL ' + json.dumps({'files': found, 'bytes': used}))


if __name__ == '__main__':
    inspect(ROOT, json.loads(REQUEST.read_text()))
