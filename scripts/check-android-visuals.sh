#!/usr/bin/env bash
set -euo pipefail
source cloud/env.sh
export DASH__SUPPRESS_ANALYTICS=true
capture_diagnostic=$(python3 - <<'PYMODE'
import json
from pathlib import Path
mode = json.loads(Path('work/ui-capture/source-provenance.json').read_text()).get('diagnosticOnly')
if mode not in (None, 'static-backdrop', 'emulator-fault-stack'):
    raise ValueError('Unknown capture diagnostic mode')
print(mode or 'normal')
PYMODE
)
if [[ "$capture_diagnostic" == static-backdrop ]]; then
  dart format --output=none --set-exit-if-changed integration_test/support/ui_static_backdrop_probe.dart test/ui_static_backdrop_probe_test.dart
  flutter analyze --no-pub integration_test/support/ui_static_backdrop_probe.dart test/ui_static_backdrop_probe_test.dart
  flutter test --no-pub test/ui_static_backdrop_probe_test.dart test/ui_frame_clock_test.dart test/ui_presentation_fence_test.dart
fi
python3 scripts/prepare-offline-emulator.py
python3 scripts/capture-android-ui.py
