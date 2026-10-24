# Development status

Updated: 2026-10-24, UTC. Branch: `codex/live-loop-video` (continuation after the owner merged PR #1).

| Gate | Current evidence |
|---|---|
| Setup restoration | Bundle hashes/size/source commit verified by restore_bootstrap.py; reviewed normal setup committed and pushed to main as 3c83e1a, without force. |
| M0 | Complete: pinned Flutter 3.47.2 root Android app, Riverpod/go_router, Home/Drafts/Settings/Editor, original theme, empty/error states. Product navigation test, formatter, analyzer, APK compilation and APK v2 signature verification passed at 65cbc69. |
| M1 | Core implemented: normalized one-pointer strokes/dots, three instrument-linked colors, swept eraser with segment splitting, undo/redo/confirmed clear, bounded history. Geometry/history and canvas interaction checks pass. Stress/smoothing tuning pending. |
| M2 | Score compiler + original three-voice PCM renderer + native Android AudioTrack clock/transport/focus adapter implemented. Determinism, speed/direction invariance, vertical chords, budgets and non-silent PCM tests pass. The owner confirmed audible playback of 1.0.1+2. The new streaming adapter passes API 35 native clock/boundary/pause tests; physical audibility/latency/interruption retesting remains. Not an accepted M2 exit. |
| M3 | Core implemented: checksummed atomic local revisions, autosave/Save, guarded Back, thumbnails/drafts, reopen, corruption fallback/stale-save protection. Persistence tests and widget save–leave–reopen/failure recovery pass. Rename/duplicate/confirmed soft-delete/Undo and recovery notices are implemented. Process-death QA remains pending. |
| M4 | Partial: frozen-snapshot MIDI/WAV files, cancellation/error states, explicit share_plus native share adapter. mido 1.3.3 parses fixture MIDI (SMF0, 480 PPQ, balanced events, 4.0 s); Python wave/ffprobe decode WAV (PCM16, mono, 44100 Hz, 231525 frames, 5.25 s, nonzero RMS). MP4 native adapter is implemented in version 1.2.0+4, with Android emulator/runtime verification pending; native sharing remains untested on a physical device. |
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
