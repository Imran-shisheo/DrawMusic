# Release privacy alignment — 2 November 2026

This bounded update corrects privacy explanations without changing creation, storage, soft-delete, backups, export destinations or permissions. It is not a release approval or a successful rerun of the blocked normal-renderer gate.

## In-app and camera wording

All 12 locales now explain that creation works offline without an account, while chosen apps/folders/cloud providers can receive exports, system settings can allow backups, recovery copies can remain until cleanup, and external copies can survive deletion or uninstalling. The old promise that files leave only through sharing is removed. Delete still marks a drawing as deleted; it is not immediate physical erasure.

The base iOS camera prompt and all 12 localized prompts now describe only the user-chosen purpose of photographing a drawing background. No permission or camera behavior changed.

Settings has a localized Privacy Policy browser action with failure/retry handling. It uses the exact published URL supplied by the coordinator: https://possible-catmint-fdb.notion.site/Doodimo-Privacy-Policy-40c9ba8090a4815dab64ed8c4f37e9a6 . The coordinator verified the public read-only browser view; independent anonymous verification is underway. No private `app.notion.com` draft or guessed address is shipped. If the URL were absent, the accurate local explanation would remain without a broken action. The URI guard rejects non-HTTPS, embedded credentials and that known private-draft host. Public support/privacy contact authorized by the owner: **imran.shisheo@gmail.com**. Target-audience decisions remain with the owner; this copy makes no age-specific promise.

`url_launcher` 6.3.3 was already resolved and bundled transitively; it is now declared directly, with no package version change. Opening the published policy delegates to the external browser/app. It does not add app-owned HTTP uploads or an embedded webview.

## Advertising ID and Data safety evidence

The audit distinguishes generated build evidence from source inspection:

- The freshly generated **release merged manifest** has neither `com.google.android.gms.permission.AD_ID` nor `android.permission.INTERNET`. Its sole `uses-permission` is `com.devwithdelta.doodimo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, signature-scoped. Manifest SHA256: `fe7d1e67810d333a17eb148ac1fdb5dc8f22dccfd69ccedaaccbefd540fb209a`.
- The resolved `releaseRuntimeClasspath` selects 56 unique external coordinates. Its Google components include Play Review/Review KTX 2.0.2, core-common 2.0.4, play-services-base 18.7.2, basement 18.7.1, tasks 18.3.2 and Guava listenablefuture. No advertising-ID, ads, Firebase Analytics, Crashlytics or other identified analytics dependency appears. Requested versions redirected by Gradle are distinguished from selected versions.
- Actual release plugin dependency edges are in_app_review, jni, jni_flutter, package_info_plus, share_plus and url_launcher_android. Merely configuring integration_test does not put it on the release runtime classpath. Dart path-provider code uses its resolved platform implementation; plugin registration metadata alone is not the JVM dependency graph.
- All ten DEX files in the **built debug APK** were scanned case-insensitively for AD_ID/AdvertisingIdClient and package/class-specific markers for Google ads identifiers, Firebase Analytics, AppsFlyer, Crashlytics, Mixpanel, Amplitude, Adjust, Sentry Android and Facebook App Events. No checked marker was found. This scan is not a complete behavioral audit. Debug tooling intentionally has INTERNET permission, unlike the generated release manifest.
- App Dart/Kotlin/Swift source has no identified advertising identifier access, app-owned HTTP upload/analytics service, ads, account/login, payment, financial or health feature. Source search matches for `_MixPanel`, `amplitude` and `adjustResize` are audio UI, synthesis math and window layout, not analytics SDKs.

These observations **do not certify that no third party ever handles data**. Optional reviews delegate to Google Play, an SDK/service boundary with its own data practices; browser policy visits, chosen cloud-capable providers and OS backups may transmit data outside this app. Shared Google base libraries expose general APIs without proving the app invokes every API. No packet/interprocess traffic audit, exhaustive third-party bytecode audit or final signed/shrunk AAB inspection was performed. Final Play Data safety answers must account for the exact shipped SDKs and Google's current [In-App Reviews Data safety guidance](https://developer.android.com/guide/playcore/in-app-review), rather than infer a universal guarantee from missing permissions or string markers.

Reproduction uses the existing pinned tools: `:app:processReleaseMainManifest`, `:app:dependencies --configuration releaseRuntimeClasspath`, APK signature/badging inspection and bounded DEX scans. Detailed local evidence is `work/privacy-release-dependencies.log` and `work/privacy-dependency-audit.json`; generated logs are not shipping assets.

## Exact upload prerequisites

1. Android `applicationId` and namespace already equal `com.devwithdelta.doodimo`. iOS Runner uses that exact Bundle ID in all three configurations; RunnerTests uses `com.devwithdelta.doodimo.RunnerTests`. No ID, data path or internal channel was changed again.
2. **Release signing is not ready:** `android/app/build.gradle.kts` still selects the debug signing configuration for release. A private owner-controlled upload keystore, alias and secrets must be supplied through secure configuration, release signing must be deliberately configured, and Play App Signing/upload-certificate expectations must match. No production key or signing credential was generated, read, configured or committed in this update. Keystore/key.properties paths remain ignored.
3. The coordinator reports an existing unpublished Play record for this ID; this executor did not independently inspect Play Console. Before an upload, verify the package, Play signing setup, and an unused/increasing version code. Current source is 2.1.0+24, minimum SDK24/target SDK36. A debug APK or a release build signed with the debug placeholder is not a store-ready AAB.
4. Use the published URL above both in-app and in the Play listing, and finish independent anonymous access verification before upload. The coordinator reports publication after owner Notion login; this executor did not publish or modify Notion. No private draft URL substitutes for the public policy.
5. Finish owner-controlled audience/content-rating/Data safety and other required declarations against the final artifact and SDK behavior. Listing graphics must be accurate actual Android captures. Source-audited draft declarations and widget fixtures are not final production/device evidence.
6. The full normal Android runtime/media and shipping-renderer performance acceptance remain unresolved from the recorded emulator failures. Earlier controlled Skia success is separately labelled diagnostic-only. iOS compilation, Apple-framework/runtime/privacy-manifest review, team/provisioning and device acceptance still require the separately authorized Mac workflow. No store upload, submission, release or owner-phone operation occurred here.

## Bounded local verification

The enclosing development checkpoint records formatter/analyzer, 13 targeted privacy/settings/localization tests, actual debug APK build/signature, 12-locale/376-key parity, purpose-only iOS plist changes, release-manifest generation and resolved dependency inspection. Link tests use the configured public URL through a fake launcher: false returns, exceptions, generic error feedback and retry are exercised without an external request. These checks do not count as real browser/provider, full emulator, physical-device or iOS acceptance.

Final local debug APK SHA256: `8cfe7edb01ff5135c71517f9259ba00f5ca8d98879f88d0fc2ed522d14bac5fb`. The final APK rebuild and v2 signature verification pass. Formatter reports113files/zero changes and analyzer zero issues; all13targeted tests pass. This is a local debug artifact, not a newly uploaded Play bundle or a fresh full native/runtime pass.
