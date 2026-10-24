#!/usr/bin/env bash
set -euo pipefail
# Keep Dart tooling from writing analytics state outside the workspace.
export DASH__SUPPRESS_ANALYTICS=true
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
if [[ ! -f pubspec.yaml ]]; then
  echo 'Flutter application has not been bootstrapped. No APK or app-test pass is claimed.' >&2
  exit 2
fi
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
# Exercise native AudioTrack preparation contracts too; Flutter fakes cannot cover them.
(cd android && ./gradlew :app:testDebugUnitTest --console=plain)
# Linux cloud process-interruption proof uses only disposable owned children.
if [[ "$(uname -s)" == Linux ]]; then
  mkdir -p work/runtime-output
  dart compile exe tool/crash_recovery_probe.dart -o work/crash-recovery-probe
  work/crash-recovery-probe --report work/runtime-output/process-recovery.json
fi
printf 'Android test APK: %s/build/app/outputs/flutter-apk/app-debug.apk\n' "$repo_root"
