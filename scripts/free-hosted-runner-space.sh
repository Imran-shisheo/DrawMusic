#!/usr/bin/env bash
# Remove unrelated preinstalled toolchains only on a disposable hosted CI VM.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted ]]; then
  echo 'Space cleanup is disabled outside disposable GitHub-hosted runners.'
  exit 0
fi
source cloud/toolchain.env
df -h /
if [[ "${DRAWMUSIC_EMULATOR_TRACE_DIAGNOSTIC:-0}" == 1 ]]; then
  # The already installed matching host debugger is required for this one diagnostic.
  sudo rm -rf /usr/share/dotnet /usr/local/lib/ghc /opt/ghc /usr/local/share/boost
else
  sudo rm -rf /usr/share/dotnet /usr/share/swift /usr/local/lib/ghc /opt/ghc /usr/local/share/boost
fi
if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/ndk" ]]; then
  for drawmusic_ndk in "$ANDROID_HOME"/ndk/*; do
    [[ -d "$drawmusic_ndk" ]] || continue
    drawmusic_ndk_version="$(basename "$drawmusic_ndk")"
    if [[ "$drawmusic_ndk_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$drawmusic_ndk_version" != "$DRAWMUSIC_ANDROID_NDK" ]]; then
      sudo rm -rf -- "$drawmusic_ndk"
    fi
  done
fi
df -h /
