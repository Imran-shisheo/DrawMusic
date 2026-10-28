#!/usr/bin/env python3
"""Evidence only for the one disposable Actions QEMU. Never retries or repairs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

DEVICE = 'emulator-5554'
PACKAGE = 'com.imranshisheo.scribblesong'
OUTPUT = Path('work/runtime-output')
TAGS = ['ActivityManager:I', 'ActivityTaskManager:I', 'lmkd:I', 'libc:I', 'flutter:I', 'DartVM:I', 'AndroidRuntime:I', '*:S']


def command(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=3, check=False)
        return {'returncode': result.returncode, 'stdout': result.stdout[-20000:], 'stderr': result.stderr[-2000:]}
    except subprocess.TimeoutExpired:
        return {'error': 'timeout after3s'}
    except OSError as error:
        return {'error': type(error).__name__}


def read_fixed(path):
    try:
        with Path(path).open() as file:
            return file.read(4096)
    except OSError as error:
        return {'unavailable': type(error).__name__}


def host_resources():
    wanted = {'MemTotal', 'MemAvailable', 'MemFree', 'SwapTotal', 'SwapFree'}
    memory = read_fixed('/proc/meminfo')
    if isinstance(memory, str):
        memory = {line.split(':', 1)[0]: line.split(':', 1)[1].strip() for line in memory.splitlines() if ':' in line and line.split(':', 1)[0] in wanted}
    processes = []
    for entry in sorted(Path('/proc').iterdir(), key=lambda value: value.name)[:10000]:
        if not entry.name.isdigit():
            continue
        name = read_fixed(entry / 'comm')
        if not isinstance(name, str) or name.strip() not in {'adb', 'java', 'dart', 'emulator', 'qemu-system-x86', 'qemu-system-aar'}:
            continue
        status = read_fixed(entry / 'status')
        fields = {}
        if isinstance(status, str):
            fields = {line.split(':', 1)[0]: line.split(':', 1)[1].strip() for line in status.splitlines() if ':' in line and line.split(':', 1)[0] in {'State', 'PPid', 'VmRSS', 'Threads'}}
        processes.append({'pid': int(entry.name), 'name': name.strip(), **fields})
        if len(processes) >= 60:
            break
    disk = shutil.disk_usage('.')
    return {'memory': memory, 'diskFreeBytes': disk.free, 'diskTotalBytes': disk.total,
            'processes': processes,
            'cgroup': {name: read_fixed('/sys/fs/cgroup/' + name) for name in ('memory.current', 'memory.max', 'memory.peak', 'memory.events')},
            'scope': 'Host counters and named process status only; no cmdline/environment. Cgroup events are whole-job evidence, not per-process OOM attribution.'}


def snapshot(stage, *, verified_qemu=False, output=OUTPUT):
    if stage not in {'before', 'failure', 'final'}:
        raise ValueError('Unknown fixed diagnostic stage')
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Only disposable Actions diagnostics authorized')
    result = {'stage': stage, 'epochSeconds': time.time(), 'device': DEVICE, 'package': PACKAGE,
              'evidenceOnly': True, 'priorQemuVerified': verified_qemu, 'qemuVerified': False, 'host': host_resources()}
    # Host-only ADB metadata remains useful even if the device transport vanished.
    result['adbVersion'] = command(['adb', 'version'])
    result['devices'] = command(['adb', 'devices', '-l'])
    identity = command(['adb', '-s', DEVICE, 'shell', 'getprop', 'ro.kernel.qemu'])
    result['qemuIdentity'] = identity
    if identity.get('returncode') == 0 and identity.get('stdout', '').strip() == '1':
        result['qemuVerified'] = True
        result['deviceState'] = command(['adb', '-s', DEVICE, 'get-state'])
        result['bootCompleted'] = command(['adb', '-s', DEVICE, 'shell', 'getprop', 'sys.boot_completed'])
        result['appPid'] = command(['adb', '-s', DEVICE, 'shell', 'pidof', PACKAGE])
        result['guestMemory'] = command(['adb', '-s', DEVICE, 'shell', 'cat', '/proc/meminfo'])
        result['appMemory'] = command(['adb', '-s', DEVICE, 'shell', 'dumpsys', 'meminfo', PACKAGE])
        result['logcat'] = command(['adb', '-s', DEVICE, 'logcat', '-d', '-v', 'threadtime', '-b', 'main,system,crash', '-t', '200', *TAGS])
    else:
        result['deviceReadsSkipped'] = 'QEMU identity unavailable/unrecognized; no package/logcat reads attempted'
    output.mkdir(parents=True, exist_ok=True)
    (output / f'runtime-transport-{stage}.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def safe_snapshot(stage, *, verified_qemu=False, output=OUTPUT):
    try:
        return snapshot(stage, verified_qemu=verified_qemu, output=output)
    except Exception as error:
        # Diagnostics must never replace the original test failure/exit code.
        print('RUNTIME_DIAGNOSTIC_UNAVAILABLE ' + type(error).__name__, flush=True)
        return None


if __name__ == '__main__':
    safe_snapshot('final')
