# Creation-loop performance checks

Measured 24 October 2026 in the selected Linux cloud environment with pinned Dart 3.13.2. These CPU diagnostics do not establish Android frame rate, audio latency, memory pressure or thermal performance. Run `dart run tool/profile_creation_loop.dart` after sourcing the cloud environment.

The original synthetic fixture contains 100 strokes × 1,000 points (the 100,000-point project limit), three instruments and no reference-app media. Each measurement warms up once and reports the median of seven runs in the same workspace. Measurements use the Dart VM, not a release Android build. Bounds are warm after the first eraser query.

| Operation | Before (µs) | After (µs) |
|---|---:|---:|
| 12 title commits | 1,491,721 | 253 |
| 20 eraser misses | 210,774 | 1,458 |
| Compile score | 12,283 | 11,868 |
| Encode project | 62,211 | 58,772 |

Title/tempo edits no longer encode two complete JSON documents to compare history states. Semantic no-ops preserve redo and do not publish an audio revision. Cached immutable point counts and stroke bounds avoid repeated full scans; eraser rejection is conservative and exact segment clipping remains unchanged. Score/encoding algorithm speed is effectively unchanged: compilation plus synthesis, accessible score description, JSON and checksum work now run in workers to reduce UI-isolate stalls.

Pointer sampling appends to a private mutable preview instead of copying every preceding sample. A notifier explicitly repaints that preview; committed geometry remains immutable. Document metadata refresh and parent acknowledgement of a previous commit preserve an ongoing gesture. External geometry replacement still clears it safely. Separate drawing/preview/cursor repaint boundaries remain in place.

Regression checks exercise the real pointer path with 10,000 new samples alongside 90,000 existing points, metadata refresh during a gesture, delayed parent acknowledgement, immutable prior strokes, point-budget enforcement, semantic undo/redo, eraser crossing and untouched-stroke identity. A real-file 100,000-point round trip checks duplicate-save handling and serialized renames. Existing deterministic score and export parity tests remain required.

Pending: release-build device frame timings, long-session memory/thermal measurements, low-storage and process-kill recovery, physical audio and sharing acceptance. Synthetic CPU timings alone do not close the M5 gate.
