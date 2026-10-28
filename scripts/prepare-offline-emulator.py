#!/usr/bin/env python3
"""Wait for real API35 system services, then require offline configuration.

sys.boot_completed can precede telephony availability. A successful property
alone is not readiness, and a missing service must never skip the offline gate.
"""
import json
import os
from pathlib import Path
import subprocess
import time

DEVICE = 'emulator-5554'


def adb(*args):
    return subprocess.run(['adb', '-s', DEVICE, *args], capture_output=True,
                          text=True, timeout=10, check=False)


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Offline preparation is restricted to the disposable GitHub Actions emulator.')
    output = Path('work/runtime-output/emulator-readiness.json')
    output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    deadline = started + 180
    report = {'passed': False, 'serial': DEVICE, 'services': {},
              'scope': 'Disposable API35 QEMU readiness and required Wi-Fi/mobile-data disable; not a product test pass.'}
    try:
        while time.monotonic() < deadline:
            try:
                qemu = adb('shell', 'getprop', 'ro.kernel.qemu')
                if qemu.returncode == 0 and qemu.stdout.strip() not in ('', '1'):
                    raise RuntimeError('QEMU identity rejected; refusing network changes.')
                boot = adb('shell', 'getprop', 'sys.boot_completed')
                if qemu.stdout.strip() != '1' or boot.returncode or boot.stdout.strip() != '1':
                    time.sleep(2)
                    continue
                ready = True
                for service in ('package', 'activity', 'wifi', 'phone', 'connectivity'):
                    state = adb('shell', 'service', 'check', service)
                    report['services'][service] = (state.stdout + state.stderr).strip()
                    ready = ready and state.returncode == 0 and state.stdout.strip().endswith(': found')
                if ready:
                    wifi = adb('shell', 'svc', 'wifi', 'disable')
                    data = adb('shell', 'svc', 'data', 'disable')
                    if wifi.returncode == 0 and data.returncode == 0:
                        report.update(passed=True, qemuVerified=True,
                                      wifiDisabled=True, mobileDataDisabled=True)
                        print('Emulator services ready; required Wi-Fi and mobile-data disable succeeded.', flush=True)
                        return
                    report['lastDisableError'] = (wifi.stderr + data.stderr).strip()
            except subprocess.TimeoutExpired:
                report['lastDisableError'] = 'ADB command exceeded its ten-second bound.'
            time.sleep(2)
        raise TimeoutError(f'Emulator services/offline configuration not ready within 180 seconds: {report["services"]}')
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        report['elapsedMs'] = round((time.monotonic() - started) * 1000)
        output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
