# Development status

Updated: 2026-10-24, Asia/Dubai. Branch: `codex/android-creation-loop`.

| Gate | Current evidence |
|---|---|
| Setup restoration | Bundle hashes/size/source commit verified by restore_bootstrap.py; reviewed normal setup committed and pushed to main as 3c83e1a, without force. |
| M0 | Complete: pinned Flutter 3.47.2 root Android app, Riverpod/go_router, Home/Drafts/Settings/Editor, original theme, empty/error states. Product navigation test, formatter, analyzer, APK compilation and APK v2 signature verification passed at 65cbc69. |
| M1 | Core implemented: normalized one-pointer strokes/dots, three instrument-linked colors, swept eraser with segment splitting, undo/redo/confirmed clear, bounded history. Geometry/history and canvas interaction checks pass. Stress/smoothing tuning pending. |
| M2 | Score compiler + original three-voice PCM renderer + native Android AudioTrack clock/transport/focus adapter implemented. Determinism, speed/direction invariance, vertical chords, budgets and non-silent PCM tests pass. Device audibility/latency is untested. Version 1.1.0+3 queues loop/beat-boundary changes; its new streaming output still needs device retesting. Not an accepted M2 exit. |
| M3 | Core implemented: checksummed atomic local revisions, autosave/Save, guarded Back, thumbnails/drafts, reopen, corruption fallback/stale-save protection. Persistence tests and widget save–leave–reopen/failure recovery pass. Rename/duplicate/confirmed soft-delete/Undo and recovery notices are implemented. Process-death QA remains pending. |
| M4 | Partial: frozen-snapshot MIDI/WAV files, cancellation/error states, explicit share_plus native share adapter. mido 1.3.3 parses fixture MIDI (SMF0, 480 PPQ, balanced events, 4.0 s); Python wave/ffprobe decode WAV (PCM16, mono, 44100 Hz, 231525 frames, 5.25 s, nonzero RMS). MP4 is not implemented; native sharing untested on device. |
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
