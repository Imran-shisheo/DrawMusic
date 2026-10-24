# Exploratory research log

Research date: 23 October 2026 (Asia/Dubai). This is a black-box review of installed Draw Music 2.0 (11), not a source-code review. The app was already installed; its data was preserved.

## Session findings

| Area | Action / expectation under test | Actual evidence | Confidence |
|---|---|---|---|
| Device | Detect a controllable Android device and package | One authorized USB device, Nothing A059P; target package installed | Verified ADB |
| Launch | Open launcher entry and inspect initial experience | Initial captured full-screen video ad; Back led to WAIT / Loading ad… over gallery; loading did not dismiss with another Back | Verified captures 001–005 |
| Recovery | Ordinary app restart | Illustrated Loading Data… splash, app-open ad with Continue to app, welcome START | Verified 006–008; clean-install order unverified |
| Monetization | Open START without purchasing | Full-screen premium offer; weekly “FREE For today”, 3-day trial; monthly 39 AED/month; selection changes CTA and explanatory copy; X closes | Verified 009–011, price only for this device/session |
| Gallery | Enter home and use plus | Two-column template cards, crown, Home/Library/Setting navigation and separate circular new-drawing button; plus opens editor | Verified screenshot + XML |
| Drawing | Draw a horizontal line | Continuous thin purple stroke with rounded ends, undo becomes available | Verified 015 |
| Playback | Play / pause research line | Left-to-right scan line with intersection marker; audio begins after Play; repeated loop | Verified images, video and waveform |
| Guidance | Open style/accompaniment/key/scale for first time | Dimmed backdrop, spotlight and short coach-mark text; dismissing reveals requested control | Verified 018, 020, 025, 028, 031 |
| Style | Open style dropdown | Smooth-line and pixel-block icon options | Verified 023 |
| Accompaniment | Open music dropdown | Bass, Drum kit, Arpeggio, Kick, Snare, Clap and Hi-hat shown; many entries visually muted; functionality/gating tested separately where possible | Verified 026 |
| Key | Open key dropdown | All 12 chromatic names in a two-column grid; C/C#/D/D# appear unbadged, E–B carry lock badges | Verified 029, visual entitlement inference only until selection test |
| Scale | Open and scroll scale dropdown | Major pentatonic, Minor pentatonic, Major, Minor; Harmonic minor, Dorian, Phrygian, Lydian, Mixolydian, Blues, Chromatic shown lower with locks | Verified 032–033 |
| Backgrounds | Open background sheet | Color/Photo/Camera tabs, color presets, custom solid/linear/radial color controls, built-in photo row, opacity slider and Apply | Verified 035–039 |
| Camera | Open optional camera path | Android camera permission requested; human user granted and took photo; cropper appeared with grid/handles/rotate/flip controls | Verified screenshot + explicit human confirmation |
| Cropper Back | Cancel crop | Android Back did not visibly dismiss the cropper in captures; toolbar Back returned to background sheet | Verified 041–045; no photo applied |
| Clear | Reset own research drawing | Canvas cleared immediately; no confirmation captured | Verified 048 |
| Ads | Use canvas for an extended session | Multiple expandable ads layered over lower playback/instrument controls; closing reveals another ad or later replacement. Full-screen native ads also recur | Verified screenshots + hierarchy; trigger/frequency not established |
| External redirect | Attempt observed ad dismissal during research | Unexpected store and browser destinations occurred. Automation stopped, destinations closed; no intentional install/purchase | Verified 052, 059; exact SDK cause unverified |
| Rating | Continue testing | In-app five-star rating dialog overlays canvas; Android Back dismisses; repeated prompts encountered | Verified 056–057; no rating submitted |

## Experimental provenance

`experiments/<case>.json` contains gesture geometry, requested timing, action timestamps and recorder exit code. `videos/exp-<case>.mkv` contains screen and Android playback audio. Drawing states are saved as `screenshots/exp-<case>-drawn.png` and `…-playing.png`. Audio analysis is descriptive spectral analysis; it is not a reverse engineering of the proprietary algorithm.

Initial vertical/circle/zigzag/reverse runs were interrupted by advertisements and are quarantined under `invalid/`. Only retried captures at the main experiment paths are candidates for valid results. Review video and screen evidence before interpreting audio. Guarded retries check resumed app and UI hierarchy before input, cancel rating prompts with Back, and stop on unknown screens. Full-screen ads are now dismissed with Android Back after an observed X unexpectedly redirected externally.

## Not established by current evidence

Clean-install onboarding order; exact algorithm/quantization; physical haptics; end-to-end audio latency; full premium content behavior; purchase completion and restoration; ad frequency rules; all error states; other phone/tablet sizes; landscape and iOS behavior. Where the PRD specifies these, it labels them as new-product decisions or validation requirements.

## Final offline pass and exports

With explicit human permission, Wi-Fi and mobile data were temporarily disabled and subsequently restored to their original enabled states (1/1). Offline entry reached Home and the editor worked. Settings has twelve languages, app-link sharing, More app and an external privacy link; the privacy browser showed ERR_INTERNET_DISCONNECTED. The Library destination contains separate Draft and exported Library subtabs. The two preexisting drafts were not evidence of a research save. A known new two-line draft was later identified by its thumbnail and reopened, verifying its own content/settings. Opening/exiting an existing draft updated its sort position without content edits.

Export menu offers MIDI, WAV and MP4. Each was generated from the known research project offline and then saved through the app's visible Save action to `/sdcard/Download/DrawMusic/`. The output files were copied via ordinary ADB public-file access and inspected, with no access to private app internals:

- MIDI: SMF 0, one track, 480 PPQ, 120 BPM, end tick 3840 (8 beats), notes 72/60 at tick 640 through 3200, velocity 100, program 4. See `experiments/source-midi-inspection.json`.
- WAV: PCM16, 44.1 kHz mono, 5.230816 s, 461,402 bytes.
- MP4: H.264, 1136 × 1440, 60 FPS, AAC 44.1 kHz mono, 5.294150 s, 495,397 bytes. Frames show the existing drawing with a scan cursor, not editor/system chrome. No MediaProjection consent appeared.

Tempo plus advances by 1 BPM; slider endpoints are 60 and 200. Marimba/Bells retain amber/green strokes. Eraser cuts local gaps; Undo/Redo restore/reapply. Pixel selection converts existing lines into block rows. Long-pressing the brush did not expose a separate palette/size editor in the tested state. Instrument labels across the strip: Soft Key, Marimba, Bells, Warm Synth, Pluck, Flute, Strings, Chime, Bass, 8 bit, Electronic Bass, Guitar, Saxophone. Crown-marked options are visible; actual premium playback remains unverified. Selecting locked E offline left C selected with a connectivity toast. No rewarded execution or purchase was performed.

A final visual audit excluded the high-line run because an extra uncontrolled stroke appeared before/during playback. Device volume overlays appear in low/multi runs; pitch/geometry evidence remains qualified and cross-session amplitude comparisons are not controlled. Horizontal-video end contains an ad; only earlier unobscured playback supports its conclusions. Reverse/fast/slow are cleaner comparison clips. Both network settings are restored; no device configuration change remains pending.
