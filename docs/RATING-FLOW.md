# Optional review flow (F22 rating portion only)

Advertisements, rewards, purchases, subscriptions and entitlement gating remain excluded. The optional review flow introduces no store link, network content upload, owner catalog or privacy URL. It cannot submit a review, grant access or change a project.

## Eligibility and ownership

`RatingCoordinator` records only explicitly successful user Save or completed export tasks. Autosave, playback, canceled/failed exports and failed saves are not qualifying events. At least three successful tasks are needed. The coordinator does not infer success from a button tap. A separate checksummed local eligibility file under application support stores only a capped count and UTC last-offered timestamp; it contains no project IDs, titles, strokes, photos or audio.

Eligibility is checked only at a safe task boundary: the editor is mounted and current, input is inactive, transport is paused, saving/exporting have finished and no other modal is present. The caller supplies a safety predicate, which is rechecked after asynchronous availability/persistence/confirmation and immediately before native launch. One serialized coordinator owns an offer; concurrent triggers cannot produce duplicate prompts. It does not pause or restart audio or modify editor state.

When native review is unavailable, no app prompt is shown. Before any prompt, the coordinator durably records the **30-day cooldown** and resets the qualifying-task counter. Back, Not now, outside dismissal, process death, native errors or quota suppression therefore cannot immediately re-prompt. Another offer needs both three subsequent successful tasks and the elapsed cooldown. A wall-clock rollback conservatively keeps the cooldown active. Corrupt, unsupported or unwritable eligibility fails closed without overwriting damaged bytes or blocking saving/export.

## Presentation and native behavior

The informational, dismissible dialog has Not now and Continue. It asks no satisfaction question, preselects no star rating and performs no sentiment filtering. Continue only permits a native review request; the body explicitly says the device may show a sheet and it can be closed without submission. Dialog content scrolls at large text and normal dialog focus/Back behavior restores the initiating control.

The actual adapter uses **in_app_review 2.0.12**, MIT license, only `isAvailable()` and `requestReview()`. The Android implementation uses the platform In-App Review API; iOS uses the system review request. There is no `openStoreListing` fallback because a verified published store destination has not been supplied. Native quotas and installation/account/store availability can suppress the sheet. A returned request future is **not** evidence that a sheet appeared or a review was submitted. No success toast claims either outcome.

Primary package documentation and current version were read on 26 October 2026:

- [Package README/API guidance](https://pub.dev/packages/in_app_review)
- [Package license](https://pub.dev/packages/in_app_review/license)
- [Android review timing and design guidance](https://developer.android.com/guide/playcore/in-app-review#when-to-request)
- [Apple rating/review guidance](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews)

## Validation and limits

Pure tests exercise threshold/count behavior, dismissal/restart/cooldown, clock rollback, unavailable platform, unsafe drawing states, safety changes across awaits, failed reads/writes, duplicate concurrent triggers, native exceptions and the request-only outcome. Real file tests verify checksummed atomic reopen, temporary-file cleanup and corrupt-byte preservation. Compact 320 dp/200% text widget tests verify dialog dismissal, Back, explicit Continue and focus return. Product integration separately validates editor hook placement.

The real Play/App Store review sheet, platform quotas, receipt of a review and iOS compilation/runtime remain **unverified** in this development environment. No listing, review or external delivery is invented. A sideloaded debug APK may never display the native review sheet, which is a normal unavailable/suppressed outcome rather than a blocked creative feature.
