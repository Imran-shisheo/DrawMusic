# Doodimo delivery checkpoint — 28 October 2026

Version **2.1.0+24**, package `com.imranshisheo.scribblesong`. [Draft PR23](https://github.com/Imran-shisheo/DrawMusic/pull/23) is stacked on [draft PR22](https://github.com/Imran-shisheo/DrawMusic/pull/22). Both remain unmerged. All creative features are free and work offline; no accounts, advertising, billing or server services were added.

## Implemented and functionally checked

| Area | Delivered behavior | Evidence and limits |
|---|---|---|
| Creation | Stable normalized canvas, Draw/Erase, Undo/Redo, style/opacity, pressure/tilt metadata and bounded large documents | Domain/widget/native creation checks; physical stylus and release drawing performance remain separate. |
| Music |13 original voices,12 keys/11 scale families, tempo/beat/loop, original accompaniment/mix and expression | Actual native streaming, clock, focus/background/noisy-route policy, ten-minute soak and explicit recovery/retry. No claim of physical audibility/latency/Bluetooth acceptance. |
| Projects | Save/autosave, reopen, rename, duplicate, delete/Undo, recovery, compatibility and conservative staged orphan cleanup | Real file-system tests,12 interrupted Linux writes, actual Android force-stop/fresh-process recovery and exact retry. Disk-full/power-loss remains unperformed. |
| Paper | Color/linear/radial gradient, imported photo/camera, direct crop/rotate/mirror/opacity with Cancel/Apply | Aspect/hidden-invalid-field/thumbnail regressions and actual native crop/PNG/video flows. Vendor picker/camera/HEIC/grant behavior remains physical acceptance. |
| Export | PNG, original-voice WAV, HD/compact MP4 at30/60FPS, MIDI, frozen library thumbnails, Share/Save/Open and honest cancellation/error states | Actual codecs, all four format flows, complete independent file inspection, HOME cancellation and retry. Opening a share sheet is not claimed as recipient delivery. |
| Experience | Doodimo original identity, bundled licensed fonts, immersive scene/ribbon, duotone icons, retained adaptive dock, editor console/choosers, gallery, sheets, Settings/help/onboarding/rating | All major surfaces implemented. Reduced motion/lifecycle, navigation/state, theme/locale, compact/large-text/RTL and visual reference coverage. Runtime performance remains a failed acceptance criterion. |
| Languages/iOS |12 bundled locales and portable native platform boundaries | Automated resources/layout/persistence plus15 Linux Swift state tests. Human translations and Apple-framework compilation/signing/runtime are unverified. |

## Chosen source and reproducible checks

Chosen application checkpoint `979c59657f8c0b3656f02f91cb572fda63176392` restores the accepted missing-photo contrast fix. It has zero diff against accepted head `b5d5379d8d46a37d22a623256e1236af94b9d086` for `lib/`, `android/`, `ios/`, shipping assets, `pubspec.yaml`/lock and `integration_test/creation_loop_test.dart`. The unsuccessful static-lighting-cache experiment was reverted; its original measurement and image remain labelled [rejected experiment](ui/performance-trial/README.md).

The final local `bash scripts/check-android.sh` passed formatter (193 Dart files), analyzer (zero issues),368 Flutter tests with three explicit diagnostic skips,76 real-font states/eight unchanged strict pixel references,24 JVM cases, Android lint, actual debug APK/v2 signing and12 interrupted-save cases. Host27, artifact/resource reader24, native-source-proof6 and conservative change-classifier3 checks pass. No golden reference was regenerated for the reverted experiment.

[Full hosted gate40599305866](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40599305866) passed at23:37:39UTC on27October. Its merge checkout `69ed416e5db8b958f8bcdd1aa53240b0a61c258a` and accepted headb5 share tree `9f65579890ead480055c793202b4baf9c135c77b`. It actually executed20 Android native cases, offline creation/playback/save/reopen/four-format exports, background/HOME/force-stop retry, independent complete media inspection and15 portable Swift state tests. The source contains24 JVM methods; the hosted tasks passed, while per-case XML was not independently materialized in the final review.

- [Accepted normal debug APK12778736866](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40599305866/artifacts/12778736866): download ZIP and extract `app-debug.apk`.
- [Runtime reports and actual exports12779835650](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40599305866/artifacts/12779835650).
- Artifacts expire3November2026. Their ZIP digests differ from individual APK/file digests; no reproducible-binary claim is made.

The600049ms audio soak sampled2397 times/150 loops with no progress stall. HD1080×1350/60 encoded317 samples in38.748s; peak-sampled native process PSS75923KB. Five complete MP4 streams independently decoded, audio offset0ms and A/V duration differences12.403–32.063ms. These measure the API35 emulator and encoded outputs, not actual display FPS, maximum memory or physical thermal behavior.

Current capture/core head is `3bca6ae4f34beaff936f26df5e08a37e2e12b69f`. Final current-core verification remains queued; final chosen-source light capture40605481853 passed, including a normal lib/main.dart APK/v2 signature (artifact12781655455). Independent original-PNG inspection follows. The native reuse proof remains fail-closed against the accepted B5 source/run; current core/JVM/lint/APK checks are still required.

## Actual images and recordings

[Native Home/editor/export, compact and tablet images](ui/public-native-checkpoint/README.md) and [panels/recording contacts](ui/public-native-checkpoint/details/README.md) retain original source, SHA and byte-count manifests. Fresh compact320dp/200% and tablet captures passed their exact two-shot subsets and were visually inspected. Compact has a tall adaptive dock and a smaller canvas/scrolling console; all controls are not simultaneously visible.

[Seven original silent recordings12775775164](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40560035660/artifacts/12775775164) fully decode and match original hashes/bytes. They demonstrate actual ambient movement, navigation, editor/Back, paper sheet, instrument/Play, export and reduced-motion interaction on earlierf9/5c source. Original partial-run `passed:false` is preserved after late VM/ADB loss; separate responsive runs do not retroactively create a full23-shot pass. Actual native IME geometry/focus passed, but its PNG does not show keyboard keys.

## Concrete remaining acceptance

**UI-PERF-01 is unresolved.** The experimental normal Home run measured UI p95 **4.376ms**, raster p95 **183.802ms**, median162.615ms; **111/111** observed raster frames exceeded16.67ms. Its original39.860867-second/199-frame recording preserves real controller advancement and fully decodes. Integrity passed; smoothness failed. A same-run historical gradient/solid diagnostic measured raster p95189.470/149.772ms and restored the original background exactly. Both were over budget; separate-host differences do not establish a causal production improvement. The extra cache was therefore removed.

The remaining diagnosis needs an attributed raster trace and actual presentation-pacing evidence against unchanged normal content before any further optimization is accepted. Android HWUI zero-frame/sentinel values cannot supply that evidence. Do not pad/retime recordings, lower the budget, infer smoothness from export FPS, or dismiss the result because emulation is software-rendered.

Final chosen-source light capture passed; independent pixel inspection and current-core delivery remain. Physical Android audio/latency/routes, screen readers, recipient apps, stylus/vendor media, storage/thermal behavior, human language quality and Mac/iOS build/runtime remain separately unperformed. No owner action is required to interpret the existing cloud evidence; these limits are explicit rather than reported as passes.

Only bounded free standard `ubuntu-24.04` runners on the verified-public repository are authorized. No paid usage, billing/credential changes, merge, force-push, history/media cleanup, store publication, personal-device operation or scheduled continuation.
