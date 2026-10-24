# Android development roadmap

Authorized 2026-10-24. Source of requirements: [PRD](../PRD.md). Cloud target is Android; iOS validation stays on the owner's Mac. Work through these gates in order and update DEVELOPMENT-STATUS.md.

| Milestone | Deliverable | Exit evidence |
|---|---|---|
| M0 — Toolchain and shell | Root Flutter project, Riverpod/navigation, original theme, Home/Drafts/Settings/Editor routes, visible empty/error states | Formatter, analyzer, meaningful navigation test, installable debug APK |
| M1 — Editable drawing | Normalized strokes, original instrument-linked colors, eraser, undo/redo/reset and resilient project history | Geometry/history tests and canvas interaction test |
| M2 — Score and audible playback | Deterministic 8-beat geometry mapping, pentatonic quantization, horizontal duration, vertical chords, native audio adapter and synchronized transport | Fixture/invariant tests, actual audible playback on a device; clearly qualify unmeasured latency |
| M3 — Save and recovery | Transactional local projects, recognizable thumbnails, reopen, safe Back/save and interruption recovery | Persistence/migration tests and save–reopen integration test |
| M4 — Export and sharing | MIDI, WAV and MP4 adapters from the same immutable score/document snapshot, cancel/error/success and native share | Parsed MIDI fixture, decoded WAV and inspected MP4 with real duration/audio; APK for physical share checks |
| M5 — Hardening | Accessibility, offline behavior, focus/lifecycle, large scenes, original asset manifest | PRD P0 QA coverage, device test notes, known-risk list and reviewable PR |

P1 accompaniment, extended catalogs, photo/camera/cropping, PNG, premium and ads follow core reliability and require their own tasks. Do not reduce MIDI/WAV/MP4 parity silently; report native-export feasibility failures as blockers with evidence.

The PRD's proposed score policy is the starting contract. Implement it first with deterministic fixtures; changes to it must update the contract and tests together. Source captures cannot prove the proprietary algorithm.
