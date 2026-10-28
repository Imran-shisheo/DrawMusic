# Home scroll correction — 28 October 2026

Product checkpoint: `9f152e6d05800dd31c3b62f2145f8e39a0a1e1d2`.

Parent-coordinated Nothing A059P / Android16 / Impeller Vulkan /90Hz QA found debug UI/raster p95 of5.06/5.66ms idle,29.18/4.64ms scrolling into the gallery, and22.70/4.95ms warmed gallery. Root layout p95 rose from0.68 to23.86ms. These are supplied debug diagnostics, not profile/display acceptance; the nominal90Hz frame budget is11.11ms. This cloud executor did not operate the phone.

Source reproduction found a5px scroll replacing six retained template documents and invalidating all six painters. SliverLayoutBuilder rebuilt its delegate for scroll constraints; sleeve build regenerated immutable documents. Separately,16 actual8dp scroll steps repainted the unchanged Home preview16 times, including a100,000-point fixture. This establishes unnecessary work, not physical FPS.

The correction caches the sliver widget/delegate until column count changes, retains each template document in keyed sleeve state, and places only the artwork/paper preview behind a repaint boundary. The immersive scene, gestures and original artwork remain unchanged. Theme/locale/text scale dependencies still update descendants. Responsive column changes and selecting a template remain covered.

Three regressions exercise real Home widgets: ordinary and100,000-point previews produce zero unchanged preview paints over16 scroll steps, actual document revision changes repaint and change pixels, and retained template documents/painters survive scrolling. French semantics, theme caption color, text scaling, responsive columns and template navigation are explicitly checked. All three pass alongside the full local product gate; existing strict visual references remain unchanged.

The complete local gate passes383 Flutter tests/three explicit diagnostic skips, analyzer/formatter,76 real-font states/eight strict references, JVM tests, Android lint/build/v2 signing and12 interrupted writers with complete recovery. This does not establish frame-budget compliance. Fresh hosted native verification and paired physical profile comparison remain pending. The parent's separate QA task owns device installation/signing and capture approval; this executor must not uninstall or replace the owner's app.

Do not infer60FPS from exported video rates, software-emulator recordings, successful decoding, or these paint counts. No footage is padded, retimed or interpolated. Actual GPU/presentation pacing and physical audio acceptance remain separate.
