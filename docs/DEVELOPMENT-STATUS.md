# Development status

## Active replacement: immersive audiovisual playground

The owner rejected BOTH previous visual iterations, including progress-02 palette/icons. Follow [the active replacement brief](requests/IMMERSIVE-REDESIGN-2026-10-27.md): navy/indigo/violet/cyan scene, polished duotone icons, prominent original bounded motion, immersive Home/editor/export with real emulator recording before wider propagation. Earlier visual claims below are historical/rejected proposals, not acceptance. Functional fixes remain preserved.

The product gate started before this latest rejection completed successfully on the preceding working tree: formatter/analyzer, 289 Flutter tests, three strict pixel references in a separate capture test, 24 JVM tests, lint, real debug APK and twelve Linux interrupted-save recovery cases. These prove correctness/buildability of that source only; its aesthetics are rejected and it is not the immersive implementation. No additional expensive acceptance is being started on the superseded look.

## Active Doodimo UI/UX redesign — 27 October 2026 / 2.1.0+24

**Design correction in progress:** the owner rejected the initial pale-card Home/editor/export preview as too basic. Its images/goldens are historical iteration evidence, not an approved redesign. The active revision materially changes composition, custom dock/glyphs, display type, editor console and format rail; fresh previews precede exhaustive visual acceptance. Functional fixes remain preserved.

Owner-selected display name: **Doodimo**; planned store title **Doodimo: Draw Music**, without store publication or legal/name-reservation claims. Repository and package ID remain DrawMusic / com.imranshisheo.scribblesong. [Draft PR #23](https://github.com/Imran-shisheo/DrawMusic/pull/23) is stacked on unmerged draft PR #22, from its documentation head cddebbd. Preserve every accepted fix below.

Pushed baseline/capture checkpoint `d15748333fb699b6015d3b5e7ce3f4a6afc1c20f`, followed by preview-only documentation commit `0f0b806`: full redesign brief/plan, 17 real before-widget captures and a dedicated owned profile-emulator harness. [Work-in-progress Home/editor/export previews](ui/progress/README.md) use actual rendered widgets, bundled fonts and declared fixture ports; they are not native-runtime acceptance. [Baseline emulator run 40491741921](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40491741921) is running against pinned pre-redesign product source cddebbd, with diagnostic source recorded separately.

Implementation currently in the shared working tree: semantic theme and spacing/type/motion components; licensed offline Nunito/Noto typography; original line-to-wave art; retained branch transitions and hidden/background/reduced-motion ambient lifecycle; Home hierarchy and real recent work; canvas-focused editor with named voice/music/advanced panels; intent-led PNG/WAV/MP4/MIDI export and actual artifact actions; document libraries; visual backgrounds/direct crop; grouped settings, language, welcome/help, coachmarks and rating. Native Doodimo icon/display-name integration is in progress. No new feature is accepted merely because this source exists.

Executed focused checks include six shared motion/contrast/adaptive-panel tests, font/translation coverage, support-screen tests and background/export regressions. New visual review caught a French 320 dp/200% editor summary overflow and navigation-label clipping; fixes and fresh captures are being verified. Final-source full formatter/analyzer/test/build/signature, native creation/save/export/runtime gates, final captures/real interaction recordings and measured profile evidence remain pending. See [redesign ledger](UI-UX-REDESIGN.md). Physical and Mac/iOS acceptance remain separate; all PRs stay draft/unmerged.

## Active review fixes — 27 October 2026 / 2.0.1+23

Merged baseline: main a7c367058101633271c990e57922ca25f7187811, PR #21 (merged; no actor attributed). New branch codex/review-fixes-2026-10-27. Complete request and focused reproduction evidence: [review fix plan](REVIEW-FIX-PLAN-2026-10-27.md). Accepted source `76c0ee2ff0b5d03f1b22a5ff4149d272d20a821b`, [Actions 40482959273](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273): formatter/analyzer, **240 Flutter / 24 JVM / 20 native Android / 15 pure Swift tests**, Android lint, actual 2.0.1+23 APK/v2 signature, all 12 Linux interruption/retry cases, full offline original/expanded creation/exports, independent actual-packet/full-stream/A-V inspection, HD and compact 60 FPS, actual HOME cancellation/same-process foreground, ten-minute native soak and Android force-stop/fresh-process exact retry pass. [Debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12725075870) · [Android runtime reports/exports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12725956006) · [Portable Swift proof](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12723034260), retained until 3 November 2026. Later documentation-only commits preserve this accepted application/native/test/check-script tree. Apple-framework/iOS compilation/runtime, physical-device acceptance and human translation review remain separate. All new PRs stay draft/unmerged. Physical/human/iOS-native acceptance remains separate.

The sections below are the historical 26 October expansion ledger and its exact-source evidence. Statements about PR #21 being unmerged described that earlier checkpoint; the PR is now merged and is not being undone.


Updated: **26 October 2026 — creative expansion 2.0.0+22**, branch `codex/creative-expansion`. The owner's uploaded scope supersedes older P1 deferrals and merging permission. All creative features remain free; leave this task's PR unmerged. Historical checkpoints below remain evidence only for their own source.

**Accepted Android application source:** `c721ce6d508ebde63b318859e3931342600f79f6`, [Actions 40329847034](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034). Formatter/analyzer, **170 Flutter / 20 JVM / 17 native Android tests**, Android lint, debug APK and local v2 signature, all 12 Linux interrupted-save recovery/retry checks, complete offline original/expanded creation and exports, independent MIDI/PNG/30+60 FPS MP4 inspection, the 600-second native playback soak and real Android force-stop/fresh-process recovery/explicit playback/exact save retry pass. [Download 2.0.0+22 debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034/artifacts/12654848499) · [Runtime reports and exports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034/artifacts/12657186456), retained until 2 November 2026. Later documentation-only commits do not change this accepted application/test/check-script tree. See [full requirement matrix](CREATIVE-REQUIREMENT-MATRIX.md).

**Implemented:** deterministic bounded simplification with exact score/Undo checks; shared-object history byte accounting; stable unknown-ID fallback and raw metadata/byte preservation; separate schema/sound versions and actual v1 fixtures; 13 original instruments, 12 keys/11 scales; original bass/arp/drum mixing and isolated MIDI channels; custom/linear/radial/photo/camera/crop/rotate/mirror backgrounds; 20 original templates, responsive gallery/navigation and playhead intersection feedback; true PNG/library/Open/Save/Share; 30/60FPS video options; twelve languages/330 keys, native labels and accessible compact controls; optional review threshold/cooldown; explicit expressive mode/stylus metadata/dark/tablet workspace; iOS source ports and scaffolding.

**Open acceptance/limits:** physical Android audio latency/timbre/routes, sharing recipients, camera/grants/HEIC/activity death, TalkBack and release FPS/memory, real disk-full/power loss; human linguistic review; iOS compilation/signing/XCTest/AVFoundation/device validation. Images are retained conservatively, so destructive orphan GC/storage cleanup is not claimed. Native review UI is platform/quota controlled, with no submission claim. Original store branding/listing/external destinations need owner configuration; broken links are not added. Ads/rewards, purchases/subscriptions, accounts, uploads, paid services, hosted backup/collaboration and unspecified advanced composition are excluded or owner decisions.

## Historical MVP checkpoint ledger

| Gate | Current evidence |
|---|---|
| Setup restoration | Bundle hashes/size/source commit verified by restore_bootstrap.py; reviewed normal setup committed and pushed to main as 3c83e1a, without force. |
| M0 | Complete: pinned Flutter 3.47.2 root Android app, Riverpod/go_router, Home/Drafts/Settings/Editor, original theme, empty/error states. Product navigation test, formatter, analyzer, APK compilation and APK v2 signature verification passed at 65cbc69. |
| M1 | Core implemented: normalized one-pointer strokes/dots, three instrument-linked colors, swept eraser with segment splitting, undo/redo/confirmed clear, bounded history. Geometry/history, exact 100,000-point interaction, cached painting and worker compilation/serialization checks pass. Physical drawing FPS/memory acceptance remains. |
| M2 | Score compiler + original three-voice PCM renderer + native Android AudioTrack clock/transport/focus adapter implemented. Determinism, speed/direction invariance, vertical chords, budgets and non-silent PCM tests pass. The owner confirmed audible playback of 1.0.1+2. The streaming adapter passes API 35 clock/boundary/pause tests and the 600-second native soak; physical audibility/latency/interruption retesting remains. Not an accepted M2 exit. |
| M3 | Core implemented: checksummed atomic local revisions, autosave/Save, guarded Back, thumbnails/drafts, reopen, corruption fallback/stale-save protection. Persistence tests, widget save–leave–reopen/failure recovery and the actual Android save/reopen UI flow pass. Rename/duplicate/confirmed soft-delete/Undo and recovery notices are implemented. Linux writer interruption and real API 35 force-stop/fresh-process recovery/retry pass; physical storage/power-loss acceptance remains. |
| M4 | Implemented: immutable MIDI/WAV plus HD/compact MP4, native public saving/Open, persistent export library and explicit dismissed/unavailable/success share states. Real native codecs, complete offline UI and independent MIDI/MP4/WAV inspection pass. Physical recipient-app delivery/device playback remains open. |
| M5 | Cloud hardening implemented: persisted settings/guides/tips, English UI/operational resources, compact safe-area/200% text/LTR/RTL route coverage, semantic targets/contrast, large-scene workers/budgets, Android process recovery and native audio soak. Physical TalkBack/routes/sharing/storage/drawing performance remain open; English is the only shipped locale. |

## Initial bootstrap evidence (historical)

Initial product check: `bash scripts/check-android.sh` passed formatter (26 lib/test files unchanged), analyzer (no issues), all 19 meaningful tests, and `flutter build apk --debug`. The expanded APK includes the native Android adapter and original icon; `apksigner verify --verbose` passed APK Signature Scheme v2 with one debug signer. Tests include the Play/Pause port path and 320 dp / 200% text after fixing a discovered toolbar overflow. Tests using a fake engine/repository are UI coordination evidence, not device audio evidence. Independent on-disk persistence/export tests use real files.

All implementation and verification ran in the selected cloud environment, using /workspace/drawmusic-tools/env.sh and refreshed runtime proxy/CA configuration. HOME was not changed; TLS verification remains enabled. Environment smoke-app results are excluded from product evidence. Doctor warns about the pinned detached channel, unknown license-status probe, absent Chrome/devices and blocked optional maven.google.com/cocoapods probes. Actual product builds succeeded. Gradle installed required API 35 and CMake 3.22.1 for plugins using the previously accepted SDK license; API 36/NDK remain pinned.

No Android emulator or physical device is available in the cloud; no iOS build/test is claimed. The owner subsequently reported a physical Android playback-start failure; see the correction below. Assets are original synthesis/geometry/vector artwork plus licensed Material icons; research media is not bundled. No accounts, backend, ads, purchases or paid service were introduced.

Next: native video export and transport boundary scheduling; retain honest M2/M4 gate status until their device/output evidence exists. See IMPLEMENTATION-NOTES.md for exact limitations and ASSET-PROVENANCE.md for shipping asset sources.

## Original hosted verification (superseded: playback initialization bug)

GitHub Actions [run 40096502571](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40096502571) completed successfully for product source head `e93161b45565d172093aacd755f0d9007a3ccbda` on 2026-10-24. Both setup detection and the real format/analyze/test/Android-build job passed. The uploaded [test APK artifact](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40096502571/artifacts/12561486508) contains the installable debug APK (ZIP download, about 89 MB). Artifact name uses the PR merge-ref SHA; its recorded source head is e93161b. It expires 2026-10-31 under the seven-day retention policy. Download while signed into the repository's GitHub account, unzip, and install app-debug.apk on an Android API 24+ device.

Review: [draft PR #1](https://github.com/Imran-shisheo/DrawMusic/pull/1). The later documentation-only handoff commit does not change the validated application source. No store publication or merge was performed.


## Playback initialization correction — 2026-10-24

The owner's device screenshot showed `audio_unavailable / Audio output unavailable` on Play. The MODE_STATIC adapter incorrectly required STATE_INITIALIZED immediately after construction. Android static buffers normally report STATE_NO_STATIC_DATA until the first PCM write, so this check rejected a valid allocation.

Version 1.0.1+2 allows STATE_NO_STATIC_DATA, rejects STATE_UNINITIALIZED, writes the entire PCM buffer, verifies STATE_INITIALIZED after the write, then sets loop points. Failed writes/state transitions/loop setup release the buffer. The editor shows a readable retryable error instead of a raw PlatformException. The regular cloud/CI check script now also runs Android JVM unit tests; the previous Flutter fake-engine test could not exercise this platform contract.

Regression evidence: the original pre-write state check failed the new state-transition test (and three failure-path assertions). The corrected lifecycle passed all six Android JVM tests. The full check script also passed formatting, analyzer (no issues), all 20 Flutter tests (including retry after native preparation failure), and debug APK compilation. apksigner verified APK v2 signing; aapt confirms version 1.0.1 / build 2. These tests simulate the documented AudioTrack buffer states; they are not a successful physical playback test. The owner must retest the replacement APK; successful audio output and latency are still unverified.

The old APK links above are retained as historical build evidence and must not be used to test this fix. A replacement Actions artifact will be linked from draft PR #1 after its build completes. Fresh hosted debug signing keys can differ between runs: if Android rejects an update for a signature mismatch, do not uninstall the old app without preserving needed drafts; uninstalling deletes app-private drawings.


## Creation-loop and draft-management checkpoint — version 1.1.0+3

The owner confirmed version 1.0.1+2 plays successfully on their Android device on 2026-10-24. This establishes basic audible playback for that build, not latency/interruption/soak results.

The next build replaces MODE_STATIC with a bounded MODE_STREAM producer driven by PCM frame counts. Drawing/scale/history revisions queue for the next available loop boundary; tempo-only revisions queue at the next available beat and preserve musical phase. Queued revisions coalesce, with a 128-frame handoff ramp. A timeline maps the hardware playback head to the audible revision and phase; cursor polling does not schedule audio. UI badges remain until the new revision reaches the playback head. Pause preserves buffered position; Replay prepares a new session. The obsolete static loader/test adapter is removed; its historical fix remains in git history.

Native frame-timeline tests cover boundary timing, coalescing, hardware-vs-write-head distinction, pause position, 32-bit playback-head wrap and crossfade endpoints. Editor integration tests cover continuous playback while editing, pending labels, rapid tempo updates and pause/resume without a second session. Rapid button taps now read the latest document rather than capturing an old frame's tempo. This new streaming adapter still needs device playback/interruption/latency testing; the owner's confirmation applies to the previous adapter.


This checkpoint passed `scripts/check-android.sh`: formatter (27 lib/test files unchanged), analyzer (no issues), 26 Flutter tests, 10 Android JVM frame-scheduler tests, debug APK compilation and local APK signature verification. New persistence tests cover serialized rename, independent duplication, tombstone survival across repository restart, restore, and preservation of damaged bytes during repair. UI tests cover draft rename/duplicate/delete/Undo and multiple strokes committed within one frame.

Draft overflow now offers Rename, Duplicate, Export/share and confirmed Delete with six-second Undo. Deletion is a persistent tombstone, preserving files; queued saves cannot resurrect it. Recovery of a prior revision is labeled in Drafts and Editor. Damaged/unsupported bytes are copied aside before a revision ordinal is replaced. Process death, storage exhaustion and physical interruption handling remain device QA items. MP4 is the next implementation slice.


## MP4 slice — version 1.2.0+4, runtime verification pending

An Android MediaCodec/MediaMuxer adapter now renders original document geometry and a timestamp-driven scan cursor offscreen, encodes the same offline PCM used by WAV to AAC, and muxes H.264/AAC MP4. HD is 1080×1350 at 30 FPS; compact is 640×800 at 30 FPS. The video length follows the encoded audio's duration to include AAC packet padding. Rendering runs on a native worker, reports actual frame progress, checks cancellation, and deletes incomplete files. Backgrounding cancels video export. The Dart adapter validates the returned file/metadata and atomically publishes it before enabling explicit sharing. User-facing filenames omit internal project/revision IDs.

No microphone, screen recording, research media, account or content upload is involved. Android instrumentation tests compile locally; this cloud worker has no /dev/kvm, so runtime acceptance is performed in the existing GitHub Actions workflow using an isolated API 35 emulator. The new checks exercise the real streaming clock, native encoder and cancellation, then use the actual Flutter UI for playback/tempo, save/reopen and all three export formats with networking disabled. FFprobe/FFmpeg and mido independently inspect the resulting artifacts. Do not treat these runtime/MP4 checks as passed until the run's output is recorded. Physical audio latency, interruptions, native recipient sharing and iOS remain unverified.


Local validation for the MP4 slice passed: formatter for lib/test/integration_test/tool, analyzer with no issues, 29 Flutter tests, 10 JVM tests, normal debug APK compilation and signature verification, plus `assembleDebugAndroidTest`. AndroidX debug test dependencies are aligned with the pinned Flutter integration-test SDK. Three native runtime tests and the Android Flutter integration test are compiled but await the Actions emulator; no encoded-output/runtime pass is claimed at this point. Remaining P0 hardening includes persisted settings/tutorials, exported-library management, tempo press-repeat, pause/focus fades, large-scene simplification/performance and physical lifecycle/share checks.


The owner merged the prior 1.0.1+2 checkpoint via PR #1 before this iteration. Current work is isolated on `codex/live-loop-video`, based on that merged main tree, and will use a new draft PR. Older PR #1/artifact references above describe historical checkpoints; current build evidence will be linked from the continuation PR. No new merge has been performed by the agent.


First continuation run 40109503631 passed product checks/build and uploaded the APK, but the API 35 emulator image could not install because the hosted runner ran out of disk space. Runtime/MP4 checks therefore did not execute; they are not counted as passed. The follow-up removes unrelated preinstalled toolchains only on disposable GitHub-hosted VMs (preserving the pinned NDK, source and credentials). Independent audio-offset validation uses sample-precision FFT correlation rather than coarse downsampling. No larger/paid runner was enabled.


The second emulator attempt remained active beyond 15 minutes without a final result. The follow-up bounds the emulator step to 20 minutes, caps Gradle at the same 3 GB heap already used successfully in the published cloud environment, releases its daemon before emulator boot, and builds runtime tests for emulator x86_64 only (the downloadable product APK still includes all Android ABIs). Superseded runtime results are not counted as passes; logs will be inspected before accepting the new adapter/MP4 output.


Inspection of superseded run [40110558767](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40110558767) confirms all three Android instrumentation tests passed on API 35: the real streaming AudioTrack clock/boundary/pause test, H.264/AAC HD export, and cancellation cleanup. The subsequent Flutter integration APK build stalled with emulator CPU hang warnings before the runner shut down. This is native API execution evidence, but the independent encoded-file inspection and full UI/save/reopen flow did not finish; MP4 timing acceptance remains pending. Retry 40112791948 uses the bounded memory/runtime configuration.


Bounded run [40112791948](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40112791948) passed the product checks/build and all three native runtime tests again. The actual Flutter UI completed playback, the audible tempo revision, saving and MP4/WAV/MIDI exports, but its navigation assertion ran before asynchronous Back/save completed (pumpAndSettle waits for scheduled frames, not filesystem completion). The integration check now waits for the gallery and reopened canvas conditions. The integration APK also compiled separately in this cloud worker in 29 seconds. Independent file validation will run even after a runtime-test failure, while preserving the failing job result. No full UI/timing pass is claimed yet.


Downloaded run-13 evidence exposed a harness-only extraction failure: both Gradle connected tests and Flutter integration tests uninstall their app by default, so post-test run-as calls captured unknown-package messages instead of exports. Runtime checks now retain APKs until extraction on the disposable emulator (`android.injected.androidTest.leaveApksInstalledAfterRun` and Flutter `--no-uninstall`). The emulator is destroyed by the action afterward. The 55-byte error files are explicitly not encoded-video evidence.


## AAC timing correction — version 1.2.1+5

Run [40114311474](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40114311474) passed all three real native tests and the complete Flutter create/play/tempo/save/reopen/MIDI/WAV/MP4 flow on the offline API 35 emulator. The overall job failed because the runner lacked ffprobe; CI now explicitly installs FFmpeg. Downloaded runtime files were independently inspected in the selected cloud worker: MIDI parsed successfully (27 notes, 121 BPM, SMF0/480 PPQ, 3840 end tick), but MP4 audio correlation measured 46.44 ms of AAC priming delay, beyond the one-frame limit. The compact AAC tail was also 15.67 ms short. Version 1.2.0+4 therefore does not satisfy MP4 timing acceptance.

Version 1.2.1+5 pads encoder input to flush the full release tail, decodes its encoded AAC, measures the device-specific delay against the original PCM, removes whole priming packets and retains enough packets for the complete source. Remaining delay must be below 1024 samples (23.22 ms); independent FFmpeg correlation must still pass within one 30 FPS frame. Alignment rejects unrelated/truncated audio, remains bounded and responds to cancellation. Four added JVM tests cover delays with a quiet lead-in and amplitude change, silence, invalid/truncated signals and cancellation. All 14 JVM tests and the instrumentation APK compilation passed locally; final product/re-encoder verification follows. Physical acceptance steps are in ANDROID-ACCEPTANCE.md.


## Verified Android checkpoint — 1.2.1+5

[Actions run 40116470068](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40116470068) completed **successfully** on 2026-10-24 for application source `a7fbaa20608a504a2e0ab2d514bb6427a32ba2b5`. Formatter (30 files unchanged), analyzer (no issues), 29 Flutter tests, 14 JVM tests and the normal Android debug build passed. Local apksigner verifies APK v2 signing. All three real API 35 native tests passed (streaming clock/beat/loop/pause, HD encoding, cancellation cleanup). The actual offline Flutter create/draw/play/audible-tempo/save/MP4/WAV/MIDI/Back/Drafts/reopen flow passed.

Independent FFmpeg/FFprobe and mido inspection passed on actual emulator output:

| Output | Observed result |
|---|---|
| HD MP4 | H.264 1080×1350, 30 FPS, 5.300000 s video; AAC mono 44100 Hz, 5.270930 s audio; duration difference 29.07 ms; audio correlation 0.999806 and measured offset 0 ms. |
| Compact UI MP4 | H.264 640×800, 30 FPS, 5.233333 s video; AAC mono 44100 Hz, 5.224490 s audio; duration difference 8.843 ms; correlation 0.999704 and offset 0 ms. |
| Cursor | HD quarter/three-quarter positions within 1 px; compact within 1 px and 4 px respectively; both pass the declared timing tolerance. Decoded frames visually inspected: original marks and cursor, no app chrome. |
| UI WAV/MIDI | WAV is the reference for compact audio correlation and decodes as mono PCM16/44100 Hz with the source release tail. MIDI independently parses as SMF0, 480 PPQ, 27 balanced notes at 121 BPM, end tick 3840 and 3.966944 s duration. |

[Installable test APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40116470068/artifacts/12569676209) · [Runtime exports/reports/logs](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40116470068/artifacts/12570297188) · [Draft PR #2](https://github.com/Imran-shisheo/DrawMusic/pull/2). Artifacts expire 2026-10-31. Download while signed into GitHub, unzip and install app-debug.apk. The final documentation-only commit records these results; its application tree is the tested source above.

M2 still requires physical audibility/latency/interruption acceptance of the new streaming adapter; the owner's earlier confirmation applies to 1.0.1+2. M3 process-death/low-storage acceptance and M4 actual receiving-app sharing/device MP4 playback remain pending. M5 and P0 completion are not claimed. Next implementation work: persisted settings/tutorials and exported-library management, followed by transport fades/press-repeat and large-scene/accessibility hardening. iOS native adapters and local Mac validation remain pending. No app-store release, paid service or merge was performed by the agent.


## Preferences and first-use guide — 1.3.0+6

The owner authorized continuing feature-by-feature PRs and merging after relevant checks pass on 24 October 2026 (Asia/Dubai). PR #2 was merged as df38a62; store publication and paid services remain unauthorized. AGENTS.md records the new merge permission.

Preview volume, optional selection haptics and reduced-motion preference now persist locally, with checksummed atomic writes, backup recovery, preservation of damaged bytes, visible errors and retry. Preview volume is applied to each playback session and does not change exported audio. Reduced page transitions respect either the app setting or the system preference; the essential audio cursor remains available. Settings includes offline privacy/help and actual package version/build information.

First-use guidance has reachable Start/Skip actions in a safe-area footer, persists completion, and can be replayed from Settings without resetting completion. Failed saves do not claim completion; Continue for now is explicitly temporary. Tool-specific contextual spotlights and localization infrastructure remain future hardening.

Local scripts/check-android.sh passed formatter, analyzer (no issues), 35 Flutter tests, 14 JVM tests and the real debug APK build. APK v2 signature verification passed. New checks cover real file restart/recovery/preservation, invalid settings, first-use completion/replay, failed-save retry, persisted preview volume reaching playback, and 320 dp / 200% text guide actions. The expanded Android integration flow now mutes preview, verifies exports remain musical and reloads preferences after recreating the app. Its hosted execution is pending; physical haptics/reduced-motion/device acceptance are not claimed. Next feature: persistent exported-file library.


## Verified preferences and guide

PR #3 was merged as 0d95807 after [Actions 40121830650](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40121830650) passed for 3cdd60f. Formatter/analyzer, 35 Flutter tests, 14 JVM tests, APK build, all three native tests and the full offline UI flow passed. The UI test muted preview, produced musical WAV/MP4, recreated the app and verified saved preview volume/tutorial completion. Both MP4 sizes measured 0 ms audio offset. [1.3.0+6 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40121830650/artifacts/12571965681) and [runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40121830650/artifacts/12571773423). Physical feedback and current-adapter device acceptance remain pending.

## Export library and public copies — 1.4.0+7

The Library tab now contains Drafts and Exports. Completed exports persist as independently listed files with checksummed atomic sidecar metadata, snapshot thumbnails, format/date/size details and a link to the source drawing. Older files without metadata remain discoverable; missing files and damaged details are isolated and preserved. Rename changes the readable display/share name without changing bytes. Delete has immediate six-second Undo and durable tombstones; expired private files are purged on the next listing. Shared/public copies and editable source drawings are unaffected. Deletion Undo now clears older status snackbars so its opportunity is not queued past its deadline.

Native Android Open uses a read-only FileProvider URI to a narrowly scoped cache copy. Save is explicit: API 29+ publishes a verified copy under Downloads/DrawMusic with MediaStore, while API 24–28 uses the system document picker. No broad storage permission is introduced. Pending/failed copies are cleaned where the provider permits; canceled saving is not reported as success. Share handles dismissed/unavailable results honestly. The export panel also offers public saving. Unicode display names are retained, with path separators removed. Catalog finalization after file publication is a short non-cancelable commit phase; metadata failure preserves a discoverable completed file and reports the limitation.

Local full checks pass: formatter, analyzer, 41 Flutter tests, 14 JVM tests, debug APK build and APK v2 signature verification. The expanded instrumentation APK compiles. New real-file tests cover restart, rename byte preservation, legacy discovery, corruption preservation, missing files, durable Undo and isolated expired-file cleanup; the Library widget test exercises Open/Rename/Share/Save/Delete/Undo through ports. A new native test writes a public WAV, reads it back byte-for-byte and removes only the test copy. The hosted UI flow now verifies three catalog entries, saves through the actual Android action, reopens the drawing and rechecks the library after app recreation. Hosted execution is pending; the native public-copy test is compiled, not yet counted as executed. Legacy document-provider flows and actual receiving-app/device acceptance remain pending. Next feature: transport fades and tempo press-repeat.

### Export-library channel wiring correction

Actions 40123615425 passed all 41 Flutter tests, all four native tests (including byte-for-byte public Downloads copying) and independent MIDI/WAV/MP4 inspection. The full UI flow failed at public Save because the file-action MethodChannel had not been registered in MainActivity. The Activity now registers it during Flutter engine configuration. The integration test also stops immediately on a visible Save failure and prints visible text on other condition timeouts. Local formatter/analyzer, 41 Flutter tests, 14 JVM tests, APK build and v2 signature verification passed after the correction. Hosted UI acceptance is being rerun; PR #4 remains unmerged until it passes.


## Transport polish — 1.5.0+8, local checkpoint

Tempo controls now repeat on hold, stop at limits/release/cancel/background/modal/disposal, and retain accessible tap labels. Tooltip gesture handling was corrected after the new hold tests found that default tooltips intercepted the long press. Live update rendering is bounded to one task with latest-revision coalescing. A regression test demonstrated that editing during native preparation previously canceled Play; preparation now retries the latest document and plays it once, with stale session polls ignored.

Native preview gain uses a 16 ms monotonic ramp for start/resume and explicit user Pause, driven from the existing native writer rather than Dart musical timers. Rapid resume reverses the current gain ramp; pause/focus/noisy-route/background interruptions can still mute immediately, and close is idempotent. Physical click/latency/route acceptance remains pending. Four new JVM envelope tests pass. The new native test exercises smooth pause reversal, clock preservation, muted playback and repeated close; it compiles but has not run yet.

Local product checks passed formatter/analyzer, 45 Flutter tests, 18 JVM tests, debug APK build and APK v2 signature verification. The five-test instrumentation APK compiles. Hosted transport/replay execution is pending. PR #4's file-action channel registration correction is included in this source. Its hosted UI rerun is pending. PR #5 targets main to run CI for the combined runtime and will be merged only after #4 and its own relevant checks pass.

## Canvas and large-document reliability — 1.6.0+9

Active ink now appends without copying the growing point list, with an explicit repaint notifier and immutable committed strokes. Metadata refresh and delayed parent acknowledgement of an earlier commit no longer discard a stroke in progress. Real pointer tests cover 10,000 new samples beside 90,000 existing points and exact project-limit enforcement. History compares semantic content without whole-document JSON and preserves redo on no-op edits. Cached point counts and conservative eraser bounds avoid repeated scans; exact eraser clipping and score policy are unchanged. Untouched later strokes retain identity after an earlier erasure.

Score compilation and PCM rendering now share a worker from the same immutable snapshot. Accessible note description, persistence JSON and checksums also run away from the UI isolate while atomic publication and recovery retain their serialized I/O behavior. A real-file 100,000-point save/reopen test verifies every point, duplicate-save handling and two queued renames. [Performance notes](PERFORMANCE-NOTES.md) record the original synthetic fixture and qualified before/after cloud CPU measurements; phone FPS and physical latency are not inferred. Local product checks passed formatter, analyzer, 50 Flutter tests, 18 JVM tests, Android debug build and APK v2 signature verification. Hosted acceptance is pending. Next: contextual first-use guidance and accessibility hardening.

## Retained root navigation — 1.7.0+10

Home, Drafts, Exports and Settings now retain separate navigation branches. Switching bottom tabs preserves each loaded page and its scroll position; Library returns to the last Drafts/Exports section. Editor and Help remain above the root shell so closing them returns to the originating section. The regression test verifies Home/Drafts scroll restoration, remembered Exports, system Back dismissing only the clear confirmation, and guarded editor Back returning to Exports after saving. Local formatter, analyzer, 51 Flutter tests, 18 JVM tests, Android debug build and APK v2 signature verification pass. Hosted navigation acceptance remains pending. This does not establish TalkBack or iOS safe-area acceptance.

## Verified export library

PR #4 merged as 6b3ea8c after [Actions 40125788727](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40125788727) passed at e09b5ca. Formatter/analyzer, 41 Flutter tests, 14 JVM tests, APK build, four real API 35 native tests and the complete offline UI flow passed. Public WAV copying verifies exact bytes; actual Flutter Save-to-Downloads, catalog/source metadata, reopen and library persistence after app recreation passed. Independent MIDI/WAV/MP4 inspection passed; both MP4 fixtures measured 0 ms audio offset. [1.4.0+7 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40125788727/artifacts/12573077298) · [runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40125788727/artifacts/12573777925). Legacy document providers and physical receiving-app acceptance remain pending.

## Contextual editor tips — 1.8.0+11

The real first editor offers skippable guidance against actual Draw, Play, instrument, tempo and key/scale targets. A modal barrier prevents tap-through to highlighted controls; the panel scrolls independently while Next/Skip/Done stay reachable. Reduced-motion preference removes the guide transition. Guidance explicitly describes the current C-only pentatonic choices. Editor Help replays tips; Settings & help can open a clearly labeled new blank drawing with the walkthrough.

Explicit Skip/Done persists completion, with backward-compatible defaults for older settings. Back closes only the guide without claiming completion. A failed preference save leaves creation available, reports temporary closure and supports settings retry. Targeted tests pass for all five steps, tap-through prevention, no repeat after completion, replay, legacy preferences and 320 dp / 200% text with a failed completion write. The full Android integration flow now skips the initial tips explicitly and checks completion after app recreation. Local formatter/analyzer, 54 Flutter tests, 18 JVM tests, Android debug APK build and v2 signature verification pass; added Back/real-file preference-completion tests also pass. Hosted acceptance is pending; no physical screen-reader validation is claimed.

## Selected cloud execution interruption

After application commit d200c5f was pushed and PR #8 opened, the selected environment reported unavailable. A branch-creation command failed with `exec-server transport disconnected`; a read-only retry returned `No usable execution environment is available`. The cloud configuration status still reports running/connected, so it does not establish usable shell readiness. No subsequent application code or build was performed elsewhere. This documentation-only commit records the blocker through the repository API; application source is unchanged from the locally checked checkpoint.

Paper-opacity work was planned next but has not started. Remaining P0 implementation also includes non-destructive Smooth/Pixel display styles and localization/accessibility hardening; device frame/memory/long-play, low-storage/process-death, receiving-app and iOS acceptance remain open. Resume in the selected cloud environment when usable, source the toolchain environment and refresh its runtime proxy as instructed, fetch these pushed branches and continue without repeating SDK license approval. Existing hosted CI can continue independently; merge only after the corresponding runtime checks pass. Do not infer P0 completion from the local passes.

## Cloud resumed and paused-cursor correction — 25 October 2026

The selected cloud shell is usable again. Runtime proxy configuration was refreshed, toolchain environment sourced, TLS verification retained and pushed branches fetched. No repeat SDK-license approval was needed. Hosted runs 40126667073 and 40127109403 exposed an intermittent native pause cursor movement: some outputs publish one final hardware quantum after AudioTrack.pause returns. Later stacked runs 40126758709 and 40127679977 passed, but those intermittent passes do not resolve the known defect. PR #5 now latches the paused cursor and resumes hardware-clock reads on Play. The regression repeats five smooth pause/resume cycles and checks immediate pause without relaxing tolerance. Local JVM tests, debug APK and instrumentation APK compilation pass. The correction is merged normally through PRs #6–#8; all four hosted checks are rerunning. No failed checkpoint has been merged.

## Paper opacity — 1.9.0+12, local checkpoint

Paper color now includes a 0–100% opacity slider, named colors, a live panel preview and explicit Cancel/Apply. Lower opacity composites paper over white; marks remain opaque and music is unchanged. The editor, Drafts/Exports thumbnails and native MP4 renderer use the same integer blending policy. Existing ARGB project storage preserves the chosen alpha across save/reopen, duplication and snapshot metadata, without a schema change. Undo/Redo restore paper changes and no new audio render is queued for them.

Local formatter/analyzer, 56 Flutter tests, 19 JVM tests, Android debug build, six-test instrumentation APK compilation and v2 signature verification pass. The additional 320 dp / 200% text panel test also passes, including reachable actions and opacity application. Real-file tests verify exact alpha/geometry persistence and identical score/PCM. Editor tests cover preview/cancel/apply/undo/redo/save during continuing playback. The native test checks repeated offscreen frames and full-strength ink; hosted execution is pending. The full hosted UI flow now selects half-opacity lilac paper and rechecks it on reopen. Independent FFmpeg inspection checks the actual compact MP4 background against the saved document. Next feature: non-destructive Smooth/Pixel display styles; physical/device acceptance remains open.

## Smooth and Pixel display styles — 1.10.0+13

A named style selector now switches non-destructively between freehand Smooth and an original 40 × 50 Pixel grid. The selected option has a check, named icon and explicit accessibility announcement. Closing the sheet cancels. Existing points, timing, instrument assignment and brush width remain intact; Undo/Redo, save/reopen, duplicate and exported thumbnails retain the style. Style changes do not alter score/PCM or queue audio renders. Legacy documents default to Smooth, and unknown style values preserve the original file through the existing recovery path.

Dart and Kotlin share the documented display-only cell policy in [DISPLAY-STYLES.md](DISPLAY-STYLES.md). Committed stroke occupancy is cached and bounded to 2,000 cells; pointer preview stays local. The native MP4 renderer uses the same grid and opaque instrument colors. The UI integration flow now saves/reopens Pixel with half-opacity paper, and FFmpeg inspection checks the interior of a real exported pixel cell in addition to paper color, cursor, audio and codecs.

Targeted style/paper/editor tests pass, including actual raster pixel inspection, reversal/boundary/dot geometry, 100,000-point occupancy, real-file persistence/duplication and unchanged PCM. Local full formatter/analyzer and 61 Flutter tests pass. Android debug APK, 20 JVM tests, seven-test instrumentation compilation and APK v2 signature verification also pass. Kotlin compilation initially caught a Paint-style name collision; it was corrected before the passing native build. Hosted seven-test native/full UI/export acceptance is pending. Next: English localization infrastructure, locale-aware formatting and accessibility/RTL coverage. Physical device/iOS acceptance remains open.

## English localization foundation — 1.11.0+14

The app now uses a generated English ARB catalog and Flutter localization delegates. Core navigation, editor/style/paper controls, contextual guidance, settings/library/export actions and parameterized score/export summaries use resources. Only English is offered in the scrollable Language selector, with check, Apply/Cancel and retryable save failure. Missing/unsupported saved languages and unsupported device locales fall back safely. The router and root tab state survive preference/locale rebuilds. Display numbers and dates use locale-aware formatting; user titles and persisted music/export data stay unchanged. The editor title now exposes its rename action explicitly to accessibility.

Existing 61 Flutter tests passed after the resource migration, and four new localization tests pass: real-file fallback preserving other preferences, unsupported device locale and Apply/Cancel without changing a non-Latin/RTL drawing, retryable failure with reachable actions at 320 dp / 200% text / RTL, and English date/number formatting. Full local formatter/analyzer, 65 Flutter tests, 20 JVM tests, Android debug APK build and APK v2 signature verification pass. The generated English catalog contains 179 messages. [LOCALIZATION.md](LOCALIZATION.md) describes generation and scope: some operational/native failure messages still use English directly, no secondary translation ships, and full physical screen-reader/RTL/device acceptance remains pending. Hosted acceptance is pending.

## Verified backup retention — 1.11.1+15

The recovery review found that housekeeping kept the three newest revision filenames even when two were corrupt. Saving a new revision could then delete the last usable older backup. Pruning now verifies checksums, schema/engine and project identity before counting a revision toward the three valid copies retained. Damaged, unsupported and foreign-identity bytes are preserved and do not consume that recovery budget. Cleanup failures do not turn an already published save into a false failure. Small histories avoid redundant validation when no pruning is needed.

Real-file regression tests pass for a corrupt-newest sequence that previously evicted the last good revision, unsupported engine data surviving later saves, bounded retention of three valid copies, recovery after a later corruption, and an actual Linux permission-denied save followed by successful retry without altering the published drawing. The permission test is real I/O failure evidence, not a disk-full or Android process-kill simulation. The last-good-backup regression fails against pre-fix 431d89a (the original backup is deleted) and passes with this change. Full local formatter/analyzer, 68 Flutter tests, 20 JVM tests, Android debug build and APK v2 signature verification pass. Hosted acceptance is pending. Actual process-death, low-storage, power-loss and physical/device acceptance remain pending.

## Merged runtime checkpoints — 25 October 2026

PRs #5–#9 were merged in order after corrected full hosted checks passed, with no unresolved review threads. Merges: #5 1283def, #6 2b7821c, #7 c4bd336, #8 1109f90 and #9 1286ec6. Actions 40130877163 / 40130900883 / 40130903126 / 40130905675 accepted transport, canvas, navigation and tips; each ran all five native tests and the complete UI/export flow. Actions 40131177171 accepted paper opacity with 57 Flutter tests, 19 JVM tests, all six native tests, actual half-opacity save/reopen/public-copy flow and independent encoded-paper inspection. Both MP4 fixtures measured 0 ms audio offset; UI MIDI parses at 122 BPM.

Latest merged [1.9.0+12 test APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40131177171/artifacts/12575586565) · [runtime exports/reports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40131177171/artifacts/12575088202). PR #10 (styles) and #11 (English infrastructure) remain in hosted checks. The current retention correction adds local evidence only until its own hosted gate passes. Physical/device/iOS acceptance is not inferred.

## Linux process-interruption recovery gate

The product check script now compiles a Linux-only AOT diagnostic and starts 12 disposable writer children in isolated temporary project directories. Each child uses the real FileProjectRepository to save a 100,000-point candidate. The parent observes creation of that attempt's temporary revision, interrupts only its own child, reopens through a fresh repository, verifies the published baseline bytes and then saves/reopens a retry exactly. No PID/name scan, phone operation or external application is involved. Reports distinguish a completed valid publication from an interrupted temporary file and require at least one pre-publication interruption.

The local full gate passes: formatter/analyzer, 68 Flutter tests, 20 JVM tests, debug build/signature and 12/12 pre-publication process interruptions with exact recovery and successful retry. The report is work/runtime-output/process-recovery.json and is included with hosted runtime evidence when CI runs this checkpoint. This is Linux filesystem/process evidence; Android force-stop, actual low storage and power-loss remain pending. Application source/version is unchanged from 1.11.1+15; this checkpoint adds the diagnostic, check-script gate and documentation only.

PR #10 is merged as b1da7fd after Actions 40131600104 passed 61 Flutter / 20 JVM / seven native tests and the full UI/export flow. Actual encoded Pixel output matched all 100 interior samples in both frames; paper color matched and both audio offsets measured 0 ms. [1.10.0+13 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40131600104/artifacts/12575072785) · [runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40131600104/artifacts/12575238474). English infrastructure (#11) and retention (#12) remain in hosted acceptance.

## Input contract and P0 coverage — 1.11.2+16

The final input review aligned tempo hold with the PRD's proposed 400 ms start and 100 ms repetition. A custom long-press recognizer preserves ordinary taps, release/cancel/modal/lifecycle/disposal stops and disabled controls. The hold hint is now an English resource. An exact-timing test verifies start/repeat/release without a duplicate release tap; existing limit tests rebuild as a parent disables the control.

The eraser now shows its transient 12 dp ring at the real pointer. Sampling/clipping use the actual canvas aspect ratio so the displayed ring matches the hit area outside the nominal 4:5 layout. A gesture test on a deliberately nonstandard viewport verifies pointer position, the expected clipped gap, one cancellation commit and ring removal. Targeted tests and the full local gate pass: formatter/analyzer, 70 Flutter tests, 20 JVM tests, Android debug build/v2 signature and all 12 Linux interruption/recovery/retry attempts. Hosted input acceptance is pending.

[P0-COVERAGE.md](P0-COVERAGE.md) maps all P0 features to evidence and limits. Pixel style is an optional F11/P1 addition; it was incorrectly included among remaining P0 work in an earlier outage note. The audit records deliberate implementation limits: explicit point-budget stop instead of lossy simplification, synthesized voices instead of sample assets, retained-point accounting instead of a measured RSS guarantee, remaining direct-English operational messages, and physical/storage/iOS gates. P0 completion is not claimed.

PR #11 merged as 296170b after Actions 40132235358 passed formatter/analyzer, 65 Flutter / 20 JVM / seven native tests and complete offline UI/export inspection, with 0 ms fixture audio offsets. [1.11.0+14 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40132235358/artifacts/12575563930) · [runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40132235358/artifacts/12575684755). Retention (#12) and the Linux process gate (#13) remain in hosted checks.

PR #12 merged as 475515d after Actions 40132937399 passed 68 Flutter / 20 JVM / seven native tests and complete offline UI/export inspection. GitHub required a normal main synchronization; 9e3b36a has an identical complete tree to tested 9858940, verified by git diff. No force push or changed-content test substitution was used. [1.11.1+15 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40132937399/artifacts/12575629626) · [runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40132937399/artifacts/12576950403). The diagnostic gate (#13) and input changes still require their own hosted acceptance.

## Failed-first-save retry guard — 1.11.3+17

The error-state audit found that the editor's initial repository attachment could schedule another autosave whenever a failed first save rebuilt the widget. This retried every half-second with no new user action. The editor now leaves a failed first save in its visible error state; explicit Save/Retry or a subsequent edit can attempt again. Successful saves, normal debouncing, lifecycle saving and guarded Back retain their existing behavior.

The new widget regression fails before the correction (three attempts instead of one after idle waits), then passes with the guard and a successful explicit retry retaining the artwork. Existing editor tests also pass. Full formatter/analyzer, 71 Flutter tests, 20 JVM tests, Android debug build/v2 signature and all 12 Linux process recovery/retry attempts pass locally. Hosted acceptance is pending; this does not establish actual Android disk-full acceptance.

## Active ink and tool switching — 1.11.4+18

Multi-touch review found that selecting another voice with the drawing pointer still down could assign the active stroke to the new voice; changing Draw/Erase could drop the active segment or pending erasure. Draw, Erase and voice selection now finish the valid active canvas operation before changing tools. Subsequent pointer-up is ignored for that already committed operation, so it cannot create a duplicate commit. Future strokes use the new selection.

The multi-pointer regression fails before the fix (the first keys stroke becomes mallet), then passes for voice switching, Draw→Erase, Erase→Draw and undo restoring the original geometry. Existing editor tests pass. Full local formatter/analyzer, 72 Flutter tests, 20 JVM tests, Android debug build/v2 signature and all 12 interruption/recovery/retry attempts pass; hosted acceptance is pending. No native audio/export code changed.

PR #13 merged as cd8d98e after Actions 40134114890 passed the full gate, including 12 real Linux interruptions/recoveries/retries and all seven native tests. PR #14 merged as 3b24dcc after Actions 40134685286 passed 70 Flutter / 20 JVM / seven native tests, all 12 process attempts and complete offline UI/export inspection. Their main synchronizations had identical complete trees to the tested sources. [Verified 1.11.2+16 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40134685286/artifacts/12576288479) · [runtime exports/reports/process proof](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40134685286/artifacts/12576479200). The failed-first-save guard (#15) and active-tool fix await their hosted gates. Physical Android/storage/soak and iOS acceptance remain open.

## Failed-save guard accepted

PR #15 merged as 3ef31f3 after Actions 40135442527 passed 71 Flutter / 20 JVM / seven native tests, all 12 Linux process recovery/retry attempts and the complete offline UI/export inspection. Synchronization 8c06fd1 had an identical complete tree to tested b3042f5. Physical Android storage failure remains untested.

## Active-tool checkpoint accepted — 1.11.4+18

Actions 40136527371 passed the complete product/native/UI/export gate at source 36c27b1: 72 Flutter / 20 JVM / seven native tests and all 12 Linux interruptions/recoveries/retries. Both encoded MP4 fixtures measured 0 ms audio offset; paper and Pixel output matched, and actual UI MIDI passed independent structure/timing inspection. [Installable debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40136527371/artifacts/12577266354) · [Runtime exports, logs, reports and process proof](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40136527371/artifacts/12577302067), retained until 31 October 2026. Download signed into GitHub, unzip and install app-debug.apk.

This final documentation packet updates the physical acceptance checklist, P0 coverage and delivery links. Application, tests, toolchain and check-script contents remain identical to the accepted source; normal main synchronization da718e0 preserves that tree, verified by git diff excluding only README.md and docs/. No force push, store publication or paid infrastructure is used. Next acceptance work is the physical checklist and Android storage/soak coverage; iOS native adapters and Mac/device validation remain separate.

## Operational message resources — 1.11.5+19

Completed the remaining operational UI mappings: editor saves, typed preferences failures, guide/tips actions, export/cancel/share/public-copy states, library errors, name validation, delete prompts, preview-volume semantics and build info. Native or arbitrary exceptions no longer become playback or score-description text. Score complexity retains an actionable repair. User document titles, native destination data and persisted export contents are unchanged.

Targeted retry/localization tests pass. New message tests cover complexity versus unknown/native diagnostics; the existing native preparation failure widget regression now injects a private path and verifies it is not displayed while Play remains retryable. The final full local product gate passed formatter/analyzer, 74 Flutter tests, 20 JVM tests, Android debug build/v2 signature and all 12 Linux process recovery/retry attempts. Hosted acceptance remains pending. No secondary language or physical TalkBack/iOS acceptance is claimed.

## Android force-stop and ten-minute native soak diagnostics

Added a two-phase real Android process check and ten-minute AudioTrack soak; [scope and reports](ANDROID-CLOUD-RECOVERY.md). The host is limited to GitHub Actions, QEMU and the exact emulator/package. It verifies the live diagnostic PID before force-stop and waits for its disappearance. The interrupted preparation cannot report success. Relaunch must match a complete baseline/candidate, preserve baseline bytes, avoid automatic playback, explicitly restart audio and save/reopen an exact retry. A `.tmp` interruption is recorded only when observed, not inferred.

Local analysis, 74 Flutter / 20 JVM tests, debug APK/v2 signature and all 12 Linux interruption/recovery/retry attempts pass. The Dart integration APK and eight-test instrumentation APK compile. Kotlin compilation initially found an Int/Long mismatch for PSS; corrected to Long before the passing build. Hosted execution of force-stop and the 600-second soak is pending; no emulator or physical result is inferred from compilation. Application behavior/version remains 1.11.5+19.

## Compact accessible creation layouts — 1.11.6+20

Expanded layout/semantics checks exposed a save-error overflow at 200% text (124 dp in 320×640) and a keyboard-visible rename dialog with hidden Apply. The editor now bounds and independently scrolls tools and transport/voices around an expanded drawing surface; canvas drags do not move the surrounding page. Naming content scrolls above the keyboard while actions remain reachable. Existing guidance scrolls to its target. Play/Pause tooltips also use resources.

All eight new portrait/landscape × LTR/RTL editor/root-route scenarios pass, including safe areas, failed-save retry, exact retained drawing data, tempo Cancel, export actions, name validation/Cancel with keyboard, root navigation/help/language, labeled taps, Android target sizes and editor text contrast. These are automated layout/semantics checks, not physical TalkBack or a secondary translation. [Layout scope](COMPACT-LAYOUT.md). The final local product gate passed formatter/analyzer, 82 Flutter tests, 20 JVM tests, debug APK/v2 signature and all 12 Linux interruptions/recoveries/retries. Hosted native/UI/recovery/soak acceptance is pending.

## Unavailable share outcome — 1.11.7+21

The final export-state review found that the plugin's unavailable result followed the generic closed-sheet branch. The export sheet and export library now handle dismissed, unavailable and success explicitly. Unavailable explains that sharing is unavailable and the saved export is preserved; successful sheet completion still makes no delivery promise.

The actual library widget regression fails before this fix because the unavailable message is missing. It now exercises all three plugin outcomes, verifies the renamed artifact is still present, then continues through public Save, Delete and Undo. Full local formatter/analyzer, 82 Flutter tests, 20 JVM tests, Android debug APK/v2 signature and all 12 Linux interruption/recovery/retry attempts pass. Hosted acceptance is pending. Physical recipient delivery remains unclaimed.

PR #17 merged as dec0d1c after Actions 40168284365 accepted source 0befcf8: 74 Flutter / 20 JVM / seven native tests, complete offline UI/export inspection and all 12 Linux recovery/retry attempts. Both MP4 audio offsets measured 0 ms. [Verified 1.11.5+19 APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40168284365/artifacts/12589846585) · [Runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40168284365/artifacts/12589997296), retained until 1 November 2026. The later Android process/soak, compact-layout and unavailable-share gates remain pending.

### Android API contract and lint gate

The final minimum-SDK review ran Android lint and found that PublicExportSaver.downloads did not declare its API 29 contract, despite its runtime check and guarded caller. Added RequiresApi(Q), retained the runtime guard and marked the API 29 MediaStore instrumentation case with SdkSuppress(minSdkVersion=29); it still runs on the API 35 gate. Android lint now passes with zero errors. Its two nonblocking suggestions concern the generated drawable-v21 resource qualifier and an optional KTX bitmap factory. The product check now enforces lint alongside the 20 JVM tests. The updated full local gate passes formatter/analyzer, 82 Flutter tests, 20 JVM tests, Android lint, product APK/v2 signature, eight-test instrumentation compilation and all 12 Linux recovery/retry attempts. Hosted acceptance is pending; legacy document-provider physical acceptance remains separate.

The export chooser's app-provided title now uses an Android string resource as well. It retains the English title and system chooser behavior; native diagnostic messages remain internal. The full product/lint/native compilation checks are rerun for this final source.

### Recovery harness startup correction

Run 40169151007 passed 82 Flutter / 20 JVM / eight native tests and the full offline UI/export flow, but its second Flutter-test attachment never published the force-stop ready marker. The artifact log stopped after APK build/install. Its soak report recorded 600,144 ms, 2,397 samples, 150 loops and no sampled clock stall. A temporary read-only inspection job retrieved the evidence; standard CI gates stayed enabled.

The recovery check now launches a diagnostic-only APK directly through Android, separating build/install from a 90-second app-readiness deadline. Real baseline/complete-document/native-clock/no-auto-resume/retry assertions remain mandatory, with explicit failure reports and full startup logs. It does not depend on a debugger/test-driver reconnect between phases. Product lib/main.dart and its normal APK target remain unchanged by this harness correction. Local analysis and the new diagnostic APK compilation are checked; full hosted validation remains pending.

### Hosted UI startup and compiler-memory correction

The corrected source's next run (40172690277) passed all eight native tests, including the 600-second soak, but the creation UI test failed before loading: Dart Development Service could not start and the emulator went offline. The later empty UI-video inspection was a consequence of that load failure, not an encoder result. The diagnostic probe was not reached.

The UI test now connects directly to the VM service with --no-dds and retains all assertions. Kotlin compilation runs in-process; emulator-stage Gradle heaps are capped at 1,536 MB and official Gradle shutdown runs between native, UI and diagnostic stages. Phase build logs and host memory/process snapshots are retained, and full Android logs include startup/crash tags. These changes address observed startup/availability failures without weakening product, native, UI, export, process or soak checks; memory pressure is a suspected contributor rather than a proven root cause. Full hosted acceptance remains pending.

## Final cloud acceptance — 1.11.7+21

PR #18 merged as 6f3800d. PR #20 includes the compact-layout implementation from PR #19, which is superseded rather than independently merged. Final application source `d2e05fdedb4c8264ee9096e65d18fcc97797eeea` passed Actions 40172814635: formatter/analyzer/Android lint, 82 Flutter / 20 JVM / eight native tests, complete offline UI/export inspection, real Android force-stop/fresh-process recovery/explicit playback/exact retry, the 600-second streaming soak and all 12 Linux interruptions/recoveries/retries. Both MP4 audio offsets measured 0 ms; paper/Pixel samples and actual UI MIDI passed independent inspection. The share widget covers dismissed/unavailable/success without delivery promises. Android lint passes with zero errors; two nonblocking suggestions concern a generated resource qualifier and an optional KTX factory.

[Installable APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40172814635/artifacts/12591545602) · [Runtime exports, logs, inspections, Android process/soak reports and Linux proof](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40172814635/artifacts/12591238935), retained until 1 November 2026. Source code/version is unchanged by this final documentation packet. Physical acceptance in ANDROID-ACCEPTANCE.md and iOS adapters/Mac validation remain open; point/history accounting is not a measured device RSS guarantee. No force push, store publication, paid service or personal-phone operation was used.

### Test-runner compatibility resolution

The subsequent CI-only experiment in runs 40174852183/40175089074 is not accepted evidence. Run 40174852183 completed all eight native tests and executed the UI scenario, but failed test loading because `--no-dds` makes the pinned Flutter integration runner request an unsupported VM service stream (`integration_test.VmServiceProxyGoldenFileComparator`). The experiment is reverted in full, restoring the exact application, native configuration, check scripts and recovery probe of the fully accepted d2e05f source. No assertion, gate or test is removed. The final documentation uses that accepted source and its artifacts; a new normal full-gate run will also run on this documentation checkpoint. PR #19's layout changes are included in PR #20, avoiding a separate merge of an earlier failing harness checkpoint.

## Creative expansion engineering and continuation

Source and behavior: CREATIVE-IMPLEMENTATION-PLAN.md; all F01–F25/QA01–QA23 rows in CREATIVE-REQUIREMENT-MATRIX.md. Detailed scope: DOCUMENT-COMPATIBILITY.md, MUSIC-CATALOG.md, MIDI-CATALOG-PARITY.md, GEOMETRY-MEMORY.md, EXPRESSIVE-INPUT.md, BACKGROUNDS.md, PNG-EXPORT.md, VIDEO-FRAME-RATE.md, TRANSLATIONS.md, RATING-FLOW.md, RAW-RECOVERY-EXPORT.md, IOS-IMPLEMENTATION.md. ASSET-PROVENANCE.md records all original synthesis/patterns/templates/gradients/platform glyphs and dependency licensing.

The full-suite first integration run found the old opacity test could no longer reach the expanded panel's slider; opacity was moved ahead of advanced controls, and tests retain transactional Cancel/Apply/Undo/Redo/reopen/no-audio-requeue assertions against the new paper model. A native test compilation error needed an explicit Kotlin Set type. Concurrent source integration briefly referenced recovery strings before generation; all twelve resources were generated before the final gate. Creative UI test semantics cleanup was corrected with try/finally. No failed or unrun check is counted as passing.

Independent review found and fixed MIDI arpeggio note-offs cutting held drawing notes (separate melodic channels14/15, percussion9), raw recovery options missing for undecodable projects, per-frame iOS photo loading/integrity gaps, rating modal/saving guards, and compaction Undo retention. New regression checks exercise those contracts. The current 169-test full run passes. The measured Linux VM history diagnostic retains one 100k-point exclusive previous scene at 14,529,854 accounted bytes under the 20MiB additional-history budget; observed whole-process RSS194.8–329.5MiB/peak372.5MiB includes VM/temp/GC and is not a physical heap/FPS target.

All implementation runs in the selected cloud with the pinned SDK and refreshed proxy/CA, TLS enabled and unchanged HOME. A local /dev/kvm is absent; real Android execution uses the isolated existing hosted workflow. Runtime/job deadlines are increased to40/60minutes to accommodate17native cases, the600second soak, genuine60FPS encoding and expanded offline UI/export inspection; no test/assertion/lint gate is disabled. No force push, PR merge, store publish, personal-phone operation or scheduled task is authorized in this scope.

If interrupted, source these environments and run:

```bash
source /workspace/drawmusic-tools/env.sh
source cloud/env.sh
export DASH__SUPPRESS_ANALYTICS=true
bash scripts/check-android.sh
(cd android && ./gradlew :app:assembleDebugAndroidTest --console=plain)
```

Then review the draft PR's new Actions run, exact17native results and independent exported-file reports. Fix any new failure and push normally, preserving all gates. Run Mac commands from IOS-IMPLEMENTATION.md only on the owner's Mac; do not convert source-only iOS status to accepted. Retained photo storage needs a deliberately reviewed reachability/deletion policy before enabling destructive collection.

Final review also made all twenty template geometries distinct independently of their assigned voices, with a geometry-only uniqueness regression. Native lint found and corrected suspicious Kotlin indentation; photo recovery no longer consumes ready metadata before Dart acknowledgement. The worker verifies synchronous metadata publication, and AndroidX ExifInterface1.4.2 replaces the platform parser. Focused photo/model/panel checks and native source/instrumentation compilation/lint pass after those corrections; the final complete gate is being rerun on this source.

Final local gate passed on the checkpointed application tree: formatter/analyzer,169Flutter/20JVM,lintzeroerrors,APKbuild/v2signature,17-testinstrumentationAPKcompilation and12Linuxinterruption/recovery/retry attempts. RealAndroid17-testexecution,offlineexpandedUI/nativefileinspection/60FPSprofile/600-secondsoak/force-stop remain pending the new hosted run. No physical or iOS native acceptance is claimed.

Local accepted application source `5e0051217f3a775458c4efc081b7d361eb70c947` passed all product checks above; Android lint0errors/11nonblockingwarnings (resource/KTX/lifecyclelint suggestions, not ignored errors). The next checkpoint only records this source/evidence. Reviewable work remains unmerged; hosted17-native/offlineUI/export/60FPS/soak/force-stop acceptance is pending.

The expanded native UI harness snapshots existing artifacts before each export. Final source review found that the first fresh-install export directory can legitimately be absent; the harness now treats that as an empty set before the real export, retaining the assertion that exactly one new file is published. Product code is unchanged by this harness correction.

### First expanded hosted runtime failure — diagnosis pending

Actions 40316035590 at source 2cca4dafb8e5023684e8b40ccdab8abb037336b0 passed the product gate and uploaded APK artifact12647950832. The real Android runtime step failed at12:10:44UTC on26October; subsequent encoded-file inspection remained active, and GitHub returned BlobNotFound for the unfinished job log. This is not a native17-test acceptance or a successful full gate. Exact cause awaits the completed log. This status-only checkpoint preserves all test/lint/runtime assertions and uses the normal workflow concurrency setting; new-source checks remain mandatory. No physical or iOS result is inferred.


### Expanded runtime diagnosis and gallery regression

Run40316035590 actually passed all17native cases, with no skips/failures. The600second soak recorded600162ms and2396samples. The640×800/60FPS codec profile passed with317real encoded samples,16666–16667µs steps,19.272s elapsed and65292KiB peak-sampled whole-process PSS. These are emulator observations, not physical performance. The original offline creation/save/reopen/four-format export flow also completed before the expanded gallery step.

The overall UI test then failed at creation_loop_test.dart292: its Three streams tap was still at y2002 in a731dp viewport because the scroll's layout had not been pumped. The harness now explicitly aligns/reveals controls, waits for layout and asserts hit-testability; a new real411×731 gallery-navigation regression passes. No warning or assertion is suppressed. Shipping app code is unchanged. The full local suite is rerun with170tests and the new hosted source must finish the entire expanded UI/inspection/recovery gate before acceptance.

The post-failure inspector stage stalled fetching FFmpeg packages from Ubuntu's Azure mirror. Inspector preparation now runs before emulator startup, uses Ubuntu's official HTTPS archive with existing signature/keyring validation, bounds package operations and keeps all file-validation commands. No lint/native/output gate is disabled. The previous failed run was superseded through the standard concurrency setting to retrieve its log; it is not reported as a successful full gate.

The corrected gallery harness and new phone-navigation regression now pass the full170-test Flutter suite; formatter/analyzer are clean. Preparation installs Python3.12 before pinned NumPy/Mido so inspector wheels and interpreter agree. The new inspector script's shell syntax and workflow YAML parse pass. All17 native tests/60FPS/soak passed on the preceding shipping-code-equivalent source, but the entire expanded UI/independent-inspection/recovery run still must complete on the corrected harness before full cloud acceptance.


### Expanded media inspection passed; language harness corrected

Run [40324186739](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40324186739), at `e194f7963004e1f7bb36d69d421737e36b04738c`, passed the full product gate (170 Flutter/20 JVM tests, analyzer, lint, debug APK and Linux recovery checks), all 17 Android native tests, the ten-minute soak and compact 60 FPS profile. Independent inspection passed for both original and expanded UI WAV/MIDI/PNG/MP4 outputs, including root, scale, accompaniment channels and gradient agreement. Runtime evidence is artifact12653746483; the normal app APK is artifact12651232120.

The combined UI test failed only at its final language preference assertion: it tapped Japanese and immediately tapped Apply without pumping the selection rebuild, so Apply still saved English. The existing fourteen locale/resource widget cases already wait for this rebuild and pass. The native integration harness now also pumps the selection, asserts that the Japanese tile is selected, then applies it. All fourteen cases and analysis pass locally. No product code or acceptance assertion is removed; full current-source cloud acceptance and the downstream Android force-stop/recovery probe remain pending.

## Final creative cloud acceptance

Actions [40329847034](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034) accepted application/test/check-script source `c721ce6d508ebde63b318859e3931342600f79f6`. All 17 actual Android tests passed, including real 60 FPS timestamps/codecs, PNG/native public copying, EXIF/import integrity, thirteen-color/gradient/photo raster cases and the 600-second streaming test. The actual offline UI creates, plays, saves/reopens and exports both the original and expanded root/scale/accompaniment/gradient project; independent parsers verify its MIDI part lifetimes/layers and PNG/video visual agreement. The direct-APK recovery probe verifies a different process, complete revision, preserved baseline, no automatic playback and exact explicit retry. This is new-source evidence; older baseline results are not reused.

[Debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034/artifacts/12654848499) · [Complete runtime evidence](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40329847034/artifacts/12657186456). Exact 60 FPS elapsed/PSS and file timing values are in the uploaded reports; emulator observations do not establish physical hardware performance. iOS source and its three portable IPC checks remain separate from unrun Swift/XCTest/native integration. Human translations, actual receiving apps/camera/TalkBack/routes/storage and safe asset-retention follow-up remain as listed. PR #21 was draft/unmerged at that historical checkpoint and is now merged at a7c3670. No store publish, paid service, personal-phone operation, force push or scheduled continuation was performed.

### Exact observed expanded runtime results

Accepted run 40329847034: all 17 native tests completed with zero skips/failures; the actual original/expanded Flutter UI test passed. The AudioTrack soak ran 600,251 ms, with 2,398 status samples and 150 loops, without a sampled progress stall. Compact 640×800/60 FPS encoded 317 samples with 16,666–16,667 µs steps, 5,283,333 µs video and 5,270,929 µs audio duration (12.404 ms difference), 16.796 s export elapsed and 66,110 KiB peak-sampled process PSS. Native renderer bitmap/pixel-array accounting is 4,096,000 bytes. These are isolated emulator codec/clock observations, not physical-device performance or a Flutter UI memory guarantee. HD 60 FPS remains unprofiled.

Independent FFmpeg correlation measured 0.0 ms audio offset for the HD 30 fixture, compact 30 original UI, compact 60 fixture and compact 30 expanded UI outputs. The expanded MIDI contains 42 drawing notes, 4 bass notes, 16 arpeggio notes and 26 percussion notes, balanced through 3,840 ticks; parsed F♯/Lydian and accompaniment channel/velocity assertions passed. PNG 1080×1350 and actual MP4 gradient corner pixels agreed within the codec tolerance.

The standalone diagnostic APK force-stopped PID 6134 and verified fresh PID 6315, recovered complete revision 0, unchanged baseline bytes, no automatic playback, successful explicit playback and exact revision 3 save/reopen retry. The probe does not guarantee a temporary write was interrupted; Linux's 12 staged interruption cases supply separate partial-write coverage. All native/runtime/inspection/upload steps and the complete job concluded success. Normal product APK artifact 12654848499 was uploaded before either diagnostic APK was built.

### First current-source hosted runtime setup failure

Run40480108092 at584cfb1 passed the complete product gate (240Flutter/24JVM/lint/APK/signature/Linux recovery) and15actualpureSwift tests. Runtimefailed immediately after emulator boot, before any instrumentation/UItest, at `svc data disable`: `cmd: Can't find service: phone`, exit20. The following inspector correctly failed because no runtime files had been produced. This is not a native/HD60 acceptance pass.

The runtime bootstrap now waits up to180seconds for QEMU identity, boot and package/activity/Wi-Fi/phone/connectivity service availability, then still requires both network-disable commands to succeed. It records a passed:false report and fails if readiness/offline setup cannot be established. No product test, offline requirement or output assertion is skipped. New current-source hosted execution remains pending.


## Accepted 27 October review fixes

Accepted source `76c0ee2ff0b5d03f1b22a5ff4149d272d20a821b`, [Actions 40482959273](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273): formatter/analyzer, **240 Flutter / 24 JVM / 20 native Android / 15 pure Swift tests**, Android lint, actual 2.0.1+23 APK/v2 signature, all 12 Linux interruption/retry cases, full offline original/expanded creation/exports, independent actual-packet/full-stream/A-V inspection, HD and compact 60 FPS, actual HOME cancellation/same-process foreground, ten-minute native soak and Android force-stop/fresh-process exact retry pass. [Debug APK](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12725075870) · [Android runtime reports/exports](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12725956006) · [Portable Swift proof](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40482959273/artifacts/12723034260), retained until 3 November 2026.

Each finding is mapped to its actual regression/source and before/after evidence in REVIEW-FIX-PLAN-2026-10-27.md. PR #21 is already merged; review PR #22 remains draft/unmerged. No merge actor is inferred. The exact HD60 profile and HOME/foreground reports describe emulator scope, not physical-device performance. Safe cleanup uses seven-day asset age plus seven staged days, no schema migration or ID changes, and retains all recoverable/deleted/unknown/pending references. Apple-framework native execution and device/human checks remain pending as documented.

### Exact accepted 2.0.1+23 emulator observations

All 20 actual Android tests passed with no skipped/failed cases. The startup readiness check confirmed package/activity/Wi-Fi/phone/connectivity services and required offline configuration before testing. The actual offline UI passed original/expanded creation, playback, save/reopen, all four export formats, Japanese Apply and real HOME/foreground cancellation of a requested HD60 job without publishing partial files or changing the document. The host driver confirmed the same process after foreground restoration.

HD 1080×1350/60 FPS: 317 encoded samples, 16,666–16,667 µs steps, 5,283,333 µs video / 5,270,929 µs audio duration (12.404 ms difference), 40.754 s export elapsed, 74,012 KiB peak-sampled native process PSS and 11,664,000 bytes of reusable renderer bitmap/pixel-array accounting. Compact 60 FPS: 317 samples, 19.362 s elapsed and 63,533 KiB peak-sampled native process PSS. These are isolated emulator codec observations, not complete Flutter-editor memory, physical-device FPS or thermal guarantees.

Independent FFmpeg packet/full-stream inspection and PCM correlation passed for HD30, compact30, compact60, HD60 and expanded compact30 outputs, with 0.0 ms correlated audio offset for these fixtures. Expanded MIDI parsed 42 drawing / 4 bass / 16 arpeggio / 26 percussion notes, balanced through 3,840 ticks; PNG/MP4 gradient pixels agreed. The native AudioTrack soak lasted 600,187 ms with 2,397 samples, 150 loops and no sampled progress stall.

Force-stop verification stopped PID 7635 and resumed in PID 7797, recovered complete revision 0, preserved baseline bytes, did not auto-play, then explicitly played and exactly saved/reopened revision 3. The normal 2.0.1+23 APK was uploaded before diagnostic APKs were built. Physical power loss/low storage is not inferred. Hosted pure Swift used Swift 6.4/Linux (15 cases); local verified-toolchain checks used Swift 6.1.2. Apple-framework typechecking and native iOS execution remain unrun.
