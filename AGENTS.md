# DrawMusic development instructions

## Authorized scope

Latest owner authorization, 26 October 2026: implement the creative expansion in docs/requests/CREATIVE-EXPANSION-2026-10-26.txt, including P1 creative tools, specified offline P2 and feasible iOS source. All creative features are free in this build. Leave reviewable draft PRs UNMERGED; this overrides earlier merging permission below. Ads/reward SDKs, billing/subscriptions, accounts, servers/uploads, paid services, cloud collaboration, store publication, force pushes, personal-phone operations and scheduled continuations are excluded. Use docs/CREATIVE-IMPLEMENTATION-PLAN.md and CREATIVE-REQUIREMENT-MATRIX.md; new source needs new evidence.

The owner authorized Android Flutter development in Codex Cloud on 2026-10-24. The earlier research-only instruction applied to the completed research phase. iOS compilation, signing and device testing will be performed by the owner on a local Mac; retain portable Dart code and platform boundaries. Do not claim iOS validation from a Linux run.

Read PRD.md, docs/ROADMAP.md and cloud/FIRST-TASK.md. ScribbleSong is the PRD's provisional original product name; DrawMusic is the repository name. Use `com.imranshisheo.scribblesong` as the development application identifier; final store naming is a later owner decision.

## Product and evidence

Follow the PRD's P0 requirements; distinguish observed source behavior from proposed product rules. Reference screenshots/audio are research evidence only and must never be packaged as app assets. All shipping templates, icons, illustrations and audio must be original or explicitly licensed with provenance. The exact source algorithm is unknown: implement the documented deterministic geometry-to-score proposal.

Prioritize a working Android creation loop. Do not use fake successful save/export states, placeholder silent playback or inaccessible paid features as evidence that a milestone is complete. Do not introduce accounts, servers, ads, purchases or cloud content upload into the MVP without a separate owner request.

## Structure

Bootstrap the Flutter app at repository root without overwriting PRD.md, research/, cloud/, scripts/ or .github/. Use Flutter 3.47.2 (revision in cloud/toolchain.env), Dart from that SDK, Riverpod and the PRD's feature-first architecture. Keep Project/Stroke/Score, quantization, history and serialization testable without widgets or native plugins. Keep pointer preview and playback cursor off the full-project Riverpod update path. Audio clock owns playback timing. Engine/export adapters implement explicit ports.

## Cloud operation

Run `bash scripts/setup-cloud-android.sh` in Linux x86_64, then source `cloud/env.sh` before later commands. If SDK license acceptance is required, ask the owner to approve the specific terms before setting DRAWMUSIC_ACCEPT_ANDROID_LICENSES=1. Never paste credentials into source, logs, issues or prompts. Use environment configuration for services, if ever needed. No paid infrastructure is required for this local-first MVP.

Make progress through the roadmap in order while within the active task. Preserve a short status record in docs/DEVELOPMENT-STATUS.md with completed work, exact checks, known failures and the next step. A task completion does not schedule the next task automatically. Commit usable checkpoints to a development branch and open a draft PR when the milestone is reviewable. The owner authorized continued feature development and merging repository PRs on 2026-10-24. Open a PR per usable feature checkpoint, continue the next feature without waiting for a reply, and merge only after relevant checks pass. Do not publish to an app store or start paid services.

## Checks and handoff

Run `bash scripts/check-android.sh` once an app exists. Add meaningful tests for score mapping, vertical polyphony, direction/speed invariance, undo/redo, save/reopen and MIDI/WAV encoding as those features are implemented. Include widget/integration tests that catch route/save failures, not tests that only mirror code. Keep pubspec.lock committed for this application. CI uploads a debug APK for phone testing. A successful setup-only job is not an application test pass.

Document physical audio latency, interruption handling, audible timbre, background lifecycle and real sharing as needing device testing until actually tested. Do not report omitted tests as passing. Do not modify the connected personal phone from a cloud environment. Update the README with how to download/install the test APK and how the owner can run iOS locally.
