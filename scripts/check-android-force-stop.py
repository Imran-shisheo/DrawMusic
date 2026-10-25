#!/usr/bin/env python3
"""Launch a real diagnostic APK and stop ONLY this workflow's emulator app."""
import json
import os
from pathlib import Path
import subprocess
import time
import uuid

PACKAGE = 'com.imranshisheo.scribblesong'
DEVICE = 'emulator-5554'
OUTPUT = Path('work/runtime-output')


def adb(*args, required=True, timeout=30):
    result = subprocess.run(['adb', '-s', DEVICE, *args], capture_output=True,
                            text=True, timeout=timeout, check=False)
    if required and result.returncode:
        raise RuntimeError(f'adb {args[0]} failed: {result.stderr[-500:]}')
    return result


def app_report(token):
    result = adb('exec-out', 'run-as', PACKAGE, 'cat',
                 f'cache/qa-force-stop-{token}.json', required=False)
    if result.returncode:
        return None
    try:
        report = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return report if report.get('token') == token else None


def launch(token, phase):
    log_path = OUTPUT / f'force-stop-{phase}.log'
    command = ['flutter', 'build', 'apk', '--debug', '--target-platform=android-x64',
               '--target=tool/android_recovery_probe.dart',
               f'--dart-define=FORCE_STOP_TOKEN={token}',
               f'--dart-define=FORCE_STOP_PHASE={phase}']
    with log_path.open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                timeout=300, check=False)
    if result.returncode:
        raise RuntimeError(f'{phase} diagnostic APK build failed; see {log_path.name}.')
    adb('shell', 'am', 'force-stop', PACKAGE)
    installed = adb('install', '-r', '-t', 'build/app/outputs/flutter-apk/app-debug.apk', timeout=90)
    if 'Success' not in installed.stdout:
        raise RuntimeError(f'{phase} diagnostic APK did not install.')
    started = adb('shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/.MainActivity', timeout=60)
    with log_path.open('a') as log:
        log.write(installed.stdout + started.stdout)
    if 'Status: ok' not in started.stdout:
        raise RuntimeError(f'{phase} diagnostic activity did not start.')


def wait_report(token, expected_phase):
    # Build/install is separate: this deadline covers actual app readiness only.
    deadline = time.monotonic() + 90
    last = None
    while True:
        last = app_report(token) or last
        if last and last.get('phase') == 'failed':
            raise RuntimeError(f'Android diagnostic assertion failed: {last.get("error")}')
        if last and last.get('phase') == expected_phase:
            return last
        if time.monotonic() > deadline:
            raise TimeoutError(f'Android app did not report {expected_phase}; last phase: {None if last is None else last.get("phase")}')
        time.sleep(.1)


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('This diagnostic runs only on the disposable GitHub Actions runner.')
    if adb('shell', 'getprop', 'ro.kernel.qemu').stdout.strip() != '1':
        raise RuntimeError('Refusing to operate anything except emulator-5554 with QEMU identity.')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    try:
        launch(token, 'prepare')
        before = wait_report(token, 'ready')
        old_pid = str(before['pid'])
        if old_pid not in adb('shell', 'pidof', PACKAGE).stdout.split():
            raise RuntimeError('Ready PID does not belong to the live diagnostic app.')
        files_before = adb('exec-out', 'run-as', PACKAGE, 'ls',
                           f'app_flutter/qa-force-stop-{token}/restart-drawing').stdout.splitlines()
        adb('shell', 'am', 'force-stop', PACKAGE)
        deadline = time.monotonic() + 15
        while adb('shell', 'pidof', PACKAGE, required=False).stdout.strip():
            if time.monotonic() > deadline:
                raise TimeoutError('Target app did not stop.')
            time.sleep(.1)
        launch(token, 'resume')
        after = wait_report(token, 'verified')
        if str(after.get('resumedPid')) == old_pid:
            raise RuntimeError('Expected a new process after force-stop.')
        report = {
            **after, 'serial': DEVICE, 'qemuVerified': True,
            'hostObservedProcessStopped': True, 'filesObservedBeforeStop': files_before,
            'observedTemporaryBeforeStop': any(name.endswith('.tmp') for name in files_before),
        }
        (OUTPUT / 'android-force-stop.json').write_text(json.dumps(report, indent=2) + '\n')
        print(f'Android force-stop: PID {old_pid} stopped; new PID {after["resumedPid"]}; complete revision {after["recoveredRevision"]} recovered; playback and exact save/reopen retry passed.')
    except Exception as error:
        (OUTPUT / 'android-force-stop-error.json').write_text(json.dumps({'token': token, 'error': str(error)}, indent=2) + '\n')
        for phase in ['prepare', 'resume']:
            path = OUTPUT / f'force-stop-{phase}.log'
            if path.exists():
                print(f'Diagnostic log: {path.name}', flush=True)
                print('\n'.join(path.read_text(errors='replace').splitlines()[-100:]), flush=True)
        raise
    finally:
        # All Android logs are diagnostic; no filtering away startup/crash tags.
        logs = adb('logcat', '-d', '-v', 'threadtime', required=False)
        (OUTPUT / 'force-stop-android.log').write_text(logs.stdout)
        adb('shell', 'am', 'force-stop', PACKAGE, required=False)


if __name__ == '__main__':
    main()
