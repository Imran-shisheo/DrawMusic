# Doodimo design system

29 October 2026. The approved reference-led graphite system supersedes the previous navy/violet/cyan and earlier rejected directions. Exact source/check state is in DEVELOPMENT-STATUS.md; this document describes implemented presentation contracts, not a physical performance acceptance claim.

## Identity and color

`brand.dart` keeps Doodimo / Draw your sound. The original orange drawing-to-sound gesture is shared by in-app painting, authoredSVG and generated native assets. Fine24-unit outline glyphs share stroke/corner/optical size and explicit disabled/selected semantics. All materials are offline Flutter/native geometry with static authored lighting, not extracted competitor art or full-screen blur. Package `com.imranshisheo.scribblesong`, project IDs, normalized artwork, original instrument colors, paper and export rendering remain unchanged.

| Semantic role | Graphite dark | Light stone |
|---|---|---|
| App surface | `#141819` | `#EEEEE7` |
| Low surface | `#1C2121` | `#FAF9F2` |
| Raised surface | `#2D3332` | `#E2E5DD` |
| Main text | `#F4F3ED` | `#202624` |
| Secondary text | `#C4C7C0` | `#4D5650` |
| Primary | `#FFA465` with `#25180E` text | `#9B400B` with `#FFF8F0` text |
| Tactile Create key | authored `#FFAB6B`→`#EC7D37`, ink text | same authored material/ink text |
| Outline | `#959E97` | `#6B766E` |

Theme roles govern control/text contrast and system bars; document paper never inherits them. The fixed missing-photo semantic backing is now opaque graphite `#242929` with an explicit white essential silhouette, independent of user paper/chrome brightness. Pixel tests retain opacity, contrast, ink and fallback-color assertions. Selected language labels/checks are measured across every material stop; normal text target4.5:1 and non-text3:1 remain mandatory, not a claim about arbitrary combinations.

`ImmersiveSurface` paints static bounded edge lighting and a shallow contact shadow; no per-frame texture decoding, repeated backdrop filter or project serialization occurs. Circular tool/dock faces and orange Create/Play/Export keys keep readable labels and48dp targets. Composition adapts at320dp/200%/RTL; scrolling advanced surfaces is intentional, while primary captions must remain readable. Panels connect to actual source bounds where available and preserve native modal/focus ownership.

## Typography and layout

Display headings use bundled Space Grotesk; UI text uses bundled Nunito Sans. Original licensed Noto Devanagari, Thai, Arabic and CJK fallbacks support non-Latin text offline. Arabic fallback/forced RTL tests do not mean an Arabic locale is shipped. All372localized resources cover English, French, Spanish, Italian, Korean, Japanese, Vietnamese, Hindi, Portuguese, Thai, Filipino and Indonesian. Human translation review remains pending. Sources, transformations, glyph checks, hashes and SIL OFL licenses are in FONT-PROVENANCE.md and FONT-MANIFEST.json; licenses ship in assets and Flutter's registry.

| Role | Size / line height | Weight |
|---|---|---|
| Large headline | 40 / 1.08 | 700 |
| Medium headline | 32 / 1.12 | 700 |
| Large title | 22 / 1.20 | 600 |
| Medium title | 16 / 1.35 | 600 |
| Large body | 16 / 1.50 | Inherited body |
| Medium body | 14 / 1.45 | Inherited body |
| Large label | 14 | 600 |

Shared spacing is 4, 8, 12, 16, 20, 24 and 32 dp. Control/card/panel radii are 16/24/28 dp. Interactive targets retain at least 48 dp. Measured word widths choose wrapped/vertical controls rather than shrinking labels or splitting words. Compact/large-text Home uses content-measured flow; the normal411dp layout frames real artwork above its caption and primary creation action. At 200% some controls, panels and coach content require scrolling. Document coordinates and gesture targets stay stable.

## Components and ownership

- `DoodimoIcon` supplies the original fine-outline optical glyph family and the named voice-object treatments; parents provide localized labels, selected checks and enabled/disabled states. Small utility actions retain familiar metaphors. No competitor pack is shipped.
- `CreativeDock` preserves stateful branch navigators and adds labeled destinations, a distinct Create action and local selected-state motion. Short landscape uses an adaptive rail; content receives actual dock insets.
- Home uses real saved/template artwork and static bounded graphite framing. The finite original gesture launch is separate from artwork. Decorative art is excluded from semantics, hit testing, saved documents and exports.
- The editor combines a stable 4:5 canvas, tool palette and transport console. Voice/music/advanced panels disclose detail while audio and gesture ownership remain outside decorative motion.
- Export uses a connected four-format selector, actual document preview and relevant options. Progress, errors, cancellation and ready actions follow the real job; share-sheet opening is never called delivery.
- Shared immersive surfaces/panels, naming, paper and style components cover Library, Settings, background/crop, help, onboarding, rating and recovery. Phone sheets and bounded wide panels preserve keyboard safety, focus return and native Back ownership. Pickers, providers and sharing remain OS-owned.

All custom motion follows MOTION-SYSTEM.md and system/persisted reduced-motion preferences. Native branding provenance is in ASSET-PROVENANCE.md. Eight intended graphite pixel references were rendered and inspected before regeneration; the complete76-state matrix passes. The complete local strict product gate passes. Fixture pixels establish rendered layouts, not physical smoothness or iOS compilation.

Graphite lighting is static bounded native/vector painting. The earlier navy/ribbon cache experiments and their software-renderer measurements remain historical in MOTION-SYSTEM.md; they are not runtime evidence for this source. Missing-photo status uses a fully opaque graphite badge and white silhouette, independently of user paper, with localized semantics and pointer-transparent behavior.
