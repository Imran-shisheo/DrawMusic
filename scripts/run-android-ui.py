#!/usr/bin/env python3
"""Run the product UI test and background only its disposable Android emulator.

The Dart test marks an actual HD60 encoding job ready. HOME then foreground
delivery exercises the real OS -> Flutter lifecycle -> native cancellation path.
No test adapter replaces the encoder, and a missing handshake fails this gate.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import time

from runtime_transport_diagnostics import safe_snapshot

PACKAGE = 'com.devwithdelta.doodimo'
DEVICE = 'emulator-5554'
OUTPUT = Path('work/runtime-output')


def adb(*args, required=True):
    result = subprocess.run(['adb', '-s', DEVICE, *args], capture_output=True,
                            text=True, timeout=30, check=False)
    if required and result.returncode:
        raise RuntimeError(f'Emulator {args[0]} failed: {result.stderr[-400:]}')
    return result


def foreground_activity():
    result = adb('shell', 'dumpsys', 'activity', 'activities').stdout
    lines = [line.strip() for line in result.splitlines()
             if 'mResumedActivity:' in line or 'topResumedActivity=' in line]
    # A null/transition entry is not proof of another resumed activity.
    components = [component for line in lines for component in re.findall(
        r'ActivityRecord\{[^}]*?\s([A-Za-z0-9_.]+/[A-Za-z0-9_.$]+)', line)]
    return '\n'.join(components)


def is_app_foreground(activities):
    return any(component.split('/', 1)[0] == PACKAGE
               for component in activities.splitlines())


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('This driver is restricted to the disposable GitHub Actions emulator.')
    if adb('shell', 'getprop', 'ro.kernel.qemu').stdout.strip() != '1':
        raise RuntimeError('QEMU identity check failed; refusing device operation.')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    safe_snapshot('before', verified_qemu=True)
    if adb('shell', 'pm', 'path', PACKAGE, required=False).stdout.strip():
        adb('shell', 'run-as', PACKAGE, 'rm', '-f', 'cache/qa-hd-background.json')
    process = None
    report = {'passed': False, 'scope': 'Actual API35 emulator HOME/foreground during HD60 encoding; not physical-device acceptance.'}
    handled = False
    deadline = time.monotonic() + 720
    try:
        process = subprocess.Popen(['flutter', 'test', 'integration_test/creation_loop_test.dart',
                                '--no-uninstall', '-d', DEVICE, '--timeout', '10m'])
        while process.poll() is None:
            if time.monotonic() > deadline:
                raise TimeoutError('Android UI driver exceeded its bounded deadline.')
            if not handled:
                raw = adb('exec-out', 'run-as', PACKAGE, 'cat',
                          'cache/qa-hd-background.json', required=False)
                try:
                    marker = json.loads(raw.stdout) if raw.returncode == 0 else {}
                except json.JSONDecodeError:
                    marker = {}
                if marker.get('phase') == 'ready':
                    before = foreground_activity()
                    if not is_app_foreground(before):
                        raise RuntimeError('HD export was not foreground before HOME.')
                    pid = adb('shell', 'pidof', PACKAGE).stdout.strip()
                    adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
                    background_deadline = time.monotonic() + 10
                    while True:
                        background = foreground_activity()
                        if background and not is_app_foreground(background):
                            break
                        if time.monotonic() > background_deadline:
                            raise TimeoutError('HOME did not background the export activity.')
                        time.sleep(.1)
                    # Keep the real app paused briefly, then return so the Flutter
                    # test can pump and assert cancellation and exact cleanup.
                    time.sleep(.5)
                    launch = adb('shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/.MainActivity')
                    if 'Status: ok' not in launch.stdout:
                        raise RuntimeError('Could not foreground the same test app.')
                    if adb('shell', 'pidof', PACKAGE).stdout.strip() != pid:
                        raise RuntimeError('Background cancellation unexpectedly restarted the app process.')
                    foreground_deadline = time.monotonic() + 10
                    while not is_app_foreground(foreground_activity()):
                        if time.monotonic() > foreground_deadline:
                            raise TimeoutError('The app never became the observed resumed activity.')
                        time.sleep(.1)
                    report.update(nonce=marker.get('nonce'), samePid=pid,
                                  beforeActivity=before, backgroundActivity=background,
                                  hostObservedBackground=True, hostRestoredForeground=True)
                    handled = True
            time.sleep(.3)
        if process.returncode:
            raise RuntimeError(f'Product UI test failed with exit code {process.returncode}.')
        if not handled:
            raise RuntimeError('UI test never exercised the real HD60 background handshake.')
        final = adb('exec-out', 'run-as', PACKAGE, 'cat', 'cache/qa-hd-background.json')
        marker = json.loads(final.stdout)
        if marker.get('phase') != 'verified' or marker.get('nonce') != report['nonce']:
            raise RuntimeError('UI did not verify canceled HD60 cleanup after actual HOME.')
        report.update(passed=True, ui=marker)
        print('Real Android HD60 HOME/background cancellation and same-process foreground retry passed.', flush=True)
    except Exception as error:
        safe_snapshot('failure', verified_qemu=True)
        report['error'] = str(error)
        raise
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        (OUTPUT / 'hd-background-host.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
