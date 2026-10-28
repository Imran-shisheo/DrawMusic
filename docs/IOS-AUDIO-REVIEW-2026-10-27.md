# 27 October iOS audio fix evidence

Findings 6/7/8 are fixed in source. `ios/AudioState/AudioSchedule.swift` is the same implementation used by the AVAudioEngine render adapter, not a Dart mock or separate scheduler simulation. The native adapter retains a distinct newest desired request while the audible pause position may still belong to an older revision. Resume restages that request at its declared beat/loop boundary without another Dart queue. Native current/target status remains consistent until the latest revision becomes audible.

A reset invalidates graph/control generations, preserves audible phase plus the newest request, disposes the stopped orphaned engine/source graph and constructs new AVAudioEngine/AVAudioSourceNode objects. Session playback/default/empty-options policy is restored, activation remains off, and only explicit Play resumes. Observer registration happens once in init. Generation guards reject old render pulls and delayed pause callbacks. Failed rebuild/start stays paused and can retry on explicit Play/Prepare.

Route notifications are classified from Apple's reason key. Expected category events, including ones delayed until after Play, are harmless; unexpected session policy, genuine removal, unsuitable output and relevant external changes pause. New devices/app overrides follow Apple's continuation policy; output timing caches refresh. End-of-interruption notifications neither auto-resume nor stop a newer explicit Play. If an otherwise harmless route event coincides with an actually stopped engine, the adapter invalidates the graph and logical playing state instead of showing a frozen playing clock. This was a defensive source finding, not a reproduced device failure; explicit Play rebuilds.

## Executed cloud proof

- Official Swift 6.1.2, x86_64-unknown-linux-gnu. GPG VALIDSIG fingerprint `52BB7E3DE28A71BE22EC05FFEF80A866B47A981F`; fingerprint cross-checked against Swift.org active signing keys; key fetched from official Swift website repository. Toolchain archive SHA256 `d749d5fe2d6709ee988e96b16f02bca7b53304d09925e31063fd5ec56019de9f`.
- Matching baseline extraction of the original pause/reset/unconditional-route semantics: **11 XCTest cases, 28 failed assertions**. This is a pure Swift reproduction of those source semantics, not execution of the old AVAudioEngine adapter or a claim about first-play hardware failure. Matching source/tests are retained in `work/ios-audio-review/baseline-package/` and baseline.log.
- Fixed implementation: **15 XCTest cases, zero failures**, including positive-latency target adoption, before/after-boundary pause, no-requeue resume, repeated tempo/edit/pause changes, paused queue, current/target reporting, reset during play/repeated reset, stale graph/fade rejection, delayed category events, interruption begin/end policy and a defensively handled halted graph after an otherwise harmless route event.
- `swiftc -frontend -parse` accepts native/helper/test source grammar. This does **not** resolve/typecheck Apple frameworks or establish an iOS build.
- Missing-compiler negative check exits 2. The check script never claims a skipped pass.

Cloud command (HOME stays unchanged):

```bash
DRAWMUSIC_SWIFT_TOOLCHAIN=/workspace/drawmusic-tools/swift-6.1.2 bash scripts/check-ios-audio-state.sh
```

When swift/swiftc are already on PATH, run `bash scripts/check-ios-audio-state.sh`. Package has no remote dependencies. Logs: `work/ios-audio-state/{compiler,tests,grammar}.log`, and `work/ios-audio-review/{baseline,toolchain-signature,final}.log` / report.json.

## Primary references

Checked on 27 October 2026:

- [Apple media-services reset guidance QA1749](https://developer.apple.com/library/archive/qa/qa1749/_index.html): recreate audio objects, restore session properties, do not reactivate before user action, no observer re-registration needed.
- [Apple route-change guidance](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html): inspect reason/previous route, pause for removal, continue for insertion/override, refresh relevant hardware timing.
- [Apple current RouteChangeReason documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangereason): category changes are a distinct documented reason. The earlier source risk was not a reproduced first-play device failure.

## Mac/device acceptance remains unrun

Build with the pinned Flutter SDK on a Mac, then run the Xcode RunnerTests target (now includes the same 15 state cases plus existing renderer cases) and the iOS integration smoke flow. AVFoundation/UIKit typechecking, graph behavior, real notification ordering, audible ramp/latency/clock drift and physical routes are **not verified by the Linux tests**.

Actual reset steps: enable iOS Developer Mode/Developer settings through normal local Xcode setup if absent. Open a drawing and Play. Queue an audible geometry/instrument or tempo change; switch to **iOS Settings → Developer → MEDIA SERVICES TESTING → Reset Media Services**. Returning to DrawMusic must show paused playback, preserve the drawing and newest desired snapshot and never auto-start. Explicit Play must recover audio using the newest request; Replay must prepare from the current drawing. Repeat during pause, an update, rapid pause/resume and after several resets. Confirm no duplicate sessions/observers, no old delayed fade pausing new playback and no permanent pending-update badge. Collect actual device/OS/route/log evidence before claiming native acceptance.

Also test first/repeated Play with delayed category/configuration events, headphone/Bluetooth removal, insertion, AirPlay/override, call/Siri interruption, background/foreground and changes to system output. Never operate the owner's personal phone from cloud.

The matching intentionally failing extracted baseline fixture is now committed under [review-fixtures/ios-audio-baseline](review-fixtures/ios-audio-baseline/README.md), outside shipping sources and normal passing gates, so the before/after source-semantics reproduction is reviewable. It remains distinct from actual old AVFoundation execution.
