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

The 16-second Home sculpture is original decoration, not an audio meter. A retained static repaint layer contains the broad gradient and ribbon. A local transform supplies bounded periodic float; a separate painter draws the traveling highlight and three orbital accents. The highlight wraps across the path boundary, and orbital phase uses a complete integer cycle. Rendered tests cover both loop continuity and hidden/background/reduced-motion suspension. Reduced motion retains a static luminous composition. No animation writes project state or enters document thumbnails/exports.

The first native after-capture attempt failed at the emulator recording encoder and also exposed insufficient presentation readiness. It is diagnostic only. Actual motion clips, final-source UI/raster measurements and physical-device acceptance remain pending; passing pixel tests do not establish frame rate.
