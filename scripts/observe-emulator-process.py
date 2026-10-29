#!/usr/bin/env python3
"""Observe only the disposable Actions SDK launcher; no emulator repairs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import threading
import time

MODES = {'runtime': 'work/runtime-output/emulator-process', 'ui': 'work/ui-capture/emulator-process'}
HEAD_BYTES = 64 * 1024
TAIL_BYTES = 256 * 1024
DB_BYTES = 8 * 1024 * 1024
DB_FILES = 8
DB_PATTERN = re.compile(rb'(/tmp/android-runner/emu-crash-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.db)(?![A-Za-z0-9_./-])')


def gate():
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'Linux':
        raise RuntimeError('Only disposable Linux Actions launcher observation is authorized')


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(65536), b''):
            value.update(block)
    return value.hexdigest()


def atomic_json(path, value):
    data = (json.dumps(value, indent=2) + '\n').encode()
    if len(data) > 32768:
        raise ValueError('Observer manifest exceeds32KiB')
    temporary = path.with_name(path.name + f'.tmp-{os.getpid()}-{threading.get_ident()}')
    if path.is_symlink() or temporary.is_symlink():
        raise ValueError('Observer manifest symlink rejected')
    temporary.write_bytes(data)
    temporary.replace(path)


def output_path(mode):
    gate()
    path = Path.cwd() / MODES[mode]
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise ValueError('Observer output symlink rejected')
    path.mkdir(parents=True, exist_ok=True)
    return path


def validate_binary(path):
    if path.is_symlink() or not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError('Expected regular executable SDK launcher')
    with path.open('rb') as stream:
        if stream.read(4) != b'\x7fELF':
            raise ValueError('Expected trusted installed SDK ELF launcher')


def install(mode):
    out = output_path(mode)
    sdk_value = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not sdk_value:
        raise RuntimeError('Selected Android SDK is unavailable')
    sdk = Path(sdk_value).resolve(strict=True)
    launcher = sdk / 'emulator' / 'emulator'
    validate_binary(launcher)
    real = launcher.with_name('emulator.doodimo-original')
    config = launcher.with_name('emulator.doodimo-observer.json')
    if real.exists() or real.is_symlink() or config.exists() or config.is_symlink():
        raise RuntimeError('Observer already installed or reserved SDK path exists; no overwrite')
    script = Path(__file__).resolve()
    state = {'schema': 1, 'launcher': str(launcher), 'real': str(real), 'output': str(out),
             'binarySha256': digest(launcher), 'observerSha256': digest(script)}
    atomic_json(config, state)
    wrapper = ('#!/usr/bin/env python3\nimport os,sys\n'
               f'os.execv(sys.executable,[sys.executable,{str(script)!r},"launch",{str(config)!r},*sys.argv[1:]])\n')
    temporary = launcher.with_name('emulator.doodimo-wrapper.tmp')
    if temporary.exists() or temporary.is_symlink():
        raise RuntimeError('Reserved wrapper temporary path exists')
    temporary.write_text(wrapper)
    temporary.chmod(0o755)
    launcher.rename(real)
    try:
        temporary.replace(launcher)
    except Exception:
        real.rename(launcher)
        raise
    atomic_json(out/'installation.json', {'schema': 1, 'installed': True,
        'binarySha256': state['binarySha256'], 'observerSha256': state['observerSha256'],
        'scope': 'Temporary same-SDK-directory launcher wrapper; identical child argv0/options/environment. No product change.'})


def start_identity(pid):
    try:
        # Field22 is after the final ')' of comm; no cmdline/environment reads.
        return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]
    except (OSError, IndexError):
        return None


def forward_to_owned_child(process, identity, number):
    if process.poll() is not None or identity is None or start_identity(process.pid) != identity:
        return False
    try:
        process.send_signal(number)
        return True
    except ProcessLookupError:
        return False


def retain_crash_db(paths, out):
    result = {'scope': 'Only exact SDK-reported /tmp/android-runner/emu-crash-X.Y.Z.db; no unrelated dumps',
              'maxFiles': DB_FILES, 'maxTotalBytes': DB_BYTES, 'files': [], 'skipped': []}
    count = total = 0
    for value in sorted(set(paths))[:1]:
        if not DB_PATTERN.fullmatch(value.encode()):
            result['skipped'].append({'reason': 'NonScopedDatabasePath'})
            continue
        source = Path(value)
        # No symlink component, including the fixed database root.
        if any(item.is_symlink() for item in (source, *source.parents)):
            result['skipped'].append({'reason': 'DatabaseSymlink'})
            continue
        try:
            info = source.stat()
        except OSError as error:
            result['skipped'].append({'reason': type(error).__name__})
            continue
        candidates = []
        if stat.S_ISREG(info.st_mode):
            candidates = [(source, Path(source.name))]
        elif stat.S_ISDIR(info.st_mode):
            visited = 0
            for directory, dirs, files in os.walk(source, followlinks=False):
                visited += 1
                if visited > 16:
                    result['skipped'].append({'reason': 'DatabaseDirectoryCountBound'})
                    break
                # Only files inside this one database; no sibling /tmp reads.
                safe_dirs = sorted(name for name in dirs if not (Path(directory)/name).is_symlink())
                if len(safe_dirs) != len(dirs):
                    result['skipped'].append({'reason': 'DatabaseDirectorySymlink'})
                if len(safe_dirs) > 8:
                    result['skipped'].append({'reason': 'DatabaseDirectoryFanoutBound'})
                dirs[:] = safe_dirs[:8]
                if len(files) > 16:
                    result['skipped'].append({'reason': 'DatabaseDirectoryFileBound'})
                for name in sorted(files)[:16]:
                    path = Path(directory)/name
                    candidates.append((path, Path(source.name)/path.relative_to(source)))
                    if len(candidates) >= 32:
                        result['skipped'].append({'reason': 'DatabaseCandidateBound'})
                        dirs[:] = []
                        break
        else:
            result['skipped'].append({'reason': 'NotRegularDatabaseOrDirectory'})
        for path, relative in candidates[:32]:
            if count >= DB_FILES:
                result['skipped'].append({'reason': 'DatabaseFileCountBound'})
                break
            try:
                before = path.lstat()
                if not stat.S_ISREG(before.st_mode) or any(part.is_symlink() for part in (path, *path.parents)):
                    result['skipped'].append({'reason': 'NotRegularDatabaseFile'})
                    continue
                if before.st_size > DB_BYTES-total:
                    result['skipped'].append({'reason': 'DatabaseByteBound', 'bytes': before.st_size})
                    continue
                descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
                with os.fdopen(descriptor, 'rb') as stream:
                    opened = os.fstat(stream.fileno())
                    data = stream.read(DB_BYTES-total+1)
                    after = os.fstat(stream.fileno())
                if ((opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns) !=
                    (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) or
                    (after.st_size, after.st_mtime_ns) != (before.st_size, before.st_mtime_ns) or
                    len(data) != before.st_size):
                    result['skipped'].append({'reason': 'DatabaseChangedDuringRead'})
                    continue
                target = out/'crash-db'/relative
                target.parent.mkdir(parents=True, exist_ok=True)
                if any(part.is_symlink() for part in (target, *target.parents)):
                    raise ValueError('Crash database output symlink rejected')
                target.write_bytes(data)
                count += 1; total += len(data)
                result['files'].append({'file': str(Path('crash-db')/relative), 'bytes': len(data),
                                        'sha256': hashlib.sha256(data).hexdigest()})
            except OSError as error:
                result['skipped'].append({'reason': type(error).__name__})
    if not paths:
        result['skipped'].append({'reason': 'NoScopedSdkDatabasePathObserved'})
    if len(set(paths)) > 1:
        result['skipped'].append({'reason': 'OnlyOneScopedDatabaseAllowed'})
    result['retainedBytes'] = total
    result['partialOrUnavailable'] = bool(result['skipped'])
    atomic_json(out/'crash-database.json', result)
    return result


def launch(config_path, arguments):
    gate()
    config_path = Path(config_path)
    if config_path.is_symlink() or config_path.stat().st_size > 32768:
        raise ValueError('Invalid observer config')
    config = json.loads(config_path.read_text())
    real, original, out = Path(config['real']), Path(config['launcher']), Path(config['output'])
    if real.parent != original.parent or real.name != 'emulator.doodimo-original' or original.name != 'emulator':
        raise ValueError('Observer launcher identity mismatch')
    validate_binary(real)
    if digest(real) != config['binarySha256']:
        raise ValueError('Original SDK binary SHA changed')
    # Version/help/list invocations must behave exactly like the installed SDK.
    if not any(arg == '-avd' or arg.startswith('@') for arg in arguments):
        os.execve(real, [str(original), *arguments], os.environ)
    if any(part.is_symlink() for part in (out, *out.parents)):
        raise ValueError('Observer output symlink rejected')
    manifest = out/'lifecycle.json'
    if manifest.exists():
        raise RuntimeError('Only one owned AVD launch per disposable runner is supported')
    state = {'schema': 1, 'state': 'launching', 'binarySha256': config['binarySha256'],
        'observerSha256': config['observerSha256'], 'wrapperPid': os.getpid(),
        'startEpochSeconds': time.time(), 'startMonotonicSeconds': time.monotonic(),
        'wrapperSignals': [], 'reportedCrashDbPaths': [], 'observedExecutableNames': [],
        'scope': 'Actual owned SDK child status, not assumed QEMU cause; no argv/environment dump. Launcher exec into QEMU is observed by same-PID executable basename, not presumed.'}
    lock = threading.RLock()
    process = None
    def save():
        with lock:
            atomic_json(manifest, state)
    save()
    try:
        process = subprocess.Popen([str(original), *arguments], executable=str(real),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=os.environ)
        identity = start_identity(process.pid)
        state.update(state='running', childPid=process.pid, childStartTicks=identity)
        def forward(number, frame):
            with lock:
                entry = {'signal': number, 'epochSeconds': time.time(), 'forwardedToVerifiedChild': False}
                state['wrapperSignals'] = (state['wrapperSignals']+[entry])[-16:]
                entry['forwardedToVerifiedChild'] = forward_to_owned_child(process, identity, number)
                save()
        for number in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(number, forward)
        save()
        def drain(stream, name):
            tail = bytearray(); seen = 0; head_size = 0; last_save = 0.0; scan = b''
            head = None; errors = []; eof = False
            def note(error):
                if len(errors) < 4: errors.append(type(error).__name__)
            def save_tail():
                try: (out/(name+'-tail.log')).write_bytes(tail)
                except OSError as error: note(error)
            try:
                try: head = (out/(name+'-head.log')).open('wb')
                except OSError as error: note(error)
                while True:
                    try:
                        block = os.read(stream.fileno(), 4096)
                    except OSError as error:
                        note(error); break
                    if not block:
                        eof = True; break
                    seen += len(block)
                    if head is not None and head_size < HEAD_BYTES:
                        try:
                            part = block[:HEAD_BYTES-head_size]; head.write(part); head.flush(); head_size += len(part)
                        except OSError as error:
                            note(error)
                            try: head.close()
                            except OSError: pass
                            head = None
                    tail.extend(block); del tail[:-TAIL_BYTES]
                    scan = (scan+block)[-8192:]
                    with lock:
                        for match in DB_PATTERN.finditer(scan):
                            value = match.group(1).decode('ascii')
                            if value not in state['reportedCrashDbPaths'] and len(state['reportedCrashDbPaths']) < 2:
                                state['reportedCrashDbPaths'].append(value)
                    if time.monotonic()-last_save >= 1:
                        save_tail(); last_save = time.monotonic()
            finally:
                if head is not None:
                    try: head.close()
                    except OSError as error: note(error)
                save_tail()
                with lock:
                    state[name] = {'bytesDrained': seen, 'headBytes': head_size, 'tailBytes': len(tail),
                        'truncated': seen > HEAD_BYTES+TAIL_BYTES, 'eof': eof, 'logWriteOrReadErrors': errors}
        threads = [threading.Thread(target=drain, args=(stream, name), daemon=True)
                   for stream, name in ((process.stdout, 'stdout'), (process.stderr, 'stderr'))]
        for thread in threads: thread.start()
        while True:
            try:
                name = Path(f'/proc/{process.pid}/exe').resolve(strict=True).name
                if name not in state['observedExecutableNames'] and len(state['observedExecutableNames']) < 4:
                    state['observedExecutableNames'].append(name)
            except OSError:
                pass
            try:
                code = process.wait(timeout=.5)
                break
            except subprocess.TimeoutExpired:
                save()
        state.update(state='child-exited', childReturncode=code,
            childTerminationSignal=-code if code < 0 else None, childExitEpochSeconds=time.time())
        save()
        # A launcher may fork rather than exec. Keep inherited pipes drained
        # until EOF; never close a live descendant's pipe to force completion.
        while any(thread.is_alive() for thread in threads):
            for thread in threads: thread.join(timeout=.25)
            save()
        state.update(state='exited', drainsComplete=all(state.get(name, {}).get('eof') is True for name in ('stdout','stderr')),
            endEpochSeconds=time.time())
        state['crashDatabase'] = retain_crash_db(state['reportedCrashDbPaths'], out)
        save()
        return code if code >= 0 else 128-code
    except Exception as error:
        state.update(observerError=type(error).__name__, state='observer-error')
        save()
        # Do not signal/repair the emulator or replace status with a fabricated
        # child exit. Keep draining threads alive while the owned child lives.
        if process is not None:
            code = process.wait()
            return code if code >= 0 else 128-code
        raise


def collect(mode):
    out = output_path(mode)
    path = out/'lifecycle.json'
    deadline = time.monotonic()+10
    value = {}
    while True:
        if path.exists() and not path.is_symlink() and path.stat().st_size <= 32768:
            value = json.loads(path.read_text())
            if value.get('state') == 'exited': break
        if time.monotonic() >= deadline: break
        time.sleep(.2)
    paths = value.get('reportedCrashDbPaths', [])
    retain_crash_db(paths if isinstance(paths, list) else [], out)
    atomic_json(out/'collection.json', {'schema':1, 'observedState':value.get('state', 'no-observer-manifest'),
        'observerFinished':value.get('state') == 'exited', 'drainsComplete':value.get('drainsComplete') is True,
        'scope':'At most10s read-only wait after Action teardown; no repairs, signals or inferred exit cause.'})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    for operation in ('install', 'collect'):
        sub.add_parser(operation).add_argument('--mode', choices=MODES, required=True)
    launch_parser = sub.add_parser('launch')
    launch_parser.add_argument('config')
    launch_parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.operation == 'launch':
        return launch(args.config, args.arguments)
    globals()[args.operation](args.mode)
    return 0


if __name__ == '__main__':
    sys.exit(main())
