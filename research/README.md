# Draw Music research handoff

Research date: 23 October 2026. Installed reference: `com.banix.drawsound.drawmusic`, version 2.0 (11). Device: Nothing A059P, Android 16/API 36, portrait 1080 × 2392 px at 420 dpi. No Flutter app has been implemented.

## Start here

- [Complete PRD](../PRD.md): 25 feature requirements, 26 screen families, complete navigation flow (§4.2), design system, drawing/audio contract, Flutter architecture and release QA.
- [Visual reference gallery](index.html): curated meaningful states and playable video/audio exports.
- [Screen inventory](../.archify/tree-draw-music-screens-20261023-164500/screen-inventory.html): expandable grouping of all 26 screen families. Grouping links are not route transitions.
- [Screen catalog](SCREEN-CATALOG.md): verified interpretation of raw screenshots, including corrections to misleading early filenames.
- [Video index](VIDEO-INDEX.md): repeatable shape experiments, timestamps, limitations and excluded runs.
- [Measurement notes](INTERACTION-MEASUREMENTS.md): verified control bounds and screenshot-derived visual estimates.
- [Research log](RESEARCH-LOG.md), [evidence scope](evidence/research-scope.md) and [source register](SOURCE-REGISTER.md): provenance, unknowns and primary documentation references.

## Drawing-to-music findings

Drawings were silent until Play. The scan moves left to right. Horizontal occupancy relates to musical time and vertical position relates to pitch; reversing a same-geometry stroke and varying its drawing duration did not establish a changed loop in the tested cases. Circle, vertical and zigzag tests show changing/multiple pitches. The exact source algorithm remains unknown.

The known two-line project was saved, reopened and exported to MIDI/WAV/MP4 offline. Its MIDI independently contains simultaneous notes 72 and 60 at velocity 100, with an 8-beat loop at 120 BPM. This validates that fixture, not the original app’s general quantization algorithm. [MIDI inspection](experiments/source-midi-inspection.json), [media inspection](evidence/export-verification.json).

## Evidence layout

| Path | Contents |
|---|---|
| `screenshots/` | Raw 1080 × 2392 PNGs; names describe capture intent, catalog is authoritative |
| `evidence/` | UI hierarchy XML, device/package configuration, timestamps, color measurements and review contact sheets |
| `experiments/` | Gesture/timing JSON, playback audio, descriptive spectral analysis and own generated source exports |
| `videos/` | Original scrcpy recordings and source-exported MP4; preview MP4s are transcoded viewing copies |
| `diagrams/navigation.mmd` | Complete navigation graph copied from PRD section 4.2 |
| `*/invalid/` | Interrupted or uncontrolled runs excluded from behavioral conclusions |

## Scope and device state

Existing app data was preserved. Two preexisting drafts were not edited; opening/exiting changed list order. Research drawings/exports remain separately identifiable. The human granted camera permission and took a photo during exploration; cropper captures are explicitly qualified. No transaction or entitlement unlock was completed. Ads interrupted several tests; those recordings are quarantined. Native share sheets were canceled without selecting a recipient.

Wi-Fi and mobile data were both enabled before the authorized offline pass and both restored to enabled afterward. [Restoration evidence](evidence/network-after-restoration.txt). No device action remains pending.

The `.py` scripts are research capture/analysis aids. They are not application code. Avoid rerunning gesture automation unattended while ads or human inputs can change the screen. No Flutter project, Dart source, dependency installation or app build was created.

## Handoff verification

The final audit checked 268 local Markdown/HTML references with no missing targets, 25 unique feature IDs, 26 unique screen IDs and equality of the PRD navigation graph with its `.mmd` copy. It found no Dart files or Flutter `pubspec.yaml`. The screen inventory passed automated schema, delivery, provenance and real-browser checks; its layout was not separately visually reviewed. The gallery’s first viewport was visually inspected in headless Chrome; its screenshot is retained. Source WAV/MP4 metadata and the parsed MIDI are saved independently. These checks verify the research handoff, not a Flutter build or achieved future-app performance.

[Handoff check report](evidence/handoff-checks.json) · [Gallery review screenshot](evidence/gallery-review.png).
