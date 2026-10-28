# Intentionally failing source-semantics reproduction

This is a faithful extracted pure-Swift model of the pre-fix pause/reset/unconditional-route semantics from merged baseline a7c3670, paired with the original eleven regression cases. It is NOT the old AVAudioEngine adapter, an Apple-framework test, an executed first-Play failure or shipping code. The fixed render-used implementation and its fifteen passing cases live in ios/AudioState and ios/AudioStateTests.

Reproduce manually with an installed Swift compiler:

```bash
swift test --package-path docs/review-fixtures/ios-audio-baseline --scratch-path work/ios-baseline-replay
```

Expected result: nonzero exit, eleven XCTest cases with twenty-eight failed assertions. This deliberately red fixture is outside application targets and normal passing gates. It makes the source-semantics reproduction reviewable; it never substitutes for actual iOS validation. See docs/IOS-AUDIO-REVIEW-2026-10-27.md for evidence and limits.
