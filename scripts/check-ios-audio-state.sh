#!/usr/bin/env bash
set -euo pipefail
# Portable Swift scheduling proof only: this is NOT an iOS application build.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
if [[ -n "${DRAWMUSIC_SWIFT_TOOLCHAIN:-}" ]]; then
  swift_binary="$DRAWMUSIC_SWIFT_TOOLCHAIN/usr/bin/swift"
  swift_compiler="$DRAWMUSIC_SWIFT_TOOLCHAIN/usr/bin/swiftc"
else
  swift_binary="$(command -v swift || true)"
  swift_compiler="$(command -v swiftc || true)"
fi
if [[ ! -x "$swift_binary" || ! -x "$swift_compiler" ]]; then
  printf '%s\n' 'Swift and swiftc are required. Set PATH or DRAWMUSIC_SWIFT_TOOLCHAIN to a toolchain root. No test pass is claimed.' >&2
  exit 2
fi
state_root="$repo_root/work/ios-audio-state"
mkdir -p "$state_root" "$state_root/cache" "$state_root/config" "$state_root/security" "$state_root/module-cache"
# Keep HOME unchanged; explicit caches also work in a read-only cloud HOME.
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$state_root/module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$state_root/module-cache}"
"$swift_binary" --version | tee "$state_root/compiler.log"
"$swift_binary" test --package-path ios --scratch-path "$state_root/build" \
  --cache-path "$state_root/cache" --config-path "$state_root/config" \
  --security-path "$state_root/security" 2>&1 | tee "$state_root/tests.log"
"$swift_compiler" -frontend -parse ios/AudioState/*.swift ios/Runner/*.swift \
  ios/AudioStateTests/*.swift ios/RunnerTests/*.swift 2>&1 | tee "$state_root/grammar.log"
printf '%s\n' 'Portable Swift scheduling tests passed; native source grammar parsed. AVFoundation/UIKit typechecking, iOS app compilation and native runtime were NOT executed.'
