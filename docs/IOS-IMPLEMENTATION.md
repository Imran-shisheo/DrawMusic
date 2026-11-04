# iOS source ports and Mac validation

The iOS project originated from **Flutter 3.47.2**. The release name is **Doodimo**, bundle identifier `com.devwithdelta.doodimo`, minimum iOS 15.0. The owner explicitly authorized App Store publication on 4 November 2026. Team `L3R5WVR26P` was verified in the signed-in individual Apple Developer membership, and the signed App Store IPA is version **2.0.1 (24)**. Signing keys and provisioning files are not committed.

## 4 November 2026 local Mac release validation

Xcode 26.2 / iOS 26.2 SDK compiled and signed the release. Strict deep signature verification, matching distribution profile/team, `get-task-allow=false`, release AOT (no debug kernel), six bundled SDK/app privacy manifests (no tracking or collected data), bundle/version/display name and minimum OS checks passed. Build metadata and SHA256 are in `distribution/app-store/validation/signed-build.json`.

The actual iPhone 17 Pro and iPad Pro 13-inch simulators each passed the UI screenshot flow: real project save/leave/reopen, advancing native playback and six real screen states. Capture fixtures are original mathematical drawings, not research/reference assets. Native XCTest passed **28 tests**: 15 audio-state cases and 13 renderer/encoder/ownership cases. Independent source review found and corrected iOS-only release defects:

- Encoded `.mp4.tmp` was rejected as missing tracks. The encoder now validates a genuine `.mp4` in exclusively owned temporary staging with asynchronous iOS 15 track loading, then hands off through an exclusive rename. Cancellation/failure never removes another job's destination. Tests preserve sentinels present before and during encoding and reject a genuine video-only movie.
- Quartz bottom-left coordinates reflected exported drawings vertically. The renderer now uses top-left document space and explicit sRGB, with independent asymmetric smooth/Pixel/cursor, gradient and four-quadrant photo crop/rotation/mirror regressions.

The real native-port flow passed audio clock/boundary/pause/resume and produced 640×800 and 1080×1350 H.264/AAC at 30/60 FPS. `scripts/validate-ios-video.py` independently checks actual packet cadence, full decoding, frozen-WAV correlation, release tail, duration, cursor position within one requested output frame, and asymmetric stroke positions. Reports live in `distribution/app-store/validation/`; all four measured 0.0 ms correlated audio offset. The same geometry inspection rejects the earlier reflected output. These are simulator codec observations, not physical audio latency, frame-rate, memory or thermal guarantees.

Reproduce with the pinned Flutter SDK on a Mac (use actual simulator UUIDs):

```bash
flutter pub get
flutter analyze lib test integration_test tool test_driver
flutter test
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,id=ACTUAL_UUID' \
  -parallel-testing-enabled NO FLUTTER_TARGET=lib/main.dart CODE_SIGNING_ALLOWED=NO test
DOODIMO_CAPTURE_DEVICE=iphone flutter drive \
  --driver=test_driver/app_store_screenshots_driver.dart \
  --target=integration_test/app_store_screenshots_test.dart -d ACTUAL_IPHONE_UUID
DOODIMO_CAPTURE_DEVICE=ipad flutter drive \
  --driver=test_driver/app_store_screenshots_driver.dart \
  --target=integration_test/app_store_screenshots_test.dart -d ACTUAL_IPAD_UUID
flutter drive --driver=test_driver/ios_native_ports_driver.dart \
  --target=integration_test/ios_native_ports_test.dart --keep-app-running -d ACTUAL_UUID
flutter build ipa --release --build-name=2.0.1 --build-number=24 --export-method=app-store
```

Locate the retained simulator's app container with `xcrun simctl get_app_container ACTUAL_UUID com.devwithdelta.doodimo data`; inspect only the files listed by `Documents/exports/ios-native-port-report.json`. For each record, run `python scripts/validate-ios-video.py VIDEO EXPECTED_WAV PROJECT_JSON REPORT_JSON FPS WIDTH` with NumPy/FFmpeg installed. The source pubspec retains the Android development build number; the iOS archive command deliberately overrides it to 24.

The historical cloud proof below did not execute Apple frameworks. Its former “unrun” statements are superseded by this local Mac section; physical checks at the end remain open.

## 27 October audio correction and executed portable proof

See [audio review evidence and exact reset/device steps](IOS-AUDIO-REVIEW-2026-10-27.md). The actual render-used pure Swift scheduling state now preserves newest desired requests independently of audible pause position, recreates/reset-generates audio graphs, classifies delayed route/interruption events, and invalidates a halted graph while preserving the newest snapshot for explicit retry. Fifteen scheduling/policy XCTest cases execute successfully with Swift 6.1.2 on Linux, and native Swift grammar parses; these checks do not typecheck AVFoundation/UIKit or compile/run an iOS app. The matching extracted baseline model failed 28 assertions across 11 cases; this is a reproduction of source semantics, not an executed first-Play device failure. All Apple-framework/native acceptance below remains open.

`bash scripts/check-ios-audio-state.sh` is a mandatory separate Linux CI job when Swift is installed. In this cloud use `DRAWMUSIC_SWIFT_TOOLCHAIN=/workspace/drawmusic-tools/swift-6.1.2 bash scripts/check-ios-audio-state.sh`. Missing compilers fail explicitly rather than being labeled skipped passes. The four renderer XTests and Apple-native execution of the scheduling tests remain unrun until Mac validation.

## Boundaries and behavior

- `IosAudioEngine` implements `AudioEngine` through `scribblesong/audio`. `DrawMusicAudio.swift` pulls the same immutable mono PCM16 44.1 kHz music snapshot used by preview/WAV/video. The AVAudioEngine render callback owns sample progression; widget timers do not trigger notes. Changes use beat/loop boundaries, a 128-frame revision handoff, start/resume ramps and a 16 ms user-pause tail. Interruption starts, backgrounding, removed devices and unsuitable/unexpected routes pause immediately without automatic resume. Expected category changes, insertion and app overrides follow Apple’s continuation policy; delayed self-generated notifications do not undo explicit Play. Media-services reset recreates the graph, retains the latest snapshot and leaves output paused until explicit Play. Preview gain is applied only in playback, not export. A bounded eight-segment revision timeline compensates for reported output latency when presenting cursor/revision state; actual route latency, drift and click behavior require device measurement. Render callback synchronization and allocation behavior also require Instruments review before claiming real-time performance.
- **Silent switch policy:** explicit Play uses `AVAudioSession.Category.playback`, mode default, so music plays even with the iPhone silent switch enabled. The session acquires exclusive playback only for user Play and releases it on pause/stop. There is no microphone capture and no background-audio capability; entering background pauses safely. The app does not resume after returning to the foreground, a call or route change.
- `IosVideoExportAdapter` / `DrawMusicVideo.swift` render the immutable document plus the same compiled PCM to H.264/AAC with AVAssetWriter. A pixel-buffer pool with a hard six-frame allocation threshold, one rendered frame at a time and 1024-frame audio chunks avoid whole-video frame accumulation. Widths 640/1080 and 30/60 FPS are accepted in source. No claim of iOS 60 FPS feasibility, memory, speed or A/V alignment is made until profiling and independent decoding pass. The document renderer supports smooth/Pixel geometry, all 13 catalog colors, solid/linear/radial paper, opacity and private normalized photo crop/quarter-rotation/mirror metadata. Photo bytes are SHA256/dimension-checked and decoded once per export into a bounded retained image; missing or corrupt images fail explicitly. Cancel/background aborts and removes temporary output; Dart publishes only after native completion and metadata/file checks.
- `IosExportFileActions` / `DrawMusicFiles.swift` validate canonical app-owned export paths, MIME, safe display names and nonempty files. Open presents the system document options from a private staging copy, with an iPad source rectangle. Save presents `UIDocumentPickerViewController(forExporting:asCopy:)`, then verifies the returned byte count and streaming SHA256 under security-scoped access. Cancel is distinct from success. Saved URLs are records of explicit copies, not persistent bookmarks. The original export remains in the library on all outcomes. The existing share_plus port handles native sharing and receives the Flutter button's iPad anchor; completion does not assert recipient delivery.
- `DrawMusicBackgrounds.swift` uses PHPicker without broad photo-library permission, or the system still-photo camera after explicit permission. ImageIO normalizes supported HEIC/EXIF orientation to immutable SHA256 PNGs under Application Support/backgrounds, max 2048 pixels on the long side. File input is limited to 32 MB and 80 million source pixels; corrupt/unsupported sources fail explicitly. Camera UIImage fallback scales before PNG generation, but the system camera's full-resolution capture memory is outside the app's measured bound and needs physical testing. Successful lost-callback metadata survives repeated `recover` reads until Dart validates delivery and sends `acknowledge`; cancellation/denial does not become an imported image. iOS cannot guarantee recovery if the OS kills an in-flight camera/import before producing an asset.

The camera usage description has resources for all 12 shipped locales. System pickers supply their own localization. Native diagnostic strings are internal error details; Flutter presents localized operational guidance. Permission translations and all language quality still require human review.

## Original assets and settings

`ios/generate_original_icons.py` rasterizes the application's original Android wave/note identity using Pillow. All app-icon and launch-image PNGs replace Flutter's generated placeholder graphics; no reference-app image is packaged. Regeneration is a developer step, not an app dependency. The native project retains the pinned Flutter template's Swift Package Manager wiring. Let Flutter generate ephemeral plugin/package state on the Mac; never commit DerivedData, generated configs, signing keys or provisioning profiles.

## Exact Mac setup and checks

1. Check out the feature branch/PR and install the pinned Flutter 3.47.2 SDK. Run `flutter --version` and `flutter doctor -v`; resolve the SDK's current Xcode requirements. Select a full Xcode installation with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` if needed, launch Xcode to finish its components/licensing, and install the iOS simulator runtime. This is local owner setup, not validated by the Linux cloud.
2. From repository root run:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter build ios --simulator --debug
   xcrun simctl list devices available
   open ios/Runner.xcworkspace
   ```

   No `flutter create .` is needed and must not overwrite reviewed project sources. For a physical iPhone/iPad, select Runner → Signing & Capabilities → a local development team, keep the development identifier or explicitly choose an available private identifier, and allow Xcode to manage local development signing. Do not send signing credentials to cloud.
3. Start an available simulator and set `IOS_SIMULATOR_ID` to its actual UUID. Run the native renderer tests and actual native-port integration:

   ```bash
   xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
     -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" test
   flutter test integration_test/ios_native_ports_test.dart -d "$IOS_SIMULATOR_ID"
   flutter run -d "$IOS_SIMULATOR_ID"
   ```

   The integration test is explicitly skipped on non-iOS hosts; that skip is not a pass. On iOS it checks real audio-clock advancement, a tempo-boundary revision, pause stability/resume and writes real 640×800 30/60 FPS MP4s plus `ios-native-port-report.json` in Documents/exports. The test's MP4 header assertion is only a container smoke check; it does not replace codec/duration/audio inspection. The Android-specific creation/recovery scripts must not be reported as iOS tests.
4. Locate the simulator's app data and inspect its files independently:

   ```bash
   xcrun simctl get_app_container "$IOS_SIMULATOR_ID" com.devwithdelta.doodimo data
   ffprobe -v error -show_streams -show_format '/actual/app/data/Documents/exports/actual-file.mp4'
   ffmpeg -v error -i '/actual/app/data/Documents/exports/actual-file.mp4' -f null -
   ```

   Use the actual returned app-data/file paths. Check H.264/AAC, dimensions, requested frame rate, note onsets, complete release tail and audio/video alignment within one output frame. Inspect sample paper/photo pixels, crop orientation and Pixel cell interiors against Flutter PNG and Android output. AVAssetWriter AAC priming/trimming has not been measured here; any offset failure needs a native correction before accepting iOS exports.

## Physical acceptance still required

- Speaker/wired/Bluetooth audibility and route latency, silent-switch policy, focus/call/Siri/route removal, all tempo extremes, revision switching and ten-minute playback. Verify no automatic resume or duplicated sessions.
- 13 distinct timbres, accompaniment/mute/levels and every export's exact frozen musical snapshot after rapid edits, pause and tempo changes.
- Actual Open/Save/share recipient apps; cancel/unavailable destinations, iCloud/third-party document providers, revoked access, iPad popovers and split-screen. Never equate a chooser launch with delivery.
- Photo/camera denial, Settings recovery, cancel, HEIC/EXIF orientation, corrupt/oversized files, interrupted imports, crop/rotate/mirror and immutable asset retention across duplicate/delete/recovery.
- Missing assets, low storage, process termination/power loss, export cancellation/background cleanup and private staging-copy cleanup.
- VoiceOver focus/return, 200% text, all locales, reduced motion, safe areas, keyboard dialogs and iPad orientations/workspaces.
- Instruments profile/release FPS, allocation, peak memory and native render-thread work. The source memory accounting and Linux Dart benchmarks do not establish physical limits.

Unresolved acceptance items above are not blockers for independent Android source work, and no task is scheduled automatically.

## Required physical media-services reset and route checks

With development mode enabled on a disposable iPhone/iPad installation, start a drawing, queue music/tempo edits near a boundary and pause/resume across positive output latency. In iOS Settings → Developer → MEDIA SERVICES TESTING → Reset Media Services, reset while playing and while paused. Return to the app: it must stay paused, preserve the latest drawing/snapshot, and resume only on explicit Play, with correct current/target revision and no duplicate graph/session. Repeat resets and Prepare/Play retries; use Instruments to check render/control races and bounded ownership.

Repeat first Play and successive Play after category/configuration changes; delayed category notifications must not stop the new session. Remove headphones or trigger a genuine interruption: pause safely and never automatically resume. New output insertion and app overrides may continue per Apple policy; verify clock/latency recalculation. Linux state tests do not establish these actual OS-notification outcomes.
