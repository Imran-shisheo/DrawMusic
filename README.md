# DrawMusic / ScribbleSong

An original Flutter drawing-to-music application. DrawMusic is the repository name; ScribbleSong is the PRD's provisional original brand. Android development runs in Codex Cloud. The owner will build and test iOS on a local Mac.

## Start here

- [Product requirements](PRD.md)
- [Research gallery](research/index.html) and [evidence guide](research/README.md)
- [Development roadmap](docs/ROADMAP.md) and [current status](docs/DEVELOPMENT-STATUS.md)
- [Android cloud setup](cloud/SETUP.md) and [first cloud task](cloud/FIRST-TASK.md)
- [Agent instructions](AGENTS.md)

## Current state

The merged creative expansion (PR #21, main a7c3670, 2.0.0+22) provides 13 original instruments, 12 keys/11 scales, accompaniment, 20 original templates, photo/camera/gradient backgrounds, PNG/MIDI/WAV/MP4, 12 locales and expressive/stylus/dark/tablet features. All creative tools remain free; no reference media ships.

**Current review fixes: 2.0.1+23**, branch `codex/review-fixes-2026-10-27`. Eraser point-cap rejection, background validation/framing, saved export thumbnails, iOS audio state/recovery, safe startup asset cleanup and HD 60 FPS coverage are tracked in the [review plan/evidence](docs/REVIEW-FIX-PLAN-2026-10-27.md) and [current status](docs/DEVELOPMENT-STATUS.md). New full product/native acceptance is pending until recorded there; the older green run is historical evidence only. See the [25-feature / 23-scenario matrix](docs/CREATIVE-REQUIREMENT-MATRIX.md).

Native iOS source is included; Apple-framework compilation/signing/runtime remains unverified. Follow the [Mac commands](docs/IOS-IMPLEMENTATION.md). Physical audio/routes/sharing/camera/TalkBack/stylus/release performance/storage and human translation review remain separate acceptance. Ads/rewards, billing, accounts, uploads, paid/hosted services and cloud collaboration are excluded. New review PRs must remain draft/unmerged.

## Android verification after bootstrap

```bash
source /workspace/drawmusic-tools/env.sh  # selected published cloud environment
bash /workspace/drawmusic-tools/configure-runtime.sh
source cloud/env.sh
bash scripts/check-android.sh
```

Historical baseline only: [accepted 2.0.0+22 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034/artifacts/12654848499) and [runtime reports/exports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034/artifacts/12657186456). Download while signed into GitHub, unzip and install app-debug.apk. This is historical development-build evidence for the merged expansion, not validation of 2.0.1+23. Current-source artifacts will be linked from the review PR/status after checks run.

The product script also runs the [Linux process-recovery probe](docs/PROCESS-RECOVERY.md). Hosted runtime evidence includes the [Android force-stop and ten-minute soak reports](docs/ANDROID-CLOUD-RECOVERY.md). [Compact layout coverage](docs/COMPACT-LAYOUT.md) describes the new accessibility scenarios. [Display-style policy](docs/DISPLAY-STYLES.md) and [Localization coverage](docs/LOCALIZATION.md) document the current behavior.

## iOS on your Mac

Pull `codex/review-fixes-2026-10-27` and use Flutter 3.47.2. The reviewed iOS project and native ports are already present; do not regenerate them with `flutter create`. Run `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build ios --simulator --debug`, then follow the [exact Xcode/signing/native-test and file-inspection commands](docs/IOS-IMPLEMENTATION.md). Configure development signing locally for a physical iPhone/iPad. Linux checks validate portable Dart and channel contracts only; Swift compilation, AVFoundation output and all iOS runtime behavior remain unverified.

## Research and asset ownership

Reference images and audio document source-app behavior. They must never be bundled in the product. This cloud starter includes 16 representative screenshots and source exports; the complete research remains in the original Mac checkout. See [cloud reference scope](docs/CLOUD-REFERENCE-SCOPE.md). The full local research includes private device captures; Git intentionally excludes camera-photo/cropper images, recipient suggestions, raw device dumps and invalid runs. Some provenance references are therefore local-only; see [publication scope](docs/RESEARCH-PUBLICATION.md). Use original or explicitly licensed shipping artwork, icons, templates and sounds with a provenance manifest.

No backend or account is required for the P0 creative workflow. Ads, purchases, accounts and hosted collaboration are excluded from this task. All creative tools are free. Physical audio latency/platform integration and native iOS compilation require their separately documented device/Mac validation.

## Runtime verification

The Android workflow runs JVM scheduler tests and an API 35 emulator in addition to Flutter tests/build. Native tests exercise AudioTrack and MediaCodec. The Flutter integration test runs the actual create/play/tempo/save/reopen/MIDI/WAV/MP4 UI flow with emulator Wi-Fi/mobile data disabled. FFprobe/FFmpeg inspect dimensions, FPS, real decoded audio, A/V duration and cursor timing; mido checks the UI-exported MIDI. Runtime evidence is uploaded separately from the normal debug APK. Physical speaker/Bluetooth latency and real receiving-app sharing still need device checks.
