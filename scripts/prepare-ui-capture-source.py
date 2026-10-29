#!/usr/bin/env python3
"""Pin capture product source separately from the new diagnostic harness."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

FILES = ['integration_test/ui_visual_capture_test.dart', 'integration_test/support/ui_capture_metrics.dart',
         'integration_test/support/ui_frame_clock.dart', 'test/ui_frame_clock_test.dart',
         'integration_test/support/ui_presentation_fence.dart', 'test/ui_presentation_fence_test.dart',
         'integration_test/support/ui_static_backdrop_probe.dart', 'test/ui_static_backdrop_probe_test.dart',
         'test_driver/ui_visual_capture_driver.dart', 'scripts/capture-android-ui.py', 'scripts/check-android-visuals.sh',
         'scripts/test-ui-capture-host.py', 'scripts/prepare-runtime-inspectors.sh',
         'scripts/runtime_transport_diagnostics.py', 'scripts/test-runtime-transport-diagnostics.py',
         'scripts/observe-emulator-process.py', 'scripts/test-observe-emulator-process.py',
         'scripts/ui_capture_mp4.py', 'scripts/test-ui-capture-mp4.py',
         'scripts/emulator_lldb_trace.py', 'scripts/check-host-debugger-readiness.py',
         'scripts/test-host-debugger-readiness.py', 'scripts/trace-owned-emulator.py',
         'scripts/owned_pc_mapping.py', 'scripts/test-owned-pc-mapping.py',
         'scripts/check-execchain-debugger-readiness.py', 'scripts/test-execchain-debugger-readiness.py',
         'scripts/test-trace-owned-emulator.py', 'scripts/free-hosted-runner-space.sh',
         'scripts/prepare-ui-capture-source.py']

def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()

def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Refusing to change a developer checkout; this is a disposable Actions-only preparation')
    request_path = 'cloud/emulator-fault-trace-request.json' if os.environ.get('DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC') == '1' else 'cloud/ui-capture-request.json'
    request = json.loads(Path(request_path).read_text())
    source, label = request.get('sourceRef'), request.get('label')
    if request.get('schema') != 1 or not isinstance(source, str) or not re.fullmatch(r'[0-9a-f]{40}', source) or label not in ('before', 'after'):
        raise ValueError('Expected a full commit SHA and before/after label')
    diagnostic = request.get('diagnostic')
    if diagnostic not in (None, 'static-backdrop') or (diagnostic is not None and label != 'after'):
        raise ValueError('Unknown diagnostic request')
    responsive = request.get('responsivePreset')
    if responsive not in (None, 'compact', 'tablet', 'light') or (responsive is not None and (diagnostic is not None or label != 'after')):
        raise ValueError('Expected one exclusive compact/tablet/light responsive preset')
    home_only = request.get('homeProfileOnly', False)
    if type(home_only) is not bool or (home_only and (label != 'after' or diagnostic is not None or responsive is not None)):
        raise ValueError('Expected exclusive after-source boolean homeProfileOnly')
    transitions = request.get('transitionCaptureOnly', False)
    comparison = request.get('transitionComparison')
    if type(transitions) is not bool or (transitions and (label != 'after' or diagnostic is not None or responsive is not None or home_only or comparison not in ('before-fix', 'after-fix'))) or (not transitions and comparison is not None):
        raise ValueError('Expected exclusive transition capture with explicit before-fix/after-fix role')
    graphite = request.get('graphiteCapture', False)
    if type(graphite) is not bool or (graphite and (label != 'after' or diagnostic is not None or responsive is not None or home_only or transitions)):
        raise ValueError('Expected exclusive after-source graphiteCapture boolean')
    fault_trace = request.get('emulatorFaultTrace', False)
    if type(fault_trace) is not bool or (fault_trace and (not graphite or os.environ.get('DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC') != '1')):
        raise ValueError('Fault trace requires explicit diagnostic authorization and pinned Graphite source')
    fault_revision = request.get('faultTraceRevision')
    if fault_revision not in (None, 'owned-pc-map') or (fault_revision is not None and not fault_trace):
        raise ValueError('Only the explicitly requested owned-PC diagnostic revision is supported')
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a') as stream:
            stream.write('product_apk_required=' + str(not graphite and not transitions and not home_only and diagnostic is None and responsive in (None, 'light')).lower() + '\n')
    harness = git('rev-parse', 'HEAD')
    if git('cat-file', '-t', source) != 'commit':
        raise ValueError('Requested source is not an available repository commit')
    with tempfile.TemporaryDirectory(prefix='drawmusic-ui-harness-') as scratch:
        for item in FILES:
            target = Path(scratch) / item
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(item, target)
        git('checkout', '--detach', source)
        if git('rev-parse', 'HEAD') != source:
            raise RuntimeError('Pinned product checkout did not match request')
        tree = git('rev-parse', 'HEAD^{tree}')
        for item in FILES:
            target = Path(item)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(Path(scratch) / item, target)
    output = Path('work/ui-capture'); output.mkdir(parents=True, exist_ok=True)
    (output / 'source-provenance.json').write_text(json.dumps({
        'label': label, 'productSourceSha': source, 'productTreeSha': tree,
        'captureHarnessSourceSha': harness, 'instrumentationFiles': FILES,
        'diagnosticOnly': 'emulator-fault-stack' if fault_trace else diagnostic,
        'emulatorFaultTrace': fault_trace, 'faultTraceRevision': fault_revision, 'acceptanceEligible': not fault_trace,
        'responsivePreset': responsive,
        'homeProfileOnly': home_only,
        'transitionCaptureOnly': transitions, 'transitionComparison': comparison,
        'graphiteCapture': graphite,
        'scope': 'Actual pinned production widget/native source plus separately identified diagnostic target. Not a substitute for full functional acceptance.'
    }, indent=2) + '\n')
    print(f'Capture product source {source}; diagnostic harness {harness}; label {label}', flush=True)

if __name__ == '__main__':
    main()
