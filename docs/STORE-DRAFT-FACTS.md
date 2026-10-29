# Doodimo store draft source facts — 29 October 2026

These facts describe the enclosing owner-approved identity checkpoint, not a production release or completed store questionnaire. Store-console preparation is handled separately; this cloud task does not register IDs, create signing credentials, upload AAB/IPA files or submit/release an app.

## Identity and compatibility

| Field | Current source / executed evidence |
|---|---|
| Display name / tagline | Doodimo / Draw your sound |
| Planned store title | Doodimo: Draw Music; no reservation or legal-clearance claim |
| Android applicationId and namespace | com.devwithdelta.doodimo |
| iOS Runner Bundle ID | com.devwithdelta.doodimo in Debug, Release and Profile |
| Test identities | Android com.devwithdelta.doodimo.test; iOS com.devwithdelta.doodimo.RunnerTests; no extension targets |
| Version | 2.1.0+24 |
| Android | MinimumAPI24, target/compileAPI36, verified in current debug APK and generated manifests |
| iOS | Source deployment15.0; Apple-framework compilation/archive/device validation not executed on Linux |
| SKU | No existing SKU documented in repository; owner/store setup remains separate |

The technical-ID change creates a separate installed application and private sandbox. Existing old-ID user files are untouched; no automatic migration, old-app uninstall or access to its private data is claimed. Internal Dartpackage, methodchannels and saved schema/engine formats remain unchanged.

## Implemented product claims

Offline drawing-to-sound creation;13original voices;12keys/11scales;20original templates; Draw/Erase/Undo/Redo; tempo/expression/accompaniment mix; style and color/gradient/photo/camera/crop paper; local autosave/reopen/recovery; Drafts/Exports with file actions; PNG/WAV/MP4/MIDI, with compact/HD and30/60FPS video options; light/dark/reducedmotion;12locales/373keys. All creative features are free. MIDI playback/timbre depends on the receiving player. Do not claim AI generation, microphone recording or background playback.

Final local checks on the new ID pass:417Fluttertests/three diagnostic skips,213formatted Dartfiles/zerochanges, analyzer0,78real-font states/eight unchanged strict references,24JVMtests/zeroerrors, Androidlint, actualdebugAPK/v2signature and12interrupted-writer recoveries. Instrumentation APK builds with the new target package. Individual debug APK SHA256f3c9bf040177ca88900714a97119bd68079f8e4b64944cefaaf7fb0bbf85ea67. New-ID native emulator/media/motion acceptance remains pending. Earlier hosted native cases/soaks belong to the former app ID and do not establish new-ID acceptance. Physical audio/routes/latency/performance/stylus/accessibility/recipient-app checks and human translations remain separate.

## Permissions and data behavior

The actual generated release merged manifest declares only com.devwithdelta.doodimo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION, signature-scoped. It declares no Internet, microphone, camera, broadstorage, location, contacts or notification permission. Debug/profile Internet permission is for Flutter tooling; debug integration-test dependencies add REORDER_TASKS, which is absent in the release manifest. Release-manifest generation is not a releaseAPK/AAB or signing validation.

Photo import/camera and public save/share use user-chosen system intents/providers and URI grants. Source audit found no app-owned HTTPclient/upload service, accounts, ads, billing, analytics/tracking SDK or server. Native path_provider/share_plus/package_info_plus/in_app_review and Flutter/localizations are included. Optional store reviews invoke GooglePlay/SKStoreReviewController; the store controls that flow. Google's official [In-App Reviews Data Safety description](https://developer.android.com/guide/playcore/in-app-review) describes user-entered ratings/review text handled by Play. Avoid absolute claims that no external service ever handles data. User-selected recipient apps/document providers may upload files according to their own behavior.

Android allowBackup/dataExtractionRules and iOS backup exclusions are not explicitly configured; OS-managed backup behavior remains to be reviewed. Do not describe local-first storage as a guarantee that data can never leave the device. Final privacy-policy/store questionnaire responses must match actual platform/SDK behavior.

## Release and screenshot gaps

Gradle release signing still references the debug-key placeholder; no production key/team/provisioning/store record is configured here. No app-authored iOSPrivacyInfo.xcprivacy was found in tracked ios/. Bundled dependency manifests/required-reason APIs and the final Apple archive still need native Mac review. Support/privacy/contact URLs, ownership, content-rating/export questions and store certifications require accurate owner facts; source code does not supply them.

Shipping instruments/templates/graphics/icons are original; bundled fonts carry their OFL licenses and repository provenance. Reference-app research and approved mockups are not shipping media. Current78-state PNGs are real widget renders with fixtures; they are not final native platform store screenshots. Partial old-ID Android captures remain diagnostic. Final source-mapped high-resolution Android captures and genuine iOS captures are still required; never label Android imagery as iOS or infer readiness/FPS from a still or encoded video frame rate.

Current generated release merged-manifest SHA256 fe7d1e67810d333a17eb148ac1fdb5dc8f22dccfd69ccedaaccbefd540fb209a. Local audit log:work/new-id-manifest-instrumentation-build.log; generated files/logs remain diagnostic build output.
