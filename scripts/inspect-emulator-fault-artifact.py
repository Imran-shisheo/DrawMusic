#!/usr/bin/env python3
"""Fixed-path read-only inspection of one unaccepted owned-SDK trace.

No SDK launch, arbitrary file selection, raw console/environment/map dumps or
inference of a natural SDK exit signal from LLDB's raw numeric exit status.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re

spec = importlib.util.spec_from_file_location('bounded_runtime_reader', Path(__file__).with_name('inspect-runtime-artifact.py'))
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
PREFIX = Path('ui-capture/emulator-lldb-trace')
FIELDS = {
    'installation.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'installed', 'sdkSha256', 'controllerSha256'),
    'lifecycle.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'phase', 'sdkSha256', 'controllerSha256', 'wrapperPid', 'ownedDebuggerPid', 'debuggerReturncode', 'debuggerTerminationSignal', 'drainsComplete', 'startEpochSeconds', 'debuggerExitEpochSeconds', 'endEpochSeconds'),
    'collection.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'observerPhase', 'debuggerFinished', 'tracePhase', 'traceBytes', 'traceSha256'),
    'faults.json': ('schema', 'diagnosticOnly', 'acceptanceEligible', 'phase', 'ownedInferiorPid', 'sigsegvStopsObserved', 'actualExitStatus', 'finalStateName', 'startEpochSeconds', 'endEpochSeconds', 'errorCategory', 'launchErrorCode', 'continueErrorCode'),
}
TOKENS = ('dynamic loader', 'rendezvous', 'link_map', 'failed to read', 'unable to read', 'could not read', 'invalid address', 'unwind', 'unsupported', 'exec', 'lldb', 'error:', 'warning:')


def validate_request(request):
    if set(request) != {'mode', 'runId', 'artifactId', 'artifactName'} or request.get('mode') != 'emulator-fault':
        raise ValueError('Explicit fixed-schema emulator-fault inspection required')
    if any(type(request.get(key)) is not int or request[key] <= 0 for key in ('runId', 'artifactId')):
        raise ValueError('Positive exact run and artifact IDs required')
    if not isinstance(request.get('artifactName'), str) or not re.fullmatch(r'drawmusic-emulator-fault-trace-[0-9a-f]{40}', request['artifactName']):
        raise ValueError('Only explicitly unaccepted fault-trace artifacts allowed')


def scalar(value):
    if value is None or type(value) in (bool, int, float):
        return value
    if isinstance(value, str):
        return value[:160]
    return '<non-scalar omitted>'


def inspect(root, request, emit=print):
    validate_request(request)
    result = {'diagnosticOnly': True, 'acceptanceEligible': False, 'request': request, 'files': [], 'missing': [],
              'scope': 'Stored fixed-path owned debugger metadata only. Console bytes are hashed/classified, never printed. Numeric LLDB exit status is not a natural SDK signal.'}
    found = 0
    for name, fields in FIELDS.items():
        relative = PREFIX / name
        if not (root / relative).exists():
            result['missing'].append(str(relative))
            continue
        data = reader.safe_bytes(root, relative, 32768)
        value = json.loads(data)
        if not isinstance(value, dict):
            raise ValueError('Diagnostic metadata must be an object')
        item = {'file': str(relative), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                'selected': {key: scalar(value.get(key)) for key in fields}}
        if name == 'lifecycle.json':
            signals = value.get('wrapperSignals', [])
            if not isinstance(signals, list) or len(signals) > 16:
                raise ValueError('Bounded wrapper signals required')
            item['wrapperSignals'] = [{key: scalar(signal.get(key)) for key in ('signal', 'epochSeconds', 'forwardedToVerifiedOwnedDebugger')}
                                      for signal in signals if isinstance(signal, dict)]
            item['drains'] = {channel: {key: scalar(value.get(channel, {}).get(key))
                                       for key in ('bytesDrained', 'headBytes', 'tailBytes', 'eof', 'truncated')}
                              for channel in ('stdout', 'stderr')}
        result['files'].append(item)
        found += 1
    for channel in ('stdout', 'stderr'):
        for part, limit in (('head', 65536), ('tail', 262144)):
            relative = PREFIX / f'{channel}-{part}.log'
            if not (root / relative).exists():
                result['missing'].append(str(relative))
                continue
            data = reader.safe_bytes(root, relative, limit)
            text = data.decode('utf-8', errors='replace').lower()
            result['files'].append({'file': str(relative), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                                    'diagnosticTokenCounts': {token: text.count(token) for token in TOKENS},
                                    'rawConsolePrinted': False})
            found += 1
    if not found:
        raise ValueError('No fixed diagnostic evidence found')
    emit('OWNED_SDK_TRACE_INSPECTION ' + json.dumps(result, sort_keys=True))
    return result


if __name__ == '__main__':
    inspect(Path('work/ui-capture-inspect'), json.loads(Path('cloud/ui-capture-inspect.json').read_text()))
