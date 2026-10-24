#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
if [[ ! -f pubspec.yaml ]]; then
  echo 'Flutter application has not been bootstrapped. No APK or app-test pass is claimed.' >&2
  exit 2
fi
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
printf 'Android test APK: %s/build/app/outputs/flutter-apk/app-debug.apk\n' "$repo_root"
