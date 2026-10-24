# Screen evidence catalog

Raw captures are in `screenshots/`. Device coordinates are 1080 × 2392 px; density is 420 dpi, giving 2.625 px per logical dp. XML bounds verify hit regions where available; visual typography/radii remain estimates. Filename labels describe capture intent, and the verified state below takes precedence.

| Reference | Verified state / purpose | Notes |
|---|---|---|
| 001-launch | Full-screen launch video ad, “Ad 1 of 2” | First captured state; not an app feature illustration |
| 002-launch-ad-end | Same ad still playing | Filename does not imply it had actually ended |
| 003-after-ad-back; 004-current; 004-current-direct; 005-loading-back | Dimmed gallery and animated WAIT / Loading ad… | Back did not dismiss loading in these captures |
| 006-relaunch | Illustrated Loading Data… splash | Ordinary force-stop/relaunch; original artwork reference only |
| 007-post-relaunch | Launch ad overlay with Continue to app | Explicit continuation control used |
| 008-home | Welcome / START screen | Filename is misleading; not gallery |
| 009-start-result | Premium offer, weekly trial selected | Monthly alternative visible; no purchase initiated |
| 010-premium-monthly | Monthly offer selected | 39 AED/month shown on this device/session |
| 011-home; 012-home-hierarchy | Gallery top with Home selected | Abstract, Bear, Beat 1–3, Bird, partial Bird 2 and Boat |
| 013-new-canvas | Gallery-to-canvas transition | XML reached canvas before screenshot; use 014 for settled layout |
| 014-canvas-empty | Blank canvas, no ad yet | Primary clean canvas visual reference |
| 015-horizontal | Paused horizontal stroke | Soft Key purple stroke |
| 016-horizontal-playing | Scan cursor intersects the stroke | Pause replaces Play |
| 017-paused; 018-draw-styles | Tempo coach mark | Contextual tutorial; verify 018 image |
| 019-tutorial-next | Canvas after dismissing tempo tip | No menu |
| 020-styles | Drawing-style coach mark and expanded lower ad | Smooth lines / pixel blocks guidance |
| 021-style-tip-dismissed; 023-style-options | Smooth/pixel style dropdown | 022 is closed dropdown |
| 025-background-music | Accompaniment coach mark | Bass, drums, arpeggio explanation |
| 026-background-music-menu | Accompaniment dropdown | Bass, Drum kit, Arpeggio, Kick, Snare, Clap, Hi-hat |
| 028-key-tip | Key coach mark | Starting-note explanation |
| 029-key-menu | Key dropdown | C through B; lock indicators on later keys |
| 031-scale-tip | Scale coach mark | Notes shaped by scale |
| 032-scales; 033-scales-scroll | Scale dropdown, top and scrolled | Free-looking first four; later scales show locks |
| 035-canvas-backgrounds; 037-color-back | Background color sheet | Color/Photo/Camera tabs, opacity, Apply |
| 036-custom-background-color | Custom color/linear/radial editor | Hue, Opacity, Tone; header back/check |
| 038-photo-background | Built-in photo-background row | Import tile plus bg_1–bg_4 visible |
| 039-camera-background | Camera background tab | Camera action tile |
| 040-camera-permission | Android camera permission prompt | Human subsequently granted permission |
| 041-camera-denied | Photo cropper after human-assisted camera capture | Not denial evidence; misleading filename retained for provenance |
| 042-background-dismissed; 043-ad-collapse; 044-current-crop-state | Cropper, sometimes black preview | Android Back did not visibly leave it; toolbar Back worked |
| 045-crop-back | Returned to Camera background sheet | Crop not applied |
| 046-canvas-return; 047-collapsed-ad; 048-clear-action; 049-ad-collapse-second | Canvas with changing expandable ad overlays | Reset clears research drawing immediately |
| 050-horizontal-clean; 051-play-above-ad | Horizontal baseline and playing scan | Play target partly covered; exposed edge responds |
| 052-store-back | Unexpected store overlay | No deliberate install/purchase; excluded from app screen design |
| 053-store-closed | Full-screen native ad over canvas | Explicit X used |
| 054-interstitial-dismissed; 055-pre-experiment | Canvas recovered, horizontal drawing retained | Ad remains over bottom controls |
| 056-interruption | In-app rating dialog | Five stars, dimmed canvas, decorative illustration; no rating submitted |
| 057-rating-dismissed | Canvas recovered with Android Back | Rating prompt cancelled |
| exp-horizontal-* | Valid controlled horizontal experiment | Recorded audio and video |
| exp-vertical-* | Retried valid vertical experiment | Initial recordings quarantined under invalid/ |
| exp-circle-* | Retried valid circle experiment | Polygonal approximation drawn as one continuous touch |

Additional settled screens and experiments are appended as exploration proceeds. Intermediate closed-menu captures are retained as evidence but do not define additional screen types. See `evidence/research-scope.md` for limitations and human assistance.

## Final exploration additions

| Reference | Actual state / significance |
|---|---|
| 058/061 evidence XML | Guard stops: native full ad / exit project modal |
| 059; 060 | External ad browser destination and return; not a production screen |
| 062; 095; 098; 137 | Exit project / Stay modal |
| 063; 064 | Full-screen native ad still present; labels describe action intent, not successful dismissal |
| 065–069 | Recovery loading, app-open ad, Welcome, Premium and gallery; some captured states reflowed as ads loaded |
| 070 | Unexpected external store overlay, not Library; fixed-coordinate target was invalid after ad reflow |
| 071 | Existing store overlay remained in front of attempted offline launch; not evidence of app offline-start failure |
| 072 | Launcher search after closing store; excluded from curated gallery |
| 073–074 | App opened offline; Welcome then Home without new ad gate |
| 075 | Populated Draft subtab, two preexisting drafts; filename “empty” is incorrect |
| 076 | Exported Library empty state, “No data available” |
| 077 | Settings: premium banner, Language, Share app, More app, Privacy, version |
| 078–079 | Twelve-language selector, top and end of list |
| 081 | Native app-link share sheet; canceled; device-specific suggestions omitted from curated gallery |
| 083 | External Privacy Policy URL with Chrome ERR_INTERNET_DISCONNECTED |
| 085 | Blank offline editor |
| 086 | Rating dismissed; no export menu in this capture |
| 087; 101; 107 | MIDI/WAV/MP4 export format chooser |
| 088 | Exported Library now contains generated WAV |
| 089 | Native Open with chooser for WAV; no default app selected |
| 091; 103; 110 | Export artifact overflow with Save / Share |
| 092; 104; 111 | Returned from local Save; exported files independently verified in Downloads |
| 093; 096; 099; 105 | Draft list with new recognizable two-line test and existing projects; list reorders after exit |
| 094; 097 | Existing pixel project opened without edits; filenames incorrectly imply the two-line research draft |
| 100; 106 | Correct known two-line research project reopened at 120 BPM, C, major pentatonic |
| 102 | Library contains newly generated MIDI and WAV |
| 108 | “Exporting Video Recording” processing dialog; no system screen-recording request appeared |
| 109 | Library contains generated MP4, MIDI and WAV |
| 112 | New isolated tool-test project |
| 113 | Tempo plus changes 120 to 121 |
| 114–116 | Tempo panel; slider endpoints 60 and 200 BPM |
| 118–121 | Marimba/Bells selection and distinct amber/green strokes |
| 123–125 | Segment erasure and visual Undo/Redo result |
| 126 | Warm Synth access attempt; no entitlement completion established |
| 127; 130 | Instrument strip middle/end; full labels inventoried |
| 129 | Pixel conversion of erased two-color research strokes |
| 131–132 | Key menu and locked E selection; C retained; offline connectivity toast |
| 133–135 | Accompaniment choices / Bass access attempt / menu dismissal |
| 136 | Long press on brush; no additional size/color picker appeared in this tested state |
| 138 | Normal save/exit returned to Home |

The curated HTML index selects representative, settled states. It omits duplicate transitions, unrelated external app screens, the native recipient suggestions and the human's photograph. Raw captures are retained locally for provenance. `exp-high-*` still images do not make the full high-line run valid; its video contains an uncontrolled extra stroke and is excluded.
