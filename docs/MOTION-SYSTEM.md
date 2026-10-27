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

The root-navigation profile phase may resume Home at a retained scrolled position, where ambient art is paused. It measures that actual navigation phase and must not be labeled a visible-sculpture benchmark. The final harness implements a separate17-second visible-Home ambient phase without screen recording; completed execution remains pending. The recorded observation then holds for40 real seconds and independently requires at least16 encoded seconds, full decoding and actual unwrapped sculpture-controller advancement through its authored period. No padding, repeated frames or retiming is allowed. Recorder overhead makes this separate from the unrecorded frame-timing benchmark.
