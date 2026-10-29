# Actual graphite implementation previews — 29 October 2026

These are actual rendered Flutter widgets from the approved graphite/orange
implementation, using the bundled production fonts/icons and deterministic
project/audio fixtures. They are not ImageGen mockups or Stitch exports.
The enclosing product commit identifies their source; the strict visual gate
re-renders that source. Capture harness: `test/ui_visual_capture_test.dart`,
`UI_CAPTURE_IMMERSIVE=true`. No pixel postprocessing was applied.

| Render | Purpose |
|---|---|
| [Home](01-home-immersive-dark-phone.png) | Actual project preview, caption, creation action and retained dock |
| [Drafts](02-drafts-dark-phone.png) | Connected Drafts/Exports selector and real saved fixtures |
| [Editor](06-editor-immersive-dark-phone.png) | Stable 4:5 document with joined transport and tools |
| [Export](09-export-immersive-dark-phone.png) | Four formats, actual artwork preview and visible transparency setting |
| [Light Home](10b-home-cool-light-phone.png) | Light stone material variant, same document colors |
| [French 320 dp / 200%](13-editor-compact-fr-large.png) | Initial transport captions and adaptive controls |
| [Short landscape](21-editor-landscape.png) | Full transport captions and stable document geometry |

[Before implementation](../graphite-baseline-2026-10-28/README.md) and
[approved original inputs](../../../design/approved/2026-10-28/) are separately
labeled. `reference-diffs.json` records the intentional full-layout changes
to eight reviewed references; strict comparison thresholds remain unchanged.
Their previous pixels remain available in Git history. This Linux update does
not resolve the previously reported eight Mac-specific golden discrepancies.

The full fixture capture covers 76 states. Animation is frozen deterministically;
safe-area/keyboard variants use declared simulated insets. These PNGs establish
rendered layout, not native behavior, continuous motion, physical frame pacing,
audibility, iOS compilation or user-device acceptance. Original real-time owned
emulator recordings and source-mapped profile results are separate pending work.
