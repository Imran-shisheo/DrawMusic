# Development status

Updated: 2026-10-24, Asia/Dubai. Branch: `codex/android-creation-loop`.

| Gate | Current evidence |
|---|---|
| Setup restoration | Bundle hashes/size/source commit verified by restore_bootstrap.py; reviewed normal setup committed and pushed to main as 3c83e1a, without force. |
| M0 | Complete: pinned Flutter 3.47.2 root Android app, Riverpod/go_router, Home/Drafts/Settings/Editor, original theme, empty/error states. Product navigation test, formatter, analyzer, APK compilation and APK v2 signature verification passed at 65cbc69. |
| M1 | Core implemented: normalized one-pointer strokes/dots, three instrument-linked colors, swept eraser with segment splitting, undo/redo/confirmed clear, bounded history. Geometry/history and canvas interaction checks pass. Stress/smoothing tuning pending. |
| M2 | Score compiler + original three-voice PCM renderer + native Android AudioTrack clock/transport/focus adapter implemented. Determinism, speed/direction invariance, vertical chords, budgets and non-silent PCM tests pass. Device audibility/latency is untested. Edits currently pause; loop/beat-boundary changes remain. Not an accepted M2 exit. |
| M3 | Core implemented: checksummed atomic local revisions, autosave/Save, guarded Back, thumbnails/drafts, reopen, corruption fallback/stale-save protection. Persistence tests and widget save–leave–reopen/failure recovery pass. Full library management/process-death QA pending. |
| M4 | Partial: frozen-snapshot MIDI/WAV files, cancellation/error states, explicit share_plus native share adapter. mido 1.3.3 parses fixture MIDI (SMF0, 480 PPQ, balanced events, 4.0 s); Python wave/ffprobe decode WAV (PCM16, mono, 44100 Hz, 231525 frames, 5.25 s, nonzero RMS). MP4 is not implemented; native sharing untested on device. |
| M5 | Pending: persisted settings/onboarding, full accessibility/localization, large scenes/soak, audio lifecycle and physical sharing checks. |

Final product check: `bash scripts/check-android.sh` passed formatter (26 lib/test files unchanged), analyzer (no issues), all 19 meaningful tests, and `flutter build apk --debug`. The expanded APK includes the native Android adapter and original icon; `apksigner verify --verbose` passed APK Signature Scheme v2 with one debug signer. Tests include the Play/Pause port path and 320 dp / 200% text after fixing a discovered toolbar overflow. Tests using a fake engine/repository are UI coordination evidence, not device audio evidence. Independent on-disk persistence/export tests use real files.

All implementation and verification ran in the selected cloud environment, using /workspace/drawmusic-tools/env.sh and refreshed runtime proxy/CA configuration. HOME was not changed; TLS verification remains enabled. Environment smoke-app results are excluded from product evidence. Doctor warns about the pinned detached channel, unknown license-status probe, absent Chrome/devices and blocked optional maven.google.com/cocoapods probes. Actual product builds succeeded. Gradle installed required API 35 and CMake 3.22.1 for plugins using the previously accepted SDK license; API 36/NDK remain pinned.

No Android emulator or physical device is available; no iOS build/test is claimed. Assets are original synthesis/geometry/vector artwork plus licensed Material icons; research media is not bundled. No accounts, backend, ads, purchases or paid service were introduced.

Next: native video export and transport boundary scheduling; retain honest M2/M4 gate status until their device/output evidence exists. See IMPLEMENTATION-NOTES.md for exact limitations and ASSET-PROVENANCE.md for shipping asset sources.
