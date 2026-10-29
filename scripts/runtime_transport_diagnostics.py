#!/usr/bin/env python3
"""Evidence only for the one disposable Actions QEMU. Never retries or repairs."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

DEVICE = 'emulator-5554'
PACKAGE = 'com.imranshisheo.scribblesong'
OUTPUT = Path('work/runtime-output')
TAGS = ['ActivityManager:I', 'ActivityTaskManager:I', 'lmkd:I', 'libc:I', 'flutter:I', 'DartVM:I', 'AndroidRuntime:I', '*:S']
CGROUP_ROOT = Path('/sys/fs/cgroup')
CGROUP_FILES = {
    'v2': ('memory.current', 'memory.max', 'memory.peak', 'memory.events', 'memory.events.local', 'cpu.stat', 'cpu.max'),
    'memory': ('memory.usage_in_bytes', 'memory.limit_in_bytes', 'memory.max_usage_in_bytes', 'memory.failcnt', 'memory.oom_control'),
    'cpu': ('cpu.stat', 'cpu.cfs_quota_us', 'cpu.cfs_period_us'),
    'cpuacct': ('cpuacct.usage',),
}


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


def own_cgroup_resources():
    """Resolve only this job's declared membership, never arbitrary host paths."""
    membership = read_fixed('/proc/self/cgroup')
    if not isinstance(membership, str):
        return {'membershipUnavailable': membership}
    result = []
    root = CGROUP_ROOT.resolve()
    for line in membership.splitlines()[:32]:
        pieces = line.split(':', 2)
        if len(pieces) != 3:
            continue
        hierarchy, controllers, member = pieces
        groups = [('v2', '')] if hierarchy == '0' and not controllers else [
            (name, directory) for name in ('memory', 'cpu', 'cpuacct')
            if name in controllers.split(',')
            for directory in ((controllers,) if controllers in ('cpu,cpuacct', 'cpuacct,cpu') else (name,))]
        for version, directory in groups:
            item = {'controller': version}
            result.append(item)
            # Reject traversal, including a namespace-relative ../../ path;
            # do not guess another host's cgroup location or walk ancestors.
            if not member.startswith('/') or '..' in Path(member).parts:
                item['unavailable'] = 'UnsafeMembershipPath'
                continue
            candidate = (root / directory / member.lstrip('/')).resolve()
            try:
                candidate.relative_to(root)
            except ValueError:
                item['unavailable'] = 'CgroupPathOutsideExpectedFilesystem'
                continue
            item['counters'] = {}
            for name in CGROUP_FILES[version]:
                target = candidate / name
                try:
                    target.resolve().relative_to(root)
                except ValueError:
                    item['counters'][name] = {'unavailable': 'CgroupPathOutsideExpectedFilesystem'}
                    continue
                value = read_fixed(target)
                item['counters'][name] = value[:1024] if isinstance(value, str) else value
        if len(result) >= 4:
            break
    return {'memberships': result[:4],
            'scope': 'Own declared membership only; unavailable counters are explicit. Counter changes alone do not attribute a QEMU exit or prove OOM.'}


def kernel_termination_signals():
    """Read-only, fixed recent kernel queries; publish signals, not raw logs."""
    attempts = []
    dmesg = ['dmesg', '--since', '-15min', '--level=emerg,alert,crit,err,warn', '--nopager']
    queries = [('dmesg', dmesg)]
    # Standard disposable Actions runners can deny unprivileged kernel reads.
    # Fixed, noninteractive, read-only fallback; never used outside Actions,
    # never changes kernel policy or requests credentials.
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        queries.append(('sudo-dmesg', ['sudo', '-n', *dmesg]))
    queries.append(('journalctl', ['journalctl', '--dmesg', '--since=-15min', '--no-pager', '--quiet', '--lines=200', '--output=short-monotonic']))
    for source, args in queries:
        value = command(args)
        attempt = {'source': source, 'returncode': value.get('returncode')}
        attempts.append(attempt)
        if value.get('returncode') != 0:
            attempt['unavailable'] = value.get('error', 'ReadDeniedOrUnsupported')
            continue
        matches = []
        for line in value.get('stdout', '').splitlines()[-200:]:
            lower = line.lower()
            # Never publish raw kernel text: OOM messages may contain task
            # command lines, paths or environment. Only fixed signal names
            # and bounded numeric/process identifiers leave this function.
            signals = [name for name, found in (
                ('oom', 'out of memory' in lower or 'oom-kill' in lower or 'oom_reaper' in lower),
                ('killed-process', 'killed process ' in lower),
                ('segfault', 'segfault' in lower),
                ('qemu-failure', 'qemu' in lower and any(word in lower for word in ('error', 'crash', 'trap', 'fatal'))),
            ) if found]
            if not signals:
                continue
            item = {'signals': signals}
            pid = re.search(r'\b(?:killed process|pid[=: ]+)\s*(\d{1,10})\b', lower)
            if not pid:
                pid = re.search(r'\b(?:qemu-system-[a-z0-9_-]{1,24}|emulator|java|dart)\[(\d{1,10})\]', lower)
            if pid:
                item['pid'] = int(pid.group(1))
            process = re.search(r'\b(qemu-system-[a-z0-9_-]{1,24}|emulator|java|dart)\b', lower)
            if process:
                item['process'] = process.group(1)
            module = re.search(r'\bin\s+([a-z0-9_.+-]{1,96}\.so(?:\.\d+){0,3})\b', lower)
            if module:
                item['moduleBasename'] = module.group(1)
            matches.append(item)
        return {'attempts': attempts, 'signals': matches[-40:],
                'scope': 'Recent bounded kernel suffix; structured signals only. Missing signals do not exclude termination/OOM; signals alone do not establish cause.'}
    return {'attempts': attempts, 'signals': [], 'unavailable': 'NoSupportedReadableKernelSource'}


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
            'ownCgroup': own_cgroup_resources(),
            'kernelTermination': kernel_termination_signals(),
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
    encoded = json.dumps(result, indent=2) + '\n'
    if len(encoded.encode()) > 128 * 1024:
        raise ValueError('Diagnostic snapshot exceeds fixed128KiB evidence bound')
    (output / f'runtime-transport-{stage}.json').write_text(encoded)
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
