# Geometry simplification and history ownership

This is an original policy for F03/F06/F07 and QA03/QA05/QA08/QA18. It is not a reconstruction of a reference application's algorithm.

## Geometry

The document remains limited to 100,000 source points. Before a new gesture, an existing document with at least 80,000 points receives a deterministic simplification attempt. A successful change is a separate undoable edit before the new stroke. Finishing a very dense new stroke also attempts simplification within that gesture's single undoable edit. An optional `DrawingCanvas.onSimplified(before, after)` notifies presentation to explain the reduction; Undo restores the previous committed geometry. No stroke or instrument is discarded.

The maximum deviation is **0.75 logical reference dp on an 800 × 1000 document** (0.0009375 horizontal / 0.00075 vertical normalized units). This fixed document definition avoids changing saved music or geometry because of phone size or orientation. It is not a claim that 0.75 reference dp equals 0.75 physical screen dp on every viewport. This interpretation of the PRD's proposed tolerance is a new design decision.

The iterative Ramer–Douglas–Peucker pass runs between mandatory anchors: original segment endpoints around each of the 96 time-bin crossings and coordinate extrema. Canonical orientation makes distance tie-breaking independent of drawing direction. Dots, endpoints, sharp corners, vertical geometry and crossings retain their meaningful shape. Original retained `InkPoint` objects retain their timestamps. Clipping and simplification use `Stroke.copyWith`, preserving raw instrument IDs and unknown metadata.

A candidate must reproduce its original stroke's exact compiled instrument/pitch/start/end notes under the document's current root, scale and engine version. Pixel documents must also preserve their exact displayed cell set. If a replacement fails either check, the original stroke remains. Distance work is bounded to two million checks per attempt; exhausting the budget leaves the affected and later strokes unchanged. The anchor scan is linear in the already bounded input size. This pass is a synchronous pointer-boundary operation; it is not run on every pointer sample.

The compiler still merges identical occupied instrument/pitch/time cells. True scenes above the 32-voice/4,096-note safety budget remain explicit errors. Simplifying their image does not justify dropping audible notes or instruments. A complex scene may therefore remain unsimplified and require erasing, saving and starting a new drawing. If the point budget remains exhausted, the visible valid segment is committed once and the existing limit feedback remains available; no oversized document is constructed.

## History accounting

`DocumentHistory` retains at most **100 total Undo plus Redo commands** and **20 MiB of additional accounted retained history**, preserving the current document. The old sum-of-point-count approximation has been removed. The current working document is separately reported by `history.memory.currentDocumentBytes`; the history budget is not a limit on the app's entire process.

An identity ledger counts document/stroke/point-list/point ownership once across current, Undo and Redo. Geometry already owned by the current document does not consume additional history budget, so 100 tempo/title edits do not count one shared 100,000-point stroke 100 times. New geometry revisions do consume the budget. Furthest Undo commands are evicted first, then furthest Redo commands when necessary. Eviction never rewrites or simplifies the current document.

Accounting reserves conservative aligned bytes for document/scalar ownership, list containers and references, point objects, stroke metadata, unknown JSON metadata, background/crop ownership and accompaniment maps/levels. Every retained stroke reserves its cached bounds and a potential lazily materialized Pixel cache: at most `min(2000, 1 + 50 × (pointCount − 1))` entries at 64 bytes per entry plus container allowance. Switching to Pixel therefore does not create an unaccounted history cache. Image pixel bytes do not live in document/history; background definitions retain small immutable asset IDs and transforms. Render/decoded-image caches remain separate working-memory responsibilities.

These sizes are deliberately conservative **accounting assumptions**, not exact VM heap measurements or a proven 20 MiB process-RSS limit. Ledger traversal itself allocates temporary identity sets; garbage collection timing affects process RSS. Do not infer Android release memory/FPS, ten-minute physical drawing performance, or a device heap guarantee from this policy.

## Reproducible diagnostic

Run the pinned SDK after sourcing the cloud environments:

```bash
export DASH__SUPPRESS_ANALYTICS=true
dart run tool/measure_history_memory.dart > work/geometry-memory-report.json
flutter test --no-pub test/simplification_memory_test.dart test/history_test.dart test/canvas_reliability_test.dart
```

The Linux Dart VM diagnostic creates eight independent 100,000-point scenes, records every commit's accounted current/history bytes, Undo/Redo counts, elapsed time and actual process RSS/peak RSS, then moves history to Redo. It fails if additional history exceeds its accounting budget. RSS includes the VM, working geometry, ledger sets and unreclaimed garbage. The emitted SDK version and raw observations accompany the run; results must be re-measured when field ownership or cache policies change.

Focused cloud tests cover a dense 20,000-point curve's geometric bound, exact score, reverse invariance and JSON reopen; preserved dots/corners/vertical chords/erasure; work exhaustion and unsafe-score fallback; exact Pixel occupancy; shared/exclusive geometry accounting; cache reservation; total Undo/Redo limits; pre-limit simplification and reversible edits; and a genuinely unsimplifiable 100,000-point hard-limit canvas scenario. Physical Android memory/FPS and real long-session drawing acceptance remain pending.

Optional stylus input fields reserve **128 accounted bytes per point**, including conservative allowance for nullable pressure/tilt storage, source device code and VM alignment. The diagnostic must be rerun after this extension; earlier 64-byte-point observations do not validate its final budget. Full field/version policy is in [EXPRESSIVE-INPUT.md](EXPRESSIVE-INPUT.md).

### Observed cloud diagnostic — 26 October 2026

Pinned Dart **3.13.2**, Linux x64, eight independent 100,000-point scenes, final 128-byte-point accounting policy:

| Observation | Result |
|---|---:|
| Current document accounted bytes | 14,529,588 |
| Maximum additional history accounted bytes | 14,529,854 |
| Additional history budget | 20,971,520 |
| Retained exclusive old scenes at final commit | 1 |
| Final additional history bytes, after Undo | 14,529,214 |
| Process RSS baseline | 239,988,736 bytes |
| Observed process RSS range during samples | 194,846,720–329,469,952 bytes |
| Observed process peak RSS | 372,531,200 bytes |
| Observed commit duration range | 43,259–215,445 microseconds |

Raw output: `work/geometry-memory-report.json`. This run confirms the ledger's eviction behavior under actual allocations; it does **not** prove a 20 MiB retained heap, physical RSS limit, mobile frame budget or release performance. The relatively large process RSS includes the Dart runtime and transient accounting sets, and the synchronous commit costs need physical release profiling. Focused tests passed **18/18** across history, simplification, canvas limits and optional stylus metadata in `work/geometry-final-tests.log`; overall product/native gates are recorded by the integration checkpoint separately.

Automatic simplification also checks the additional ownership needed to retain its exact pre-change document as an Undo command. If that one snapshot would exceed 20 MiB (possible with many independent dense strokes and reserved caches), the candidate is declined and original geometry remains. It does not commit a supposedly undoable simplification whose predecessor would immediately be evicted. The explicit hard-limit repair path remains available. A 200-stroke/100,000-point regression independently demonstrates the over-budget case and exact source preservation.

## 27 October eraser capacity correction

Clipping can add two intersection endpoints, even when a source document is already at its valid 100,000-point cap. `eraseAt` remains a pure geometric operation; the canvas now checks the final gesture output before changing its committed stroke list or constructing a document. If it cannot fit, the exact previous document/history remains intact, the transient preview is cleared, and localized feedback explicitly says the erasure was not applied. It does not silently simplify unrelated artwork to force an erasure through. A gesture that temporarily exceeds the cap may still succeed if its final result fits; one accepted gesture is one Undo edit.

`test/eraser_point_cap_test.dart` reproduces 99,999→100,001 and 100,000→100,002 before the fix, then covers rejection, no-op, repeated gestures, subsequent usable input, exact-cap acceptance, Undo/Redo, real save/reopen and absence of autosave after rejection. Initial evidence: work/eraser-cap-before.log (five intended failures); focused corrected geometry/history/score suite: 35 passed in work/eraser-cap-safety.log. The complete new-source gate is recorded separately in DEVELOPMENT-STATUS.md.
