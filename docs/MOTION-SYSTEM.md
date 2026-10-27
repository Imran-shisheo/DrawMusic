# Motion system

27 October 2026. Implemented motion tokens; final visual and profile acceptance pending.

| Motion | Purpose and trigger | Duration / curve | Interruption and reduced motion |
|---|---|---|---|
| Press/selection | Immediate touch/selected feedback | 120 / 180 ms, ease-out | Retarget from current state; static selection under reduced motion |
| Root branch | Explain destination change without losing branch state | 260 ms, ease-out cubic, at most 12 dp | Keep navigator children mounted; rapid switches retarget; reduced motion changes immediately |
| Forward/back | Establish page hierarchy | 320 / 240 ms, ease-out cubic | Reverse with route; no large translation under reduced motion |
| Sheet | Focused controls over the current project | 300 ms forward / 240 ms reverse | Native modal ownership and Back remain authoritative; immediate under reduced motion |
| Format/state change | Reveal relevant export options or real job state | 180 ms, ease-out | Preserve job owner, no fake progress; immediate layout/state under reduced motion |
| Ambient motif | Quiet invitation in bounded Home/welcome/empty artwork | 16 s cycle, smooth periodic curve | Pause offscreen, hidden branch and app background; static original art under reduced motion |
| Playback feedback | Show the actual audio-owned position/state | Real native audio clock | Essential stable position remains available; no independent beat scheduler |

Keep animation state local to presentation widgets. Use repaint listeners for decorative paths, separate from document, canvas/pointer and cursor repaint boundaries. No geometry serialization, project mutations or full editor rebuilds per animation tick. Do not animate canvas constraints, pointer targets or readable content during drawing. Avoid unconditional entrance cascades on branch return.

Test rapid switching, Back during transitions, retained scroll/dialog/language/editor/audio state, hidden/background ticker suspension and reduced-motion semantics. Use bounded deterministic pumps for looping decoration. Actual cloud emulator recordings and profile UI/raster timings must substantiate runtime claims; debug rendering alone is not a smoothness measurement.

## Immersive sculpture implementation

The 16-second Home sculpture is original decoration, not an audio meter. The broad gradient and ribbon use one explicitly bounded static texture, with the original vector art visible until allocation completes or if it fails. Each texture is limited to1,048,576pixels/2048pixels per dimension, with one resident image and one in-flight replacement; these are owned-image limits, not a whole-process memory claim. Size/theme/scale changes coalesce, and obsolete or disposed completions release their images. Reduced/hidden/background first presentation avoids unnecessary cache allocation.

A local transform supplies the same bounded periodic float; a separate repaint boundary draws the live traveling highlight and three orbital accents. The highlight wraps across the path boundary, and orbital phase uses a complete integer cycle. Eight focused resource/visual/lifecycle checks pass, including no neighboring10k-artwork rebuild/repaint across40ticks. Same-phase fallback-to-texture mean absolute RGB delta is0.698/255 from antialias resampling, with original composition/palette retained in inspected images. This proves isolation and visual continuity, not native speed: a new actual profile is required. Reduced motion retains static original art. No animation writes project state or enters document thumbnails/exports.

The first native after-capture attempt failed at the emulator recording encoder and also exposed insufficient presentation readiness. It is diagnostic only. Actual motion clips, final-source UI/raster measurements and physical-device acceptance remain pending; passing pixel tests do not establish frame rate.

The root-navigation profile phase may resume Home at a retained scrolled position, where ambient art is paused. It measures that actual navigation phase and must not be labeled a visible-sculpture benchmark. The final harness implements a separate17-second visible-Home ambient phase without screen recording; the latest final-app partial capture completed this phase with 46 frames over18.395seconds. It observed the real774×816 cache resident in all34 samples; UI p95 was6.770ms and raster p95 was470.004ms, with all46 raster frames over the16.67ms budget. This is severe software-emulator raster cost, not physical-device performance or a proven optimization speedup. The recorded observation then holds for40 real seconds and independently requires at least16 encoded seconds, full decoding and actual unwrapped sculpture-controller advancement through its authored period. No padding, repeated frames or retiming is allowed. Recorder overhead makes this separate from the unrecorded frame-timing benchmark.


## Earlier inspected final-app partial capture

Application f9fc4ba / harness de6fc14, run40550097229, independently inspected by40555660399: actual ambient video41.071344seconds/97frames, PTS0→40.6084seconds, complete host and independent decode passed. The actual controller advanced17.916666seconds against17.714808seconds of sampled Stopwatch time during the unrecorded phase; all sampled states remained resumed/animating/TickerMode enabled with reduced motion false. No clock or footage was padded, retimed or repeated.

This run passed actual native keyboard-inset/focus/panel-bound checks and recorded Home/root navigation, then failed its drawn-editor screenshot witness because the browser-style URL remained/home under imperative push. The capture-only correction uses the actual canvas route with unchanged current/transition/rendered/modal guards; a real router regression passes. The partial artifact does not accept the remaining editor/Back, paper, playback, export, reduced-motion, compact/tablet or cool-light flows on this final source. Its keyboard PNG lacks visible keyboard keys despite real inset/focus evidence. The corrected exact-source capture and complete profile matrix remain pending. Earlier complete recordings belong to their explicitly recorded earlier application source.

## Public-run observation and recovery

The same appf9fc4ba with harness5c4a7be ran publicly in40560035660 attempt3. Reader40594654948 independently decoded the original40.580256-second/174-frame ambient recording (PTS0→40.557511s); its actual controller advanced39.899999s over40.000687s. The separate unrecorded Home profile observed83frames/17.807834s with UI p954.628ms and raster p95234.942ms; all83 raster frames exceed16.67ms. All34 samples retain the actual774×816 cache. These are real renderer/clock observations, not smoothness acceptance or a causal cross-run speedup.

Reader40598222546 also independently verified original hashes/byte counts and completely decoded all six interaction clips: root navigation31.177878s/117frames; editor/Back8.262700s/41frames; paper12.060967s/44frames; instrument/playback16.394811s/66frames; export-ready16.806500s/55frames; reduced motion5.172956s/28frames. Original footage is unchanged and silent. The parent capture still has passed:false after late VM/ADB loss; media decoding does not accept frame pacing or missing responsive states.

Harness2fcfea0 separates responsive presets into fresh app/emulator sessions, and introduces a diagnostic-only17s normal/17s solid Home radial-backdrop comparison. It retains the same mounted Aurora State/controller/cache, natural frame clock, geometry, theme and lifecycle; only the exact full Home backdrop radial shader changes to its existing opaque surface color. It restores the exact original decoration and requires two matching natural engine-raster completions. This produces separate diagnostic profiles, never substitute normal footage or altered project art. Results are pending; no optimization is attributed before measurement.
