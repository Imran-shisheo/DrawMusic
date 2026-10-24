# DrawMusic / ScribbleSong

An original Flutter drawing-to-music application. DrawMusic is the repository name; ScribbleSong is the PRD's provisional original brand. Android development runs in Codex Cloud. The owner will build and test iOS on a local Mac.

## Start here

- [Product requirements](PRD.md)
- [Research gallery](research/index.html) and [evidence guide](research/README.md)
- [Development roadmap](docs/ROADMAP.md) and [current status](docs/DEVELOPMENT-STATUS.md)
- [Android cloud setup](cloud/SETUP.md) and [first cloud task](cloud/FIRST-TASK.md)
- [Agent instructions](AGENTS.md)

## Current state

The Android development branch implements drawing, erasing, history, deterministic pentatonic scores, an actual Android audio adapter, local save/reopen and MIDI/WAV/MP4 exports with sharing. Live updates now queue on native beat/loop boundaries; Drafts supports rename, duplicate and delete with Undo. M0 product checks and APK compilation passed; see [current status](docs/DEVELOPMENT-STATUS.md) for later validation and gaps. P0 hardening is incomplete: persisted settings/tutorials, exported-library management, large-scene profiling and physical device acceptance remain. MP4 runtime validation is tracked in the draft PR.

## Android verification after bootstrap

```bash
source /workspace/drawmusic-tools/env.sh  # selected published cloud environment
bash /workspace/drawmusic-tools/configure-runtime.sh
source cloud/env.sh
bash scripts/check-android.sh
```

The original checkpoint APK has a playback initialization bug. Use the **1.2.1+5** creation-loop/export build linked in [development PR](https://github.com/Imran-shisheo/DrawMusic/pull/2), which also tracks remaining work. CI produces a debug APK under the workflow run's Artifacts section after successful checks. Download/unzip it and install app-debug.apk on your test phone. It is a development build, not a signed Play Store release.

## iOS on your Mac

Pull the development branch, use Flutter 3.47.2, run `flutter create --platforms=ios --org com.imranshisheo .`, review generated files, then `flutter pub get`. Open the Xcode workspace and configure signing locally. Dart models, score, synthesis, storage and MIDI/WAV are portable; the current audio/video MethodChannels require iOS adapters before playback and MP4 export work. See [cloud setup](cloud/SETUP.md). No iOS validation is claimed.

## Research and asset ownership

Reference images and audio document source-app behavior. They must never be bundled in the product. This cloud starter includes 16 representative screenshots and source exports; the complete research remains in the original Mac checkout. See [cloud reference scope](docs/CLOUD-REFERENCE-SCOPE.md). The full local research includes private device captures; Git intentionally excludes camera-photo/cropper images, recipient suggestions, raw device dumps and invalid runs. Some provenance references are therefore local-only; see [publication scope](docs/RESEARCH-PUBLICATION.md). Use original or explicitly licensed shipping artwork, icons, templates and sounds with a provenance manifest.

No backend or account is required for the P0 creative workflow. Ads and purchases are deferred until core reliability. App code stays portable for later iOS testing; physical audio latency and platform integration need real-device validation.

## Runtime verification

The Android workflow runs JVM scheduler tests and an API 35 emulator in addition to Flutter tests/build. Native tests exercise AudioTrack and MediaCodec. The Flutter integration test runs the actual create/play/tempo/save/reopen/MIDI/WAV/MP4 UI flow with emulator Wi-Fi/mobile data disabled. FFprobe/FFmpeg inspect dimensions, FPS, real decoded audio, A/V duration and cursor timing; mido checks the UI-exported MIDI. Runtime evidence is uploaded separately from the normal debug APK. Physical speaker/Bluetooth latency and real receiving-app sharing still need device checks.
