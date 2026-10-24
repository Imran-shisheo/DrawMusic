# Original display style policy

Smooth renders the normalized source polyline and round dots. Pixel fills occupied cells on an original fixed grid of 40 columns × 50 rows. The 4:5 canvas makes cells square at its normal aspect ratio; previews and video use the same normalized grid at every resolution. Pixel cells have hard edges and retain each stroke's named instrument color. Source stroke width remains stored and is used again in Smooth.

Each normalized point maps by floor(u × 40), floor(v × 50), clamped to the last cell at the right/bottom edge. Sparse segments connect with symmetric integer-weight interpolation over max(abs(delta column), abs(delta row)) steps, rounded to the nearest cell. This policy is identical in Dart and Kotlin and symmetric under drawing-order reversal. Occupancy is bounded to 2,000 cells per stroke and cached only for immutable committed strokes; active preview occupancy remains local to the canvas.

Styles are display-only. They never resample, quantize or replace editable source points, never alter the deterministic score, and never request a new audio render by themselves. Switching back restores the exact smooth geometry. History treats style selection as a reversible visual edit. Save/reopen, duplication, thumbnail snapshots and MP4 retain the selected style.

`style` is an optional schema-1 document field (`smooth` or `pixel`). Older files without the field default to Smooth; unknown values fail without deleting the original. Engine version stays 1 because musical mapping is unchanged. The native video renderer also defaults missing style to Smooth and rejects unknown styles.

Automated coverage includes sparse/boundary/dot/reversed geometry, the 100,000-point input budget, real file reopen/duplicate, unchanged score/PCM, Undo/Redo/cancel, and actual Dart pixel painting. Native offscreen rendering and independent FFmpeg cell-area inspection are included in the hosted gate. Physical TalkBack, device rendering and long-session performance acceptance remain separate checks.
