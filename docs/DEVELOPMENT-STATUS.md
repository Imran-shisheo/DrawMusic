# Development status

Updated: 2026-10-24, UTC. Branch: `codex/live-loop-video` (continuation after the owner merged PR #1).

| Gate | Current evidence |
|---|---|
| Setup restoration | Bundle hashes/size/source commit verified by restore_bootstrap.py; reviewed normal setup committed and pushed to main as 3c83e1a, without force. |
| M0 | Complete: pinned Flutter 3.47.2 root Android app, Riverpod/go_router, Home/Drafts/Settings/Editor, original theme, empty/error states. Product navigation test, formatter, analyzer, APK compilation and APK v2 signature verification passed at 65cbc69. |
| M1 | Core implemented: normalized one-pointer strokes/dots, three instrument-linked colors, swept eraser with segment splitting, undo/redo/confirmed clear, bounded history. Geometry/history and canvas interaction checks pass. Stress/smoothing tuning pending. |
| M2 | Score compiler + original three-voice PCM renderer + native Android AudioTrack clock/transport/focus adapter implemented. Determinism, speed/direction invariance, vertical chords, budgets and non-silent PCM tests pass. The owner confirmed audible playback of 1.0.1+2. The new streaming adapter passes API 35 native clock/boundary/pause tests; physical audibility/latency/interruption retesting remains. Not an accepted M2 exit. |
| M3 | Core implemented: checksummed atomic local revisions, autosave/Save, guarded Back, thumbnails/drafts, reopen, corruption fallback/stale-save protection. Persistence tests, widget save–leave–reopen/failure recovery and the actual Android save/reopen UI flow pass. Rename/duplicate/confirmed soft-delete/Undo and recovery notices are implemented. Process-death QA remains pending. |
| M4 | Partial: frozen-snapshot MIDI/WAV files, cancellation/error states, explicit share_plus native share adapter. mido 1.3.3 parses fixture MIDI (SMF0, 480 PPQ, balanced events, 4.0 s); Python wave/ffprobe decode WAV (PCM16, mono, 44100 Hz, 231525 frames, 5.25 s, nonzero RMS). MP4 native adapter is implemented in version 1.2.0+4, with API 35 native/UI execution and independent MP4 timing verification passed in 1.2.1+5; native recipient sharing remains untested on a physical device. |
| M5 | Pending: persisted settings/onboarding, full accessibility/localization, large scenes/soak, audio lifecycle and physical sharing checks. |

Final product check: `bash scripts/check-android.sh` passed formatter (26 lib/test files unchanged), analyzer (no issues), all 19 meaningful tests, and `flutter build apk --debug`. The expanded APK includes the native Android adapter and original icon; `apksigner verify --verbose` passed APK Signature Scheme v2 with one debug signer. Tests include the Play/Pause port path and 320 dp / 200% text after fixing a discovered toolbar overflow. Tests using a fake engine/repository are UI coordination evidence, not device audio evidence. Independent on-disk persistence/export tests use real files.

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
