# Before graphite: actual widget baseline

Source: main `a7a8e595d96735c9b5db607c8d03d785937edf15`, identical file content to accepted75e708d. These are original actual Flutter widget PNGs with explicit bundled fonts and deterministic repository/preferences/audio/export fixtures. They are not approved ImageGen boards, redesigned screens, Android screenshots, native audio results or physical frame-pacing acceptance.

The existing capture test passed and rendered76 states. The four PNGs below were visually inspected and copied without image modification; [provenance](provenance.json) records their byte lengths/SHA256. The full local matrix and harness manifest remain under ignored `work/graphite-baseline-a7a8e59/`; only these four representative images are committed. No reference was regenerated and no full product gate is claimed for this documentation-only checkpoint.

- [Home](01-home-immersive-dark-phone.png): existing navy/ribbon hero, real fixture artwork, original template previews and retained dock.
- [Drafts](02-drafts-dark-phone.png): shared Drafts/Exports selector, actual fixture thumbnails, names and overflow actions.
- [Editor](06-editor-immersive-dark-phone.png): stable4:5 document, drawing/history tools and current voice/transport/music controls.
- [Export](09-export-immersive-dark-phone.png): four real intent choices, document preview, current image settings and Export action. The complete options/control inventory remains authoritative when adapting this layout.

Capture command after sourcing the pinned toolchain/environment:

```bash
flutter test --no-pub test/ui_visual_capture_test.dart \
  --dart-define=UI_VISUAL_CAPTURE=true \
  --dart-define=UI_CAPTURE_IMMERSIVE=true \
  --dart-define=UI_CAPTURE_DIR=work/graphite-baseline-a7a8e59
```

The approved Graphite Review, Motion Storyboard and complete Motion Plan inputs remain inaccessible in this cloud session. These baseline screenshots do not substitute for inspecting those approved inputs before implementation. See [the exact blocker and continuation sequence](../../GRAPHITE-IMPLEMENTATION-PLAN.md).
