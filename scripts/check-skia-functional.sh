#!/usr/bin/env bash
set -euo pipefail
source cloud/env.sh
export DASH__SUPPRESS_ANALYTICS=true
python3 scripts/prepare-offline-emulator.py
functional_result=0
python3 scripts/run-skia-functional-diagnostic.py || functional_result=$?
# Preserve partial files on failure; unchanged validators reject absent exports.
for diagnostic_artifact in ui-export-video.mp4 ui-export-audio.wav ui-export-notes.mid ui-project.json ui-export-metadata.json ui-export-image.png expanded-project.json expanded-video.mp4 expanded-audio.wav expanded-notes.mid expanded-image.png qa-hd-background.json; do
  timeout 30s adb -s emulator-5554 exec-out run-as com.devwithdelta.doodimo cat "cache/$diagnostic_artifact" > "work/runtime-output/$diagnostic_artifact" || true
done
python3 scripts/runtime_transport_diagnostics.py || true
exit "$functional_result"
