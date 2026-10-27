# UI/UX redesign implementation and acceptance

27 October 2026. Source: [complete owner brief](requests/UI-UX-REDESIGN-2026-10-27.txt), supplemented by the owner's naming authorization. This is an implementation ledger, not a completion claim.

## Baseline and dependency

Branch `codex/ui-redesign-2026-10-27` starts at `cddebbd56bf5b4d53b7774fcdf7718e562720c06`, the documentation checkpoint of draft, unmerged PR #22. Its application tree equals accepted source `76c0ee2`, verified by Actions 40482959273. The redesign must retain all eraser, background, thumbnail, cleanup, audio and HD60 fixes. Its draft PR will be stacked on `codex/review-fixes-2026-10-27`; main alone is not an adequate baseline.

## Direction and review findings

Create a calm musical sketchbook: warm ivory, forest text, restrained teal actions and small sage/lavender/coral accents. Use an original continuous line becoming a wave, never competitor media. Keep artwork colors, rendering, geometry and audio unchanged. The owner selected Doodimo after considering alternatives. Use one centralized brand definition, original line-to-wave assets and the planned store title Doodimo: Draw Music; no store publication or legal/name-reservation claim.

Current source exposes a long Home introduction before the creation action, simultaneous editor settings in two scroll regions, thirteen instrument chips, and a long export sheet containing every format. Navigation retains four branch navigators but lacks a deliberate content transition. These findings guide the redesign; actual pre-change widget captures and emulator evidence must be inspected separately before visual acceptance.

## Implementation sequence and ownership

| Phase | Work | Current evidence/status |
|---|---|---|
| Baseline | Real widgets, loaded fonts/icons, realistic fixture data; actual emulator captures | Capture harness in progress; not yet visually accepted |
| Foundations | Semantic theme, licensed bundled fonts/fallbacks, spacing/type/component/motion tokens, original line motif | In progress |
| Vertical slice | Home hierarchy, retained animated navigation, stable canvas-focused editor and voice/music choosers | Pending implementation |
| Creative surfaces | Drafts/Exports, intent-led export, visual paper/crop workflow | Pending implementation |
| Support surfaces | Grouped Settings, language, welcome/help, coachmarks, recovery/rating | Pending implementation |
| Accessibility | Light/dark, all 12 locales, forced RTL, 320 dp/200%, tablets/landscape/keyboard, contrast and targets | Pending new-source checks |
| Runtime delivery | Full product checks, actual emulator recordings, measured profile frame timings, exact-source APK/draft PR | Pending new-source checks |

Parent owns shared tokens/components, Home/navigation, integration and review. Existing independent agents own editor, library/export, backgrounds, support screens, baseline/font coverage, and emulator/profile harness respectively. No overlapping commits or branch changes by agents.

## Functional invariants

Retain every branch navigator and scroll/section state; animation must not dispose branches. Keep document/controller/audio/export-job ownership intact across routes and sheets. Canvas placement and pointer normalization stay stable during decorative ticks; do not animate the live canvas geometry. Instrument changes finish active gestures safely. Derive playback visuals only from real audio status. Ambient graphics live outside document renderers, ignore input/semantics, and pause when hidden/backgrounded or reduced motion is active.

## Acceptance evidence still required

Before/after captures must cover Home; editor empty/drawn/playing and music/voice controls; paper/crop; Drafts/Exports; export selection/progress/ready/error; Settings/language/help; and representative dark/compact/large-text/tablet cases. Record actual cloud emulator navigation, tabs, voice/playback, sheet, export and reduced-motion flows. Collect profile UI/raster frame timings under transitions and drawing load, including actual sample counts and over-budget frames. Widget snapshots do not prove native performance. Mac compilation, physical sound/routes, screen readers and receiving applications remain separate acceptance work.

Run formatter, analyzer, meaningful existing/new tests, `bash scripts/check-android.sh`, signature verification and relevant actual runtime checks. Preserve functionality tests; update changed presentation expectations rather than deleting coverage. Report new source independently of the accepted pre-redesign gate.

## Corrective art direction — first iteration rejected

The owner rejected the initial pale-card preview as too basic. It is retained under `docs/ui/progress` as rejected comparison evidence; its passing technical checks and golden pixels do not constitute design approval.

The active direction is **Doodimo as a pocket creative instrument / editorial mixtape**: open Home composition around real saved/template artwork, paper sleeves with titles outside; one compact deep-ink four-key dock with an animated selected marker; original 24-unit control glyphs; Space Grotesk display typography over legible Nunito/Noto UI text; a tactile joined editor tool rail and transport console; connected format selection and a real-artifact export ticket. Warm paper, deep ink, lavender and one controlled lime accent establish hierarchy without universal outlined containers, blur or false audio visualizers. Preserve every functional, accessibility, gesture, audio and recovery fix already verified. New renders must materially differ before exhaustive acceptance resumes.
