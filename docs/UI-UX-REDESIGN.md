# UI/UX redesign implementation and acceptance

**ACTIVE REPLACEMENT:** [immersive audiovisual-playground brief](requests/IMMERSIVE-REDESIGN-2026-10-27.md). The owner rejected BOTH earlier iterations, including the editorial-mixtape palette/icons. The historical design directions below do not constrain the new aesthetic. Preserve their verified functional/a11y fixes. All major surfaces now use the implemented replacement. Final-source native, recording, responsive-pixel and profile acceptance remains active; historical recordings and rejected references are separately labeled.

27 October 2026. Source: [complete owner brief](requests/UI-UX-REDESIGN-2026-10-27.txt), supplemented by the owner's naming authorization. This is an implementation ledger, not a completion claim.

## Baseline and dependency

Branch `codex/ui-redesign-2026-10-27` starts at `cddebbd56bf5b4d53b7774fcdf7718e562720c06`, the documentation checkpoint of draft, unmerged PR #22. Its application tree equals accepted source `76c0ee2`, verified by Actions 40482959273. The redesign must retain all eraser, background, thumbnail, cleanup, audio and HD60 fixes. Its draft PR will be stacked on `codex/review-fixes-2026-10-27`; main alone is not an adequate baseline.

## Historical original direction and baseline findings

The original, now rejected direction proposed a calm musical sketchbook: warm ivory, forest text, restrained teal actions and small sage/lavender/coral accents. Use an original continuous line becoming a wave, never competitor media. Keep artwork colors, rendering, geometry and audio unchanged. The owner selected Doodimo after considering alternatives. Use one centralized brand definition, original line-to-wave assets and the planned store title Doodimo: Draw Music; no store publication or legal/name-reservation claim.

Current source exposes a long Home introduction before the creation action, simultaneous editor settings in two scroll regions, thirteen instrument chips, and a long export sheet containing every format. Navigation retains four branch navigators but lacks a deliberate content transition. These findings guide the redesign; actual pre-change widget captures and emulator evidence must be inspected separately before visual acceptance.

## Implementation sequence and current status

| Phase | Work | Current evidence/status |
|---|---|---|
| Baseline | Real widgets, loaded fonts/icons, realistic fixture data; actual emulator captures | 19 native before screenshots, six actual clips and separate profile phases accepted as baseline; new after evidence pending |
| Foundations | Semantic theme, licensed bundled fonts/fallbacks, spacing/type/component/motion tokens, original line motif | Implemented; final-source checks pending |
| Vertical slice | Home hierarchy, retained animated navigation, stable canvas-focused editor and voice/music choosers | Implemented and under final visual refinement |
| Creative surfaces | Drafts/Exports, intent-led export, visual paper/crop workflow | Implemented and under final visual refinement |
| Support surfaces | Grouped Settings, language, welcome/help, coachmarks, recovery/rating | Implemented and under final visual refinement |
| Accessibility | Light/dark, all 12 locales, forced RTL, 320 dp/200%, tablets/landscape/keyboard, contrast and targets | Focused tests / first 55-screen matrix executed; final exact-source acceptance pending |
| Runtime delivery | Full product checks, actual emulator recordings, measured profile frame timings, exact-source APK/draft PR | Focused tests / first 55-screen matrix executed; final exact-source acceptance pending |

Parent owns shared tokens/components, Home/navigation, integration and review. Existing independent agents own editor, library/export, backgrounds, support screens, baseline/font coverage, and emulator/profile harness respectively. No overlapping commits or branch changes by agents.

## Functional invariants

Retain every branch navigator and scroll/section state; animation must not dispose branches. Keep document/controller/audio/export-job ownership intact across routes and sheets. Canvas placement and pointer normalization stay stable during decorative ticks; do not animate the live canvas geometry. Instrument changes finish active gestures safely. Derive playback visuals only from real audio status. Ambient graphics live outside document renderers, ignore input/semantics, and pause when hidden/backgrounded or reduced motion is active.

## Acceptance evidence still required

Before/after captures must cover Home; editor empty/drawn/playing and music/voice controls; paper/crop; Drafts/Exports; export selection/progress/ready/error; Settings/language/help; and representative dark/compact/large-text/tablet cases. Record actual cloud emulator navigation, tabs, voice/playback, sheet, export and reduced-motion flows. Collect profile UI/raster frame timings under transitions and drawing load, including actual sample counts and over-budget frames. Widget snapshots do not prove native performance. Mac compilation, physical sound/routes, screen readers and receiving applications remain separate acceptance work.

Run formatter, analyzer, meaningful existing/new tests, `bash scripts/check-android.sh`, signature verification and relevant actual runtime checks. Preserve functionality tests; update changed presentation expectations rather than deleting coverage. Report new source independently of the accepted pre-redesign gate.

## Corrective art direction — first iteration rejected

The owner rejected the initial pale-card preview as too basic. It is retained under `docs/ui/progress` as rejected comparison evidence; its passing technical checks and golden pixels do not constitute design approval.

That second, also rejected direction was **Doodimo as a pocket creative instrument / editorial mixtape**: open Home composition around real saved/template artwork, paper sleeves with titles outside; one compact deep-ink four-key dock with an animated selected marker; original 24-unit control glyphs; Space Grotesk display typography over legible Nunito/Noto UI text; a tactile joined editor tool rail and transport console; connected format selection and a real-artifact export ticket. Warm paper, deep ink, lavender and one controlled lime accent establish hierarchy without universal outlined containers, blur or false audio visualizers. Preserve every functional, accessibility, gesture, audio and recovery fix already verified. New renders must materially differ before exhaustive acceptance resumes.

## First immersive slice checkpoint

The current implementation is reviewable in [three actual dark widget renders](ui/immersive-prototype/README.md), separate from both rejected sets. The Home sculpture is implemented, lifecycle-aware and loop-continuity tested; source-pinned actual emulator motion evidence is next. Editor and export now use the new dimensional/icon/material system while keeping existing document/audio/export ownership. This is a prototype checkpoint, not complete redesign acceptance. Secondary-surface integration and final full gates remain pending. The existing main-bound product workflow is preserved during this early stacked prototype; re-enable the stacked base for full CI at integration, retain every check, and run the final source locally and hosted before completion.

## Current immersive implementation and review

The implemented replacement uses ink navy, layered indigo, violet/cyan ribbon lighting, crisp off-white text and a deliberately cool light theme. Thirty-five original filled duotone utility/navigation objects and thirteen instrument illustrations replace the rejected thin glyphs. Doodimo branding uses the original filled folded-orbit mark; bundled Space Grotesk, Nunito and Noto fallbacks remain offline. Artwork paper/colors and save formats are independent of chrome.

Home combines real saved/template artwork with a bounded 16-second sculpture, a clear Create action and a lazy responsive artwork gallery. The dock keeps each branch navigator mounted. Short landscape at large text uses a measured side rail; section state, scroll, focus, pending language and modal barriers retain their owners. The sculpture separates static gradients/ribbon painting from animated highlights and gentle compositor movement; real rendered tests cover loop seams and lifecycle suspension.

Editor controls now form one joined instrument console: prominent Play, Replay, named voice, music summary and labeled Tools. Draw/Erase, Undo/Redo and document paper remain stable. Instrument/music/mix/score/style/background/crop panels use the same materials and transactions. Applying tempo alone preserves unknown raw root/scale identifiers; resize during a gesture uses the current canvas transform and retains a single Undo.

Library presents real document/export metadata and thumbnails in dimensional sleeves. At very short heights its section selector enters the scroll flow, while ordinary layouts retain pinned sections. Name, delete and empty-image confirmations use shared branded panels. Short keyboard panels pin Close and actions while letting their heading/content scroll; large text preserves full labels rather than shrinking touch targets.

Export has one connected Image/Sound/Video/Notes selector, real frozen artwork, relevant options and truthful job states. The PNG transparency control remains reachable; the preview removes paper onto a checkerboard. Actual UI publication tests decode both modes and verify transparent corners or exact paper RGBA, opaque ink and unchanged source document. Sharing does not imply receipt. Native jobs retain cancellation/finalization ownership.

Settings, language, welcome/help, rating and coach marks now share the scene, duotone objects and primary actions. Preferences and opt-in behavior remain real. Coach marks preserve measured control geometry, tap barrier and focus restoration. Background/crop/style presentation preserves existing 4:5 framing, direct crop controls and Apply/Cancel semantics.

The first 55-image matrix rendered without Flutter exceptions, then visual inspection found split words in the French 200% Home/editor actions and narrow landscape music summary. These were corrected through measured whole-word reflow and the subsequent clean76-state matrix; a green renderer alone is not visual acceptance. The matrix uses correctly bundled fonts, declared fixture ports and simulated keyboard insets where labeled. Actual native IME, physical audio/performance and iOS remain separate.

The first after-native run failed on emulator H.264 configuration at720×1600 and captured a premature flat startup image. Diagnostic evidence is retained. The repaired harness verifies first raster plus actual native presentation, checks exact recorder identity through startup and stop, permits a bounded432×960 fallback only on the observed encoder configuration error, and validates actual MP4 metadata/duration. Host regression tests are diagnostic orchestration tests, not native motion proof. A new source-pinned emulator run is required. See DEVELOPMENT-STATUS.md for current exact source and test evidence.

## Final local integration checkpoint

All major surfaces are implemented. The final local Android script at application f9fc4ba / capture-only harness efcac58 passes356 Flutter tests, a clean76-state capture with eight strict pixel references,24 JVM tests, lint, actual APK/v2 signing and12 Linux interruption/recovery cases. The [rendered review set](ui/immersive-review/README.md) includes the independent document paper, cool light theme, compact editor, language choices and actual coach. All12 large-text console locales were independently inspected; measured whole-word reflow fixes ES/PT/FIL/ID, and tests preserve named voice access after real scrolling. The language instruction moves behind help at constrained sizes. Large coach text uses a bounded scrolling card; simultaneous full-canvas visibility is not claimed at200%.

The full application/native gate passed run40555672797 at accepted head efcac58 with app source f9fc4ba: actual offline drawing/playback/save/reopen and PNG/WAV/MP4/MIDI, interruption/force-stop retry, HD60 and independent complete-file inspection. The current normal test APK is artifact12758462920 from that run. Native acceptance is reused only when an exact protected-input/workflow/source/run proof succeeds; core/JVM/lint/build remain current. Production changes require fresh affected native checks.

Public capture40560035660 attempt3 (harness5c4a7be, appf9fc4ba) produced17 actual snapshots, all seven silent recording pairs and three frame profiles before VM/ADB connectivity disappeared after live compact-display reconfiguration. Cause unknown. Reader40594654948 independently verified five PNGs and completely decoded the40.580256-second/174-frame ambient clip. Reader40598222546 independently verified original SHA/bytes and decoded the six remaining original interaction clips covering root navigation, editor/Back, paper, instruments/playback, export-ready and reduced motion. Decoding verifies media integrity, not smoothness or complete responsive acceptance. [Actual native Home/editor/export previews](ui/public-native-checkpoint/README.md) preserve source/fixture conditions. Native IME inset/focus/panel geometry passed, but its PNG lacks visible keyboard keys.

Unrecorded Home observed83 engine frames, UI p954.628ms / raster p95234.942ms; every raster frame exceeded16.67ms. Different runner placements prevent causal comparison with the older470.004ms figure. Smoothness remains unaccepted. Harness2fcfea0 now recovers compact/tablet/light in separate fresh preset sessions before app launch, retaining real route/platform-scaler/exact-raster guards, and prepares one bounded diagnostic-only radial-backdrop A/B without changing shipping artwork or animation clocks. Complete responsive pixel review and measured performance investigation remain in progress. See DEVELOPMENT-STATUS.md for the current exact source/checkpoint and any subsequent product correction.
