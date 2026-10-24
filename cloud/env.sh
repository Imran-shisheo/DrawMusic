#!/usr/bin/env bash
# Source before cloud commands. This file does not install anything.
drawmusic_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=cloud/toolchain.env
source "$drawmusic_repo_root/cloud/toolchain.env"
export DRAWMUSIC_TOOLS_DIR="${DRAWMUSIC_TOOLS_DIR:-$HOME/.cache/drawmusic-tools}"
export FLUTTER_ROOT="$DRAWMUSIC_TOOLS_DIR/flutter"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$DRAWMUSIC_TOOLS_DIR/android-sdk}}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$FLUTTER_ROOT/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
if [[ -d /usr/lib/jvm/java-17-openjdk-amd64 ]]; then
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  export PATH="$JAVA_HOME/bin:$PATH"
fi
