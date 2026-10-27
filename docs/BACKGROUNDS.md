# Original backgrounds and private image imports

Implemented source scope, 26 October 2026. Background metadata is independent of
score geometry and engine version. Older ARGB-only documents remain schema 1;
using the expanded `paper` object upgrades the document format to 2 without
changing its sound version. `BackgroundDefinition` is pure Dart and records solid,
linear or radial colors, independent opacity, or a content-addressed photo with a
normalized source crop, clockwise quarter-turn rotation and mirror. Linear
presets interpolate top-left to bottom-right; radial gradients use the document
center and half its longest side. Three original two-color palettes were created
for this app; no reference-app images or artwork are packaged.

The expanded paper panel is a local Preview/Cancel/Apply transaction. Choosing a
photo imports an immutable private asset but does not change the project until
Apply; Cancel preserves the document. Crop sliders operate in normalized source
coordinates and retain at least 5% per axis. Rotate, mirror and Reset crop are
nondestructive metadata edits. Removing the photo selects the original warm
paper. Missing or corrupt assets leave the drawing accessible and expose a
Replace/Remove repair path. Background changes do not generate musical notes.

## Picker and asset safety

Android's `scribblesong/backgrounds` native channel uses the API 33+ system photo
picker and the system Open Document picker on API 24–32. Camera capture delegates
to an installed camera app with `ACTION_IMAGE_CAPTURE` and a read/write URI grant
for one app-owned temporary file. This flow does not require broad storage or
media access, and the application does not request microphone access. Camera-app
permissions remain that application's responsibility; unavailable activities,
security denial, cancellation and invalid image input have distinct results.

The import worker streams at most 32 MiB to a temporary file, inspects image
bounds (at most 80 million source pixels), samples decoding to at most 2048 pixels
per side, normalizes all EXIF orientations, then writes and flushes a PNG. HEIC is
accepted only when the OS decoder supports it; unsupported/corrupt inputs report
an actionable import failure. PNG content SHA-256 names are constrained to 64
hexadecimal characters. Publication uses a same-directory temporary/rename;
existing valid immutable assets are reused. Original capture/import temporary
files are cleaned after the job, and failed jobs do not publish asset metadata.

Android assets live in `Context.filesDir/backgrounds`, matching
`getApplicationSupportDirectory()/backgrounds`; this differs from the document
export directory (`app_flutter/exports`). iOS uses Application Support under the
same portable Dart contract. There are no remote image URLs or content uploads.
The picker stores pending source/capture information and completed metadata so
`recover` can retrieve an interrupted selection after Activity recreation. Completed Android metadata is synchronously committed on the import worker before the success callback and remains available through repeated recovery reads until Dart validates it and sends `acknowledge`. iOS also retains recovery metadata until acknowledgement. The paper panel offers the recovered image as a preview; it never auto-commits it.
Transient URI grants can expire after process loss; recovery then reports a
failure and permits choosing again rather than claiming successful import.

Photos referenced by a project, its Undo state, duplicate or retained revision
share an immutable asset ID. There is deliberately **no destructive asset garbage
collection** in this checkpoint: Cancel may leave an unreferenced private PNG,
but a delete or crop cannot remove another project's image. A future collector
must enumerate all live, retained, deleted-with-Undo and recovery references
before deleting anything. Project deletion currently preserves assets.

## Rendering and bounded ownership

`paintBackground` is the shared Flutter document-coordinate renderer used by
`BackgroundSurface` and PNG export. The normal base is white; opacity composites
the selected background onto that base. Photo crop is applied in source space,
then rotation/mirror and aspect-cover produce the document picture. Surface
widgets own bounded decoded images with generation guards and disposal; history
retains only metadata. `BackgroundAssets.decode` verifies content hash and
encoded/dimension budgets before bounded decode. PNG fails honestly for a missing
photo instead of publishing a substitute as successful photo export. Transparent
PNG intentionally omits the entire background.

Android MP4 and iOS source ports implement the same serialized background
contract. Native compile/runtime and visual parity are tracked separately from
these pure/rendering tests; iOS remains uncompiled until Mac validation.

## Evidence and remaining acceptance

`flutter test --no-pub test/background_model_test.dart test/background_panel_test.dart`
passes eight tests: picker metadata/acknowledgement/cancel validation; malformed
crop/asset rejection and future-kind retention; format-2 persistence with unchanged
score/PCM; actual gradient/opacity pixels; content hash/tamper/missing/shared-ID
handling; source crop/quarter-rotation output; transactional gradient Apply/Cancel; and unavailable camera/canceled picker at 320 dp with 200% text. Focused analyzer reports zero issues. Native `BackgroundImportTest`
adds real EXIF normalization/content SHA/deduplication and corrupt-input
non-publication cases. `DocumentFramesBackgroundTest` adds four native raster cases covering all 13 catalog colors, gradient/opacity compositing without accumulation, photo SHA/crop/quarter-turn/mirror/opacity and missing-photo failure. Their execution is recorded in the overall product run,
not inferred from source.

Physical camera-app behavior, one-time/permanent denial variants, HEIC support
across vendors, real Activity death/grant expiry, actual low-storage/power-loss,
TalkBack and iOS compile/device behavior remain open until observed. No physical
image-memory/FPS guarantee follows from the decode budgets or Linux tests.

Primary API references: [Android photo picker](https://developer.android.com/training/data-storage/shared/photopicker),
[ExifInterface](https://developer.android.com/reference/android/media/ExifInterface),
[FileProvider](https://developer.android.com/reference/androidx/core/content/FileProvider).
Android EXIF parsing uses the pinned maintained AndroidX `androidx.exifinterface:exifinterface:1.4.2` (Apache-2.0), replacing the older OS-bundled parser. Google Maven primary metadata checked 26 October 2026 lists 1.4.2 as the newest stable version; 1.5.0-alpha01 is pre-release and is not selected. Metadata: https://dl.google.com/dl/android/maven2/androidx/exifinterface/exifinterface/maven-metadata.xml. No new Flutter package was added.
