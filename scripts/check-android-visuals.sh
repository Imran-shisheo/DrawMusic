#!/usr/bin/env bash
set -euo pipefail
source cloud/env.sh
export DASH__SUPPRESS_ANALYTICS=true
python3 scripts/test-ui-capture-host.py
python3 scripts/prepare-offline-emulator.py
python3 scripts/capture-android-ui.py
