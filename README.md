# DrawMusic / ScribbleSong

An original Flutter drawing-to-music application. DrawMusic is the repository name; ScribbleSong is the PRD's provisional original brand. Android development runs in Codex Cloud. The owner will build and test iOS on a local Mac.

## Start here

- [Product requirements](PRD.md)
- [Research gallery](research/index.html) and [evidence guide](research/README.md)
- [Development roadmap](docs/ROADMAP.md) and [current status](docs/DEVELOPMENT-STATUS.md)
- [Android cloud setup](cloud/SETUP.md) and [first cloud task](cloud/FIRST-TASK.md)
- [Agent instructions](AGENTS.md)

## Current state

The active **2.0.0+22 creative expansion** builds on the accepted 1.11.7 creation loop. It adds thirteen original synthesized instruments, twelve root keys, eleven scales, clock-synchronized accompaniment/mixing, custom/gradient/photo/camera backgrounds with crop transforms, twenty original editable templates and genuine PNG export. MIDI/WAV/MP4 include the expanded immutable musical snapshot; video offers 30/60 FPS.

P0 hardening adds score-preserving undoable simplification, shared-ownership history memory accounting, unknown-ID fallbacks preserving metadata, actual v1 compatibility fixtures and lossless raw recovery exports. Twelve languages, localized help/errors, opt-in native rating, explicit expressive dynamics, stylus metadata, dark theme, compact layouts and a wide tablet workspace are implemented. All creative tools remain free.

The local product gate passes formatting, analyzer, **169 Flutter tests, 20 JVM tests, Android lint, APK build/v2 signature and twelve Linux interruption/recovery/retry checks**. The seventeen native runtime tests compile; real emulator execution, offline expanded UI/exports, independent file inspection, ten-minute soak and process recovery are tracked with exact source/run links in [current status](docs/DEVELOPMENT-STATUS.md). Historical results below do not validate new changes. See the [25-feature / 23-scenario requirement matrix](docs/CREATIVE-REQUIREMENT-MATRIX.md) and [implementation plan](docs/CREATIVE-IMPLEMENTATION-PLAN.md).

Real iOS audio/video/file/photo source ports and scaffolding are included; **Swift compilation and iOS runtime are unverified** until a Mac run. Follow [exact Mac/signing/test commands](docs/IOS-IMPLEMENTATION.md). Physical Android audio/routes/sharing/camera/TalkBack/release FPS/memory/storage acceptance, human translation review and owner store/branding configuration remain open. Assets are retained conservatively without destructive orphan garbage collection; storage growth remains a documented limitation. Ads, billing, accounts, uploads, hosted services and cloud collaboration are excluded. This work stays in an unmerged draft PR.

## Android verification after bootstrap

```bash
source /workspace/drawmusic-tools/env.sh  # selected published cloud environment
bash /workspace/drawmusic-tools/configure-runtime.sh
source cloud/env.sh
bash scripts/check-android.sh
```

Historical baseline only: use the [verified 1.11.7+21 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40172814635/artifacts/12591545602) and [runtime exports/reports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40172814635/artifacts/12591238935), retained until 1 November 2026. Download while signed into GitHub, unzip and install app-debug.apk. This is a development build. A build artifact alone does not establish runtime acceptance; the linked source run passed the complete gate.

The product script also runs the [Linux process-recovery probe](docs/PROCESS-RECOVERY.md). Hosted runtime evidence includes the [Android force-stop and ten-minute soak reports](docs/ANDROID-CLOUD-RECOVERY.md). [Compact layout coverage](docs/COMPACT-LAYOUT.md) describes the new accessibility scenarios. [Display-style policy](docs/DISPLAY-STYLES.md) and [English localization scope](docs/LOCALIZATION.md) document the current behavior.

## iOS on your Mac

Pull the development branch, use Flutter 3.47.2, run `flutter create --platforms=ios --org com.imranshisheo .`, review generated files, then `flutter pub get`. Open the Xcode workspace and configure signing locally. Dart models, score, synthesis, storage and MIDI/WAV are portable; the current audio/video/file-action MethodChannels require iOS adapters before playback, MP4 export and native Open/Save work. See [cloud setup](cloud/SETUP.md). No iOS validation is claimed.

## Research and asset ownership

Reference images and audio document source-app behavior. They must never be bundled in the product. This cloud starter includes 16 representative screenshots and source exports; the complete research remains in the original Mac checkout. See [cloud reference scope](docs/CLOUD-REFERENCE-SCOPE.md). The full local research includes private device captures; Git intentionally excludes camera-photo/cropper images, recipient suggestions, raw device dumps and invalid runs. Some provenance references are therefore local-only; see [publication scope](docs/RESEARCH-PUBLICATION.md). Use original or explicitly licensed shipping artwork, icons, templates and sounds with a provenance manifest.

No backend or account is required for the P0 creative workflow. Ads and purchases are deferred until core reliability. App code stays portable for later iOS testing; physical audio latency and platform integration need real-device validation.

## Runtime verification

The Android workflow runs JVM scheduler tests and an API 35 emulator in addition to Flutter tests/build. Native tests exercise AudioTrack and MediaCodec. The Flutter integration test runs the actual create/play/tempo/save/reopen/MIDI/WAV/MP4 UI flow with emulator Wi-Fi/mobile data disabled. FFprobe/FFmpeg inspect dimensions, FPS, real decoded audio, A/V duration and cursor timing; mido checks the UI-exported MIDI. Runtime evidence is uploaded separately from the normal debug APK. Physical speaker/Bluetooth latency and real receiving-app sharing still need device checks.
