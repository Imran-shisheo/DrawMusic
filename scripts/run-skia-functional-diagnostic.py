#!/usr/bin/env python3
"""One explicitly ineligible Skia comparison of the unchanged real UI gate."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess

PRODUCT = '2ffc61665159d38240c7a869811c4580d82a8fc0'
DRIVER = Path('scripts/run-android-ui.py')
DRIVER_SHA = '77c60728d150377d45a6dc04348b332823fbd7ddfefe748c63d8a59e079a74e2'
ORIGINAL_COMMAND = ['flutter', 'test', 'integration_test/creation_loop_test.dart',
                    '--no-uninstall', '-d', 'emulator-5554', '--timeout', '10m']


class DiagnosticSubprocess:
    def __getattr__(self, name):
        return getattr(subprocess, name)

    def Popen(self, command, *args, **kwargs):
        if command != ORIGINAL_COMMAND:
            raise ValueError('Only the exact unchanged product UI command may receive the diagnostic flag')
        return subprocess.Popen([*command, '--no-enable-impeller'], *args, **kwargs)


def validate(provenance):
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('DRAWMUSIC_SKIA_FUNCTIONAL_DIAGNOSTIC') != '1':
        raise RuntimeError('Only the explicitly requested owned Actions diagnostic may run')
    if (provenance.get('productSourceSha') != PRODUCT or provenance.get('diagnosticOnly') != 'skia-functional'
            or provenance.get('acceptanceEligible') is not False or provenance.get('rendererOverride') != 'skia-diagnostic-only'):
        raise ValueError('Exact unaccepted Skia functional provenance required')
    if hashlib.sha256(DRIVER.read_bytes()).hexdigest() != DRIVER_SHA:
        raise ValueError('Original UI driver changed; refusing implicit assertion/timing changes')


def main():
    output = Path('work/runtime-output')
    provenance = json.loads((output / 'source-provenance.json').read_text())
    validate(provenance)
    report = {'passed': False, 'acceptanceEligible': False, 'diagnosticOnly': True,
              'rendererOverride': 'skia-diagnostic-only', 'rendererRuntimeFlag': '--no-enable-impeller', 'productSourceSha': PRODUCT,
              'originalUiDriverSha256': DRIVER_SHA, 'functionalSequenceCompleted': False,
              'nativeCasesAndSoakRerun': False, 'forceStopRerun': False,
              'scope': 'Original real creation/save/reopen/four-export/HOME assertions with one runtime renderer override; not normal product, native-proof, performance, physical or iOS acceptance.'}
    try:
        spec = importlib.util.spec_from_file_location('original_owned_ui_driver', DRIVER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        # Substitute only this module's process facade. ADB commands, deadlines,
        # foreground/PID checks, test assertions and cleanup remain original.
        module.subprocess = DiagnosticSubprocess()
        module.main()
        report['functionalSequenceCompleted'] = True
    except Exception as error:
        report['errorType'] = type(error).__name__
        raise
    finally:
        report['originalUiDriverUnchanged'] = hashlib.sha256(DRIVER.read_bytes()).hexdigest() == DRIVER_SHA
        (output / 'skia-functional-diagnostic.json').write_text(json.dumps(report, indent=2) + '\n')
        print('SKIA_FUNCTIONAL_DIAGNOSTIC ' + json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
