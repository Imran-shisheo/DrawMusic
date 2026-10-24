#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'This installer targets Linux x86_64 cloud workers. It does not modify macOS.' >&2
  exit 2
fi
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=cloud/env.sh
source "$repo_root/cloud/env.sh"
if ! command -v javac >/dev/null || ! command -v unzip >/dev/null || ! command -v xz >/dev/null; then
  if [[ "$(id -u)" == 0 ]]; then
    apt-get update
    apt-get install -y ca-certificates curl git unzip zip xz-utils openjdk-17-jdk-headless libglu1-mesa libfontconfig1
  elif command -v sudo >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl git unzip zip xz-utils openjdk-17-jdk-headless libglu1-mesa libfontconfig1
  else
    echo 'Install JDK 17, curl, git, unzip, zip, xz, libGLU and fontconfig in the environment, then retry.' >&2
    exit 2
  fi
  source "$repo_root/cloud/env.sh"
fi
mkdir -p "$DRAWMUSIC_TOOLS_DIR" "$ANDROID_HOME/cmdline-tools"
if [[ ! -d "$FLUTTER_ROOT/.git" ]]; then
  if [[ -e "$FLUTTER_ROOT" ]]; then
    echo "Unexpected existing Flutter directory at $FLUTTER_ROOT; inspect it before continuing." >&2
    exit 2
  fi
  git clone --depth 1 --branch "$DRAWMUSIC_FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
if [[ "$(git -C "$FLUTTER_ROOT" rev-parse HEAD)" != "$DRAWMUSIC_FLUTTER_REVISION" ]]; then
  echo 'Flutter revision does not match cloud/toolchain.env. Resolve the mismatch explicitly.' >&2
  exit 2
fi
flutter config --no-analytics --enable-android --no-enable-linux-desktop
flutter precache --android
if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  work_dir="$(mktemp -d)"
  trap 'rm -rf "$work_dir"' EXIT
  curl --fail --location --retry 3 "https://dl.google.com/android/repository/$DRAWMUSIC_ANDROID_TOOLS_ARCHIVE" -o "$work_dir/tools.zip"
  printf '%s  %s\n' "$DRAWMUSIC_ANDROID_TOOLS_SHA1" "$work_dir/tools.zip" | sha1sum --check --status
  unzip -q "$work_dir/tools.zip" -d "$work_dir/unpacked"
  if [[ -e "$ANDROID_HOME/cmdline-tools/latest" ]]; then
    echo 'Existing incomplete cmdline-tools/latest; inspect rather than overwrite it.' >&2
    exit 2
  fi
  mv "$work_dir/unpacked/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
# Leave acceptance to an explicit owner decision. Hosted CI images normally already
# include accepted SDK licenses. Set this flag only after the owner authorizes it.
if [[ "${DRAWMUSIC_ACCEPT_ANDROID_LICENSES:-0}" == 1 ]]; then
  set +o pipefail
  yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
  license_status=${PIPESTATUS[1]}
  set -o pipefail
  if [[ "$license_status" != 0 ]]; then exit "$license_status"; fi
fi
if ! sdkmanager --sdk_root="$ANDROID_HOME" \
  'platform-tools' "platforms;android-$DRAWMUSIC_ANDROID_PLATFORM" \
  "build-tools;$DRAWMUSIC_ANDROID_BUILD_TOOLS" "ndk;$DRAWMUSIC_ANDROID_NDK" </dev/null; then
  echo 'SDK preparation failed. If licenses are missing, ask the owner to approve Android SDK terms, then retry with DRAWMUSIC_ACCEPT_ANDROID_LICENSES=1.' >&2
  exit 2
fi
flutter config --android-sdk "$ANDROID_HOME"
flutter --version
flutter doctor -v
if [[ -f "$repo_root/pubspec.yaml" ]]; then
  cd "$repo_root"
  flutter pub get
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n%s\n%s\n' "$FLUTTER_ROOT/bin" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin" >> "$GITHUB_PATH"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'ANDROID_HOME=%s\nANDROID_SDK_ROOT=%s\nFLUTTER_ROOT=%s\n' "$ANDROID_HOME" "$ANDROID_HOME" "$FLUTTER_ROOT" >> "$GITHUB_ENV"
fi
