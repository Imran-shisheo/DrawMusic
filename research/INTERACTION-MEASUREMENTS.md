# UI measurement notes

Measurements use raw screenshots and accessibility bounds, not extracted layouts/assets. `px / 2.625 = dp` at the verified device density; dp values below are rounded. Text sp equals approximate dp only at font scale 1.0; no font file or text style was inspected.

## Verified environment

- Nothing A059P / Asteroids, Android 16 / API 36.
- Physical display 1080 × 2392 px, density 420 dpi / scale 2.625. Approximate full logical extent 411.4 × 911.2 dp.
- Display reports 120 Hz mode, with 90/60/30 Hz alternatives. This is device configuration, not measured application rendering throughput.
- Portrait rotation 0; font scale 1.0; auto-rotate setting 1. No size or density override was applied.
- App versionName 2.0, versionCode 11; package metadata minSdk 23, targetSdk 36. These do not set the new Flutter app's minimum versions.

## XML hit regions (verified)

| Component | Screen px bounds | Size px | Converted size dp |
|---|---|---|---|
| Gallery card, left | [32,255]–[524,748] | 492 × 493 | 187.4 × 187.8 |
| Gallery horizontal gap | 524–556 | 32 | 12.2 |
| Gallery outer inset | 0–32 | 32 | 12.2 |
| Gallery row gap | 748–780 | 32 | 12.2 |
| Premium entry hit region | [909,89]–[1046,226] | 137 square | 52.2 square |
| Editor Back | [0,157]–[134,291] | 134 square | 51.0 square |
| BPM decrement | [134,160]–[261,287] | 127 square | 48.4 square |
| BPM increment | [468,160]–[605,287] | 137 × 127 | 52.2 × 48.4 |
| Background control | [625,160]–[752,287] | 127 square | 48.4 square |
| Export | [772,160]–[1060,287] | 288 × 127 | 109.7 × 48.4 |
| Brush / Eraser / Style | x=73/200/327, y=321; 127-square regions | 127 square | 48.4 square |
| Undo | [42,1825]–[169,1952] | 127 square | 48.4 square |
| Redo | [169,1825]–[296,1952] | 127 square | 48.4 square |
| Play | [316,1798]–[497,1979] | 181 square | 69.0 square |
| Instrument item | [34,2000]–[173,2139] | 139 square | 53.0 square |
| Key menu item | 168 × 126 | 168 × 126 | 64.0 × 48.0 |
| Scale menu item | 609 × 126 | 609 × 126 | 232.0 × 48.0 |
| Accompaniment menu row | 578 × 137 | 578 × 137 | 220.2 × 52.2 |
| Background segmented tab | approx 337 × 154 | 337 × 154 | 128.4 × 58.7 |
| Background Apply | [34,2186]–[1046,2344] | 1012 × 158 | 385.5 × 60.2 |

The plus-button XML region includes a larger image container [789,2089]–[1080,2392]; its visible circular disk is smaller. Do not equate image-container bounds with visible disk diameter.

## Pixel samples (verified screenshot values)

See `evidence/color-samples.json` for dominant exact RGB values and pixel counts. Main samples: page #FFFEF8, gallery artwork field #FBFAF0, canvas #F7F6EE, cards #FFFFFF, ink #263A35, accent #00C8B3, tool-strip fill #EEEEEE, selected home capsule #F0F0F0. Instrument tiles include #8277DB, #EAC67B, #94C6B1, #DFA38B, #BCD89C, #96A6DA. Premium panel mint fields #BFFBEB and #96F2DA; selected border #58D4BD. These are captured pixels, not proof of original design-token declarations.

## Visual estimates (not verified style declarations)

- Canvas rectangle approximately x=34…1046, y=482…1764 px: 1012 × 1282 px (~386 × 488 dp), with ~32–40 px rounded corners (~12–15 dp).
- First gallery card: artwork band ~375 px (~143 dp), white title band ~118 px (~45 dp); radius ~48 px (~18 dp), very light gray drop shadow offset 2–5 px with soft blur.
- Visible toolbar icon art ~54–70 px (~21–27 dp) inside ≥48 dp hit targets. Glyph stroke ~4–7 px (~1.5–2.7 dp).
- Visible default drawing stroke about 6 px (~2.3 dp), rounded caps; exact width may vary with render/style mode.
- Rounded geometric sans for UI. Body ~14–18 sp, gallery labels ~18 sp, BPM ~22 sp semibold, premium headline ~32 sp heavy. Brand wordmark is custom art, not the UI font.
- Sheet top radius ~42 px (~16 dp). Buttons and navigation use large rounded/pill silhouettes; white surfaces have restrained elevation rather than hard borders.
- Premium CTA has a glossy warm yellow → orange → pink horizontal treatment, with diagonal highlights. Gradient endpoints and stops were not programmatically sampled; use original art direction rather than tracing it.
- No exact animation durations were measured. WAIT letters visibly change vertical positions between captures; the crown changes orientation/appearance. Cursor motion is in recorded clips. Proposed timings in PRD are new-product targets.

## Interaction limits

ADB verifies single-pointer taps, drags, button selection and visible response. It does not verify physical haptics, two-finger/stylus behavior or real touch-to-speaker latency. UI hierarchy includes some useful instrument descriptions but many icon-only controls have no description. Expanded ads can cover the Play and instrument controls; visual hit targets are then inaccessible despite remaining in underlying XML.
