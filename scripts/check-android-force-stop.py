#!/usr/bin/env python3
"""Force-stop ONLY this workflow's installed app on its disposable emulator."""
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
        raise RuntimeError(f'adb command failed: {args[0]}: {result.stderr[-500:]}')
    return result


def app_report(token):
    result = adb('exec-out', 'run-as', PACKAGE, 'cat',
                 f'cache/qa-force-stop-{token}.json', required=False)
    if result.returncode:
        return None
    try:
        report = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None  # Reading a ready marker must tolerate its initial write.
    return report if report.get('token') == token else None


def command(token, phase):
    return ['flutter', 'test', 'integration_test/force_stop_recovery_test.dart',
            '--no-uninstall', '-d', DEVICE, '--timeout', '10m',
            f'--dart-define=FORCE_STOP_TOKEN={token}',
            f'--dart-define=FORCE_STOP_PHASE={phase}']


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('This diagnostic runs only on the disposable GitHub Actions runner.')
    if adb('shell', 'getprop', 'ro.kernel.qemu').stdout.strip() != '1':
        raise RuntimeError('Refusing to operate anything except emulator-5554 with qemu identity.')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    first = None
    stopped = False
    try:
        with (OUTPUT / 'force-stop-prepare.log').open('w') as log:
            first = subprocess.Popen(command(token, 'prepare'), stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 300
            while True:
                if first.poll() is not None:
                    raise RuntimeError('Preparation exited before the host observed a live ready marker; see force-stop-prepare.log.')
                before = app_report(token)
                if before and before.get('phase') == 'ready':
                    break
                if time.monotonic() > deadline:
                    raise TimeoutError('Android force-stop preparation did not become ready in five minutes.')
                time.sleep(.1)
            old_pid = str(before['pid'])
            if old_pid not in adb('shell', 'pidof', PACKAGE).stdout.split():
                raise RuntimeError('Ready marker PID does not belong to the live diagnostic application.')
            files_before = adb('exec-out', 'run-as', PACKAGE, 'ls',
                               f'app_flutter/qa-force-stop-{token}/restart-drawing').stdout.splitlines()
            adb('shell', 'am', 'force-stop', PACKAGE)
            deadline = time.monotonic() + 15
            while adb('shell', 'pidof', PACKAGE, required=False).stdout.strip():
                if time.monotonic() > deadline:
                    raise TimeoutError('Target application did not stop.')
                time.sleep(.1)
            stopped = True
            first_exit = first.wait(timeout=90)
            if first_exit == 0:
                raise RuntimeError('Interrupted preparation unexpectedly reported success; no restart pass is claimed.')
        with (OUTPUT / 'force-stop-resume.log').open('w') as log:
            result = subprocess.run(command(token, 'resume'), stdout=log, stderr=subprocess.STDOUT,
                                    timeout=360, check=False)
        if result.returncode:
            raise RuntimeError('Reopen/retry test failed; see force-stop-resume.log.')
        after = app_report(token)
        if not after or after.get('phase') != 'verified' or str(after.get('resumedPid')) == old_pid:
            raise RuntimeError('Missing fresh-process verification report.')
        report = {
            **after, 'serial': DEVICE, 'qemuVerified': True,
            'hostObservedProcessStopped': stopped, 'interruptedRunnerExit': first_exit,
            'filesObservedBeforeStop': files_before,
            'observedTemporaryBeforeStop': any(name.endswith('.tmp') for name in files_before),
        }
        (OUTPUT / 'android-force-stop.json').write_text(json.dumps(report, indent=2) + '\n')
        print(f'Android force-stop: PID {old_pid} stopped; new PID {after["resumedPid"]}; complete revision {after["recoveredRevision"]} recovered; playback and exact save/reopen retry passed.')
    finally:
        # Only this Popen handle is terminated if a bounded preparation fails.
        if first is not None and first.poll() is None:
            first.terminate()
            try:
                first.wait(timeout=10)
            except subprocess.TimeoutExpired:
                first.kill()
                first.wait(timeout=10)


if __name__ == '__main__':
    main()
