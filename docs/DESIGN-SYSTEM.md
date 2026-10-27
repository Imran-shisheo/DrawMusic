# Doodimo design system

27 October 2026. Implemented application source `f9fc4ba`; exact-source final runtime acceptance is tracked in DEVELOPMENT-STATUS.md. The owner rejected the earlier warm sketchbook and editorial iterations. Their palette and glyphs are historical, not the current system.

## Identity and color

`lib/design_system/brand.dart` centralizes Doodimo and “Draw your sound.” The original folded ribbon D mark, filled duotone icons and navy/violet/cyan materials form one offline identity. Application ID `com.imranshisheo.scribblesong`, document IDs, stored artwork colors and export rendering remain independent of branding. The planned store title is Doodimo: Draw Music; no store publication or legal availability claim is made.

| Semantic material | Dark | Cool light |
|---|---|---|
| App surface | `#090B18` | `#F4F7FF` |
| Raised low surface | `#151B35` | `#E9EEFE` |
| Main text | `#F0F3FF` | `#141B35` |
| Secondary text | `#BDC5E3` | `#505B7A` |
| Primary control | `#BCA6FF`, ink text | `#6840C7`, white text |
| Secondary control | `#55DFF5`, ink text | `#006878`, white text |

Authored decorative accents use violet `#8B5CF6`, cyan `#55DFF5` and restrained pink `#EF81C7`. These are decorative tokens, not a promise that every arbitrary foreground/background combination meets text contrast. Theme and selected-language tests verify the actual semantic pairs at ≥4.5:1 for normal text and ≥3:1 for tested non-text outlines/checks. Physical screen-reader and complete device contrast review remain separate.

`theme.dart`, `brand_colors.dart` and `system_chrome.dart` own semantic roles and theme-aware system bars. Dark Android chrome uses light system icons; cool-light chrome uses dark icons. A root AnnotatedRegion and AppBar styles follow the same policy. System controls and document paper are never recolored by animation.

## Typography and layout

Display headings use bundled Space Grotesk; UI text uses bundled Nunito Sans. Original licensed Noto Devanagari, Thai, Arabic and CJK fallbacks support non-Latin text offline. Arabic fallback/forced RTL tests do not mean an Arabic locale is shipped. All 371 localized resources cover English, French, Spanish, Italian, Korean, Japanese, Vietnamese, Hindi, Portuguese, Thai, Filipino and Indonesian. Human translation review remains pending. Sources, transformations, glyph checks, hashes and SIL OFL licenses are in FONT-PROVENANCE.md and FONT-MANIFEST.json; licenses ship in assets and Flutter's registry.

| Role | Size / line height | Weight |
|---|---|---|
| Large headline | 40 / 1.08 | 700 |
| Medium headline | 32 / 1.12 | 700 |
| Large title | 22 / 1.20 | 600 |
| Medium title | 16 / 1.35 | 600 |
| Large body | 16 / 1.50 | Inherited body |
| Medium body | 14 / 1.45 | Inherited body |
| Large label | 14 | 600 |

Shared spacing is 4, 8, 12, 16, 20, 24 and 32 dp. Control/card/panel radii are 16/24/28 dp. Interactive targets retain at least 48 dp. Measured word widths choose wrapped/vertical controls rather than shrinking labels or splitting words. Compact/large-text Home uses content-measured flow; the normal 411 dp layout preserves a measured 12 dp headline/artwork gap. At 200% some controls, panels and coach content require scrolling. Document coordinates and gesture targets stay stable.

## Components and ownership

- `DoodimoIcon` supplies 35 original optical glyphs and the named voice-object treatments; parents provide localized labels, selected checks and enabled/disabled states. Small utility actions retain familiar metaphors. No competitor pack is shipped.
- `CreativeDock` preserves stateful branch navigators and adds labeled destinations, a distinct Create action and local selected-state motion. Short landscape uses an adaptive rail; content receives actual dock insets.
- Home uses real saved/template artwork and an original bounded ribbon scene. Decorative art is excluded from semantics, hit testing, saved documents and exports.
- The editor combines a stable 4:5 canvas, tool palette and transport console. Voice/music/advanced panels disclose detail while audio and gesture ownership remain outside decorative motion.
- Export uses a connected four-format selector, actual document preview and relevant options. Progress, errors, cancellation and ready actions follow the real job; share-sheet opening is never called delivery.
- Shared immersive surfaces/panels, naming, paper and style components cover Library, Settings, background/crop, help, onboarding, rating and recovery. Phone sheets and bounded wide panels preserve keyboard safety, focus return and native Back ownership. Pickers, providers and sharing remain OS-owned.

All custom motion follows MOTION-SYSTEM.md and system/persisted reduced-motion preferences. Native branding provenance is in ASSET-PROVENANCE.md. Eight original immersive pixel references and 76 real-font fixture states passed the latest complete local gate without reference regeneration; these establish rendered layouts, not physical smoothness or iOS compilation.

Scene lighting retains its original gradient decoration. A static cache-layer experiment preserved exact pixels but did not verify a runtime gain and was rolled back; see MOTION-SYSTEM.md for measured limits. Missing-photo status uses an opaque indigo badge and white existing glyph, maintaining measured16.935:1 silhouette contrast independently of document paper, with localized image semantics and pointer-transparent behavior.
