# Doodimo — DrawMusic repository

An original Flutter drawing-to-music application. Doodimo is the owner-selected display name; DrawMusic remains the repository name. The historical PRD uses the provisional ScribbleSong name, and the package ID remains com.imranshisheo.scribblesong. Android development runs in Codex Cloud. The owner will build and test iOS on a local Mac.

## Start here

- [Product requirements](PRD.md)
- [Research gallery](research/index.html) and [evidence guide](research/README.md)
- [Development roadmap](docs/ROADMAP.md), [current status](docs/DEVELOPMENT-STATUS.md) and [implemented-versus-verified delivery checkpoint](docs/DELIVERY-CHECKPOINT-2026-10-28.md)
- [Android cloud setup](cloud/SETUP.md) and [first cloud task](cloud/FIRST-TASK.md)
- [Agent instructions](AGENTS.md)

## Current state

Current follow-up: [draft PR24](https://github.com/Imran-shisheo/DrawMusic/pull/24), Library transition continuity and Home scroll churn. Library's fresh native gate passed; Home checkpoint `9f152e6` passes the full local gate and fresh [hosted native/media gate40662060004](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40662060004). [Accepted Home-fix APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40662060004/artifacts/12803953970). Physical profile acceptance remains pending. [Latest source/check mapping](docs/DEVELOPMENT-STATUS.md), [Home diagnostics](docs/HOME-SCROLL-PERFORMANCE.md), and [reviewed UI UX Pro Max / Mac Stitch handoff setup](docs/UI-UX-TOOLS.md). Earlier checkpoint details below retain their original source-specific scope. PR22/23 were merged externally; PR24 remains draft/unmerged.

**Doodimo immersive UI redesign in progress (2.1.0+24):** [historical stacked PR #23](https://github.com/Imran-shisheo/DrawMusic/pull/23), [actual native Home/editor/export](docs/ui/public-native-checkpoint/README.md), [320 dp at 200% text](docs/ui/public-native-checkpoint/compact/README.md), [actual tablet layouts](docs/ui/public-native-checkpoint/tablet/README.md), and [chosen-source cool-light pixels](docs/ui/public-native-checkpoint/light/README.md). Home, retained navigation, canvas/transport, libraries, export, background/crop, Settings and help share original ribbon branding, duotone icons and bundled fonts. PR22/23 were subsequently merged externally; use the current follow-up above.

The restored accepted app passes the complete local Android gate: 368 Flutter tests, analyzer/formatter, unchanged visual references, JVM/lint, normal APK/v2 signing and interrupted-save recovery. A cache-layer experiment was removed after its actual raster p95 remained183.802ms; the16.67ms target and presentation pacing remain unaccepted. No smoothness claim follows from a successful video decode. Compact and tablet subset captures passed; they are not a single full capture or physical-device acceptance. See the [implementation ledger](docs/UI-UX-REDESIGN.md) and [exact source/check status](docs/DEVELOPMENT-STATUS.md).

The [contrast-fix checkpoint APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40599305866/artifacts/12778736866) passed the complete hosted product/native gate40599305866, including independent real-file decoding and portable Swift checks. The unsuccessful static-lighting experiment was rolled back to this accepted application. [Final chosen-source normal APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40605481853/artifacts/12781655455) was built from lib/main.dart and v2-verified during the successful light capture; [current core40606948730](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40606948730) subsequently passed on the same chosen application. [Fresh normal APK12781157114](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40606948730/artifacts/12781157114) includes exact merge/head mapping in the delivery checkpoint. The preceding accepted immersive app `f9fc4ba` was tested by [40555672797](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40555672797): [normal debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40555672797/artifacts/12758462920) and [runtime reports/real exports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40555672797/artifacts/12762965938). Each download retains its own source and acceptance scope.

The merged creative expansion (PR #21, main a7c3670, 2.0.0+22) provides 13 original instruments, 12 keys/11 scales, accompaniment, 20 original templates, photo/camera/gradient backgrounds, PNG/MIDI/WAV/MP4, 12 locales and expressive/stylus/dark/tablet features. All creative tools remain free; no reference media ships.

**Current review fixes: 2.0.1+23**, branch `codex/review-fixes-2026-10-27`. Eraser capacity, relevant background validation, 4:5 preview, frozen export thumbnails, iOS audio revision/reset/route state, safe startup reclamation and HD60 profiling/cancellation are implemented. Accepted source `76c0ee2ff0b5d03f1b22a5ff4149d272d20a821b`, [Actions 40482959273](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273): formatter/analyzer, **240 Flutter / 24 JVM / 20 native Android / 15 pure Swift tests**, Android lint, actual 2.0.1+23 APK/v2 signature, all 12 Linux interruption/retry cases, full offline original/expanded creation/exports, independent actual-packet/full-stream/A-V inspection, HD and compact 60 FPS, actual HOME cancellation/same-process foreground, ten-minute native soak and Android force-stop/fresh-process exact retry pass. [Debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12725075870) · [Android runtime reports/exports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12725956006) · [Portable Swift proof](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12723034260), retained until 3 November 2026. See the [finding ledger](docs/REVIEW-FIX-PLAN-2026-10-27.md), [requirement matrix](docs/CREATIVE-REQUIREMENT-MATRIX.md) and [current status](docs/DEVELOPMENT-STATUS.md).

Native iOS source is included; Apple-framework compilation/signing/runtime remains unverified. Follow the [Mac commands](docs/IOS-IMPLEMENTATION.md). Physical audio/routes/sharing/camera/TalkBack/stylus/release performance/storage and human translation review remain separate acceptance. Ads/rewards, billing, accounts, uploads, paid/hosted services and cloud collaboration are excluded. New review PRs must remain draft/unmerged.

## Android verification after bootstrap

```bash
source /workspace/drawmusic-tools/env.sh  # selected published cloud environment
bash /workspace/drawmusic-tools/configure-runtime.sh
source cloud/env.sh
bash scripts/check-android.sh
```

Use the source-labelled APK links above. Download the Actions artifact ZIP and unzip `app-debug.apk`; the capture profile APK is not the installable product offered here. These are development builds. Physical-device and Apple-native validation remain separate. The public repository uses bounded free standard `ubuntu-24.04` runners; no paid runner or billing change is authorized.

The product script also runs the [Linux process-recovery probe](docs/PROCESS-RECOVERY.md). Hosted runtime evidence includes the [Android force-stop and ten-minute soak reports](docs/ANDROID-CLOUD-RECOVERY.md). [Compact layout coverage](docs/COMPACT-LAYOUT.md) describes the new accessibility scenarios. [Display-style policy](docs/DISPLAY-STYLES.md) and [Localization coverage](docs/LOCALIZATION.md) document the current behavior.

## iOS on your Mac

Pull `codex/ui-redesign-2026-10-27` for the full redesigned app (stacked on all unmerged review fixes) and use Flutter 3.47.2. The reviewed iOS project and native ports are already present; do not regenerate them with `flutter create`. Run `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build ios --simulator --debug`, then follow the [exact Xcode/signing/native-test and file-inspection commands](docs/IOS-IMPLEMENTATION.md). Configure development signing locally for a physical iPhone/iPad. Linux checks validate portable Dart and channel contracts only; Swift compilation, AVFoundation output and all iOS runtime behavior remain unverified.

## Research and asset ownership

Reference images and audio document source-app behavior. They must never be bundled in the product. This cloud starter includes 16 representative screenshots and source exports; the complete research remains in the original Mac checkout. See [cloud reference scope](docs/CLOUD-REFERENCE-SCOPE.md). The full local research includes private device captures; Git intentionally excludes camera-photo/cropper images, recipient suggestions, raw device dumps and invalid runs. Some provenance references are therefore local-only; see [publication scope](docs/RESEARCH-PUBLICATION.md). Use original or explicitly licensed shipping artwork, icons, templates and sounds with a provenance manifest.

No backend or account is required for the P0 creative workflow. Ads, purchases, accounts and hosted collaboration are excluded from this task. All creative tools are free. Physical audio latency/platform integration and native iOS compilation require their separately documented device/Mac validation.

## Runtime verification

The Android workflow runs JVM scheduler tests and an API 35 emulator in addition to Flutter tests/build. Native tests exercise AudioTrack and MediaCodec. The Flutter integration test runs the actual create/play/tempo/save/reopen/MIDI/WAV/MP4 UI flow with emulator Wi-Fi/mobile data disabled. FFprobe/FFmpeg inspect dimensions, FPS, real decoded audio, A/V duration and cursor timing; mido checks the UI-exported MIDI. Runtime evidence is uploaded separately from the normal debug APK. Physical speaker/Bluetooth latency and real receiving-app sharing still need device checks.
