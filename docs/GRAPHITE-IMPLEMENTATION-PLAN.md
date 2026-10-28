# Approved graphite redesign — implementation checkpoint

## Current state and input blocker

The owner approved the original graphite review boards and cloud implementation on 28 October 2026. This is a new app-wide visual direction, superseding the earlier navy/violet/cyan presentation. Existing functionality and verified corrections remain mandatory.

Baseline: remote main `a7a8e595d96735c9b5db607c8d03d785937edf15`, containing `75e708d9efbd21fc829a290e5e56e0f15a826823`; their file trees have no content diff. The user merged PR22/23/24. This task did not perform those merges. New development branch: `codex/graphite-redesign-2026-10-28`.

**Blocked before visual implementation:** the selected cloud session has no Library skill, Library file tools, or supported Library materialization helper. Both complete cloud-skill catalog pages and the executor catalog were inspected; no Library skill is listed and the executor skill catalog is empty. Tool metadata exposes no Library search/read/materialize route. The exact files are absent from this workspace. The project tracker Page contains no references to their filenames, so its exact-reference reader cannot be used with an invented reference. No authenticated URL, parent/Mac filesystem path or generic Sediment downloader was used as a workaround.

Required authorized inputs:

| File | Authoritative Library identity | Current verification |
|---|---|---|
| Doodimo-Graphite-Review.png | `libfile_90e6fdfce7b881918256b20f898237d8` | Bytes unavailable; not visually inspected |
| Doodimo-Motion-Storyboard.png | `libfile_95faaa9a450881919a22c6b77b58abd4` | Bytes unavailable; not visually inspected |
| Doodimo-Motion-Plan.md | `libfile_9850c6512d408191912ba6e2c721e4c3` | Complete source unavailable; parent summary only |

These are original static ImageGen design inputs, not Stitch exports or implemented product captures. They must be materialized through a supported authorized transfer route into this executor, verified for byte length/SHA256/MIME/dimensions/path, and both PNGs viewed before implementation. User approval is already given; no new design approval is needed. Restoring supported file access or supplying the exact authorized bytes to this task is the missing prerequisite. Until then, only inventory and implementation planning proceed. No visual product change, new APK or redesigned-screen test pass is claimed. The independent current-main baseline widget capture passed and generated76 real-font fixture states; four original PNGs were inspected and are retained in [the baseline evidence](ui/graphite-baseline-2026-10-28/README.md). This is not native/device validation.

## Source inventory and preserved contracts

| Area | Implementation seams | Preserve during redesign |
|---|---|---|
| Design system | `lib/design_system/theme.dart`, `brand_colors.dart`, `typography.dart`, `immersive_surface.dart`, `creative_components.dart`, `doodimo_icon.dart`, `brand.dart` | Central semantic light/dark tokens, bundled licensed fonts/fallbacks, contrast and selected/error/disabled states; Doodimo / Draw your sound; package ID `com.imranshisheo.scribblesong` |
| Shell/navigation | `lib/app/app.dart`, `creative_dock.dart`, `retained_transition.dart`, `motion.dart`, `system_chrome.dart` | Retained branch/controller/scroll state, continuous retarget from painted weights, full backdrop coverage, independent Drafts/Exports navigators, selected-only input/focus/semantics/tickers/Hero ownership, RTL/Back and safe areas |
| Home/templates | `lib/app/app.dart` HomePage; `features/home/presentation/templates.dart`; template catalog | Real saved data and original templates; cached sliver delegate/documents, keyed sleeves and narrow `home-artwork-paint` repaint boundary. Never reintroduce five-pixel-scroll six-document churn |
| Editor | `features/editor/presentation/editor.dart`, `responsive_workspace.dart`, `canvas.dart`, voice/music/tools/accompaniment panels | Stable normalized canvas coordinates, immediate pointer capture, active-gesture finishing, one audio/controller owner, all thirteen voices, history, tempo/key/scale/expression and real save/preparation/playback state |
| Libraries | Drafts/Exports pages, `library_branch_frame.dart`, `library_tabs.dart`, document card/gallery/state panels | One stable selector, independent scroll, rename/duplicate/delete/Undo/recovery, photo/gradient thumbnails and missing/corrupt/recovery states |
| Export | `features/export/presentation/export_sheet.dart`, preview stage, `continuity_switcher.dart` | PNG/WAV/MP4/MIDI settings and real job/cancel/finalization ownership, transparent/paper PNG behavior, snapshot geometry/paper, native Share/Save/Open semantics |
| Background/crop | Shared creative panels and `features/backgrounds/presentation/` | Transactional Cancel/Apply, relevant-field validation, exact document-aspect preview, direct crop/rotation/mirror/opacity, photo replacement/removal and native picker ownership |
| Secondary surfaces | Settings/language/onboarding/help/rating and shared sheet/dialog/name/style/paper controls | All current controls and locale persistence, skippable first-use help, focus entry/return, keyboard-safe panels, twelve locales/RTL, reduced motion and existing offline/free behavior |

Document artwork, paper, instrument identities, saved/recovery formats, audio scheduling and all export adapters remain independent of app-chrome styling. Synthetic filenames/art in the mockups must not become fake user activity. No accounts, ads, billing, network runtime assets or paid services are added.

## Implementation sequence after input access

1. Inspect both approved PNGs and full motion plan; record actual pixel observations and limitations. Capture the implemented baseline using deterministic real project/template fixtures. Derive concrete graphite/charcoal/orange materials, framing, icon geometry and type hierarchy from the inspected boards; do not invent exact token values from the parent summary.
2. Implement the shared materials, consistent fine-outline icon family, persistent shell/backdrop and nonblocking launch composition. Review actual Home/Library/Editor renders against the approved boards before propagating components everywhere.
3. Deliver the Home/Library/Editor vertical slice: artwork-forward hierarchy, tactile connected navigation/transport/tools, real preview-to-editor continuity, stable canvas, preserved Home caches and interrupted Library blends.
4. Carry the same system through export selection/options/progress/ready/error/cancel, background/crop, Settings/language, onboarding/help, empty/recovery/error/rating surfaces. Preserve every existing feature and control path.
5. Refine cool/light and dark themes, 320dp, 200% text, RTL/long/non-Latin strings, landscape/tablets, safe areas and keyboards. Measure composed text/non-text contrast and touch targets. Adapt composition rather than shrink readable text or tap areas.
6. Execute affected functional, visual and native gates; inspect actual pixels and genuine real-time recordings. Profile actual UI/raster/presentation evidence with explicit renderer/device/refresh-rate scope; never infer smoothness from PNGs, encoded export FPS or complete-video decoding.

## Motion contracts to verify against the storyboard

- Launch: seed → expand → gather → reform → settle; approximately1.1s is a design target, not a forced startup wait. Content/input must not depend on animation completion. Preserve warm-session state; reduced motion uses an immediate/short final composition. Confirm the actual storyboard before choosing paths/timelines.
- Tabs: persistent shell/background and retained pages; no blank/reset/disposal at first frame or rapid retarget. Sample the current visual state on interruption; preserve independent scroll and focus. Equivalent reduced-motion state changes remain usable.
- Artwork flight: one meaningful Home/template/draft preview → Editor transition using a safe immutable snapshot and unique ownership. Do not animate live drawing geometry, remount the engine, move pointer coordinates or block input until a decorative flight finishes. Test rapid entry/Back and interruptions explicitly.
- Ambient/depth: bounded original native/vector or measured cached composition, hidden/background ticker suspension, reduced-motion static alternative, no repeated full-screen blur. Decoration never enters documents/thumbnails/exports. Audio-reactive state, if used, must come from the actual audio clock; no fake meters/progress.
- Sheets/controls: consistent connected shape/material feedback and reversible open/close transitions; retain export jobs and keyboard/focus ownership. Semantics and final state cannot depend on animation-end callbacks.

## Skill use and evidence boundaries

### Nonvisual ownership audit while input transfer is pending

- `main.dart` awaits bounded coordinated background cleanup before creating providers. A launch composition must not reorder that storage-safety gate or initialize an editor/audio session just to animate. Additive visual work starts after application construction and cannot create a second startup delay.
- `ScribbleSongApp` owns one late-final router. Keep that router and its branch trees stable while launch/theme/motion widgets rebuild. `settingsProvider` initially reports `loading: true` and loads asynchronously: a future decorative launch must not animate before a persisted reduced-motion preference is known. Keep content usable with a static composition while unknown, combine persisted/system preferences, and never start a late entrance cascade after the session is warm.
- The pinned Flutter Hero implementation visits current nested PageRoutes and stops at disabled `HeroMode` subtrees. Existing retained containers enable HeroMode only for the selected branch/section. Preserve that filter; never enable both retained Library sections for the same flight. Tests must cover multiple previews of the same project, nested branch→root Editor navigation, rapid reversal and Back.
- Template routing uses catalog IDs (`/editor/template-…`), while `openedDocumentProvider` creates a fresh independently identified document. Sleeve preview documents are deliberately cached. A flight identity must distinguish navigation/preview ownership without reusing a cached preview as a newly saved project or assuming preview/document IDs match. Saved-project loading is asynchronous; use an honest static snapshot/fallback until the real destination is ready, and preserve load/recovery/error behavior.
- The editor owns `_canvas` through a GlobalKey and its engine through init/dispose. On non-resumed lifecycle it finishes the gesture, pauses and saves. A safe flight animates a separate immutable representation, never reparents the live DrawingCanvas into an overlay or mounts a second Editor. First-pointer input during flight must either remain immediately visible on stable canvas coordinates or cancel the decorative flight safely; decide through an actual prototype and test, not by hiding input until animation completion.
- Export deliberately finishes the active gesture and pauses before opening its owned sheet. Existing PopScope/save/pause and export cancellation/finalization determine correctness. No decorative completion callback may pop a route, save a project, resume audio, cancel an export or announce publication success.

These are source-audit constraints and proposed verification points, not implemented launch/Hero behavior. Exact paths, shapes, timings and composition remain dependent on the actual approved images and complete motion plan.

The pinned MIT `.agents/skills/ui-ux-pro-max/SKILL.md` is explicitly read/applied; its provenance remains upstream `28b3b8dee8c976df4fa3e94aed4e092ad43fcb03`. Offline Flutter shared-element search returned Hero guidance and shared-state guidance; the unrelated state row is not a visual specification. The first interruptible-motion search returned reduced-motion/excessive-motion guidance; one narrowed retry returned Web Cancellable State Transitions. That cancellation principle may inform Flutter ownership, but Web examples are not native implementation proof. Generic catalog recommendations do not override the approved boards, existing product contracts, pinned Flutter3.47.2 or48dp Android touch targets. No new design-system output was persisted or substituted for the unavailable mockups.

Retain existing meaningful tests for Library first-frame coverage/reversal/transparent ink/footer isolation, Home document/painter identity and dense-preview paint isolation, navigation/scroll/focus, save/recovery and actual exports. Add targeted launch/flight/interruption/lifecycle coverage for new behavior. Run formatter/analyzer/product tests and `bash scripts/check-android.sh`; new protected product source needs fresh applicable native/media acceptance. Update visual references only after inspecting intended rendered changes, without deleting functional coverage or weakening pixel thresholds.

Prior source75e708d has accepted cloud gates, original recordings and source mapping in `DEVELOPMENT-STATUS.md`; those passes do not validate a future redesign. The eight strict Mac golden discrepancies remain unresolved; no Mac/iOS or physical-profile pass is implied. The phone is user-controlled in a separate task; this executor must not contact/control it. New review PRs stay draft/unmerged. Use only bounded free standard GitHub runners while the repository is verified public; no paid usage, credentials, history rewriting, store publishing or scheduled continuation.
