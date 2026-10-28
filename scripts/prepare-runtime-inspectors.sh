#!/usr/bin/env bash
set -euo pipefail
# Disposable hosted runner only; these are inspection tools, never APK assets.
if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
  echo 'Run inspector preparation only on the disposable GitHub runner.' >&2
  exit 2
fi
inspector_video_only=false
if [[ $# -gt 0 ]]; then
  if [[ $# -ne 1 || "$1" != --video-only ]]; then
    echo 'Usage: prepare-runtime-inspectors.sh [--video-only]' >&2
    exit 2
  fi
  inspector_video_only=true
fi
# Keep distribution signatures and TLS validation enabled. The previous run
# stalled downloading FFmpeg from azure.archive.ubuntu.com. Use Ubuntu's
# official HTTPS archive with the existing signed repository/keyring settings.
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
  for inspector_source in /etc/apt/apt-mirrors.txt /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; do
    if [[ -f "$inspector_source" ]]; then
      sudo sed -i 's|http://azure.archive.ubuntu.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' "$inspector_source"
    fi
  done
  timeout 180s sudo apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 update -qq
  timeout 180s sudo apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 install -y --no-install-recommends ffmpeg
fi
# Fail before the long emulator soak if a package service is unavailable.
mkdir -p work/validation-deps
if [[ "$inspector_video_only" != true ]]; then
  timeout 180s python3 -m pip install --disable-pip-version-check --no-cache-dir --timeout 30 --retries 1 --target work/validation-deps numpy==2.2.6 mido==1.3.3
fi
ffmpeg -version > work/validation-deps/ffmpeg-version.txt
ffprobe -version > work/validation-deps/ffprobe-version.txt
sed -n '1p' work/validation-deps/ffmpeg-version.txt work/validation-deps/ffprobe-version.txt
