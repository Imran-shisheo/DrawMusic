# Doodimo App Store metadata and release evidence

Prepared and executed 4 November 2026. Apple ID 6830542700 is configured on Imran Khan’s account, with the public Google Play title Doodimo: Draw Music and registered bundle com.devwithdelta.doodimo. Build 24 has passed Apple processing and is attached to version 2.0.1. See en-US.json and DEVELOPMENT-STATUS.md for final submission state.

The owner supplied the [Google Play listing](https://play.google.com/store/apps/details?id=com.devwithdelta.doodimo) and [privacy policy](https://possible-catmint-fdb.notion.site/Doodimo-Privacy-Policy-40c9ba8090a4815dab64ed8c4f37e9a6). Both returned inaccessible in the web tool and indexed searches found no matching result. The connected Notion tool subsequently retrieved the complete policy (edited 2 November) on 4 November. It explicitly covers the bundle ID and provides public privacy/support email imran.shisheo@gmail.com. The policy page is also suitable as the support URL because that contact is prominent. The policy subsequently rendered publicly in the InApp browser without a Notion login. The public Play listing was also retrieved and matched the title, bundle, free price and drawing-to-music purpose.

## Search and conversion decisions

The saved title leads with Doodimo and states the app's draw-to-music purpose. The subtitle adds the beginner-friendly melody/beat use case. The keyword field expands into relevant sound-making, composition and offline terms without repeating title/subtitle words or competitor names. These are semantic hypotheses grounded in the product, not measured search-volume or ranking claims. The first three screenshots should explain drawing, voices and accompaniment before secondary tools.

Validated saved-copy lengths: name 19/30 characters; subtitle 28/30; keywords 99/100 ASCII bytes; promotional text 135/170; description 1,593/4,000; review notes 1,201/4,000 ASCII bytes.

Apple limits name/subtitle to 30 characters. Its product-page guidance limits keywords to 100 characters, discourages duplicated/irrelevant terms, and says promotional text does not affect search ranking. The platform reference specifies a 100-byte keyword limit, so this draft uses ASCII. Promo copy is limited to 170 characters and description to 4,000. See [app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), and [product-page guidance](https://developer.apple.com/app-store/product-page/).

Music is the best primary category for the core musical loop. Graphics & Design is a plausible secondary category for the actual drawing tools. The store's category selector remains authoritative. No Kids-category or therapeutic positioning is proposed.

After release, compare the store's actual search impressions, product-page views and downloads over consistent periods. Once there is enough traffic, test the first screenshot through [Product Page Optimization](https://developer.apple.com/app-store/product-page-optimization/). Do not claim an ASO uplift without measurements. Add localized store copy after translation review; shipped in-app locales alone do not prove the quality of store metadata.

## Initial source review and wording limits

The qualifications below record the initial source review. Executed simulator/binary acceptance is documented at the end and in DEVELOPMENT-STATUS.md; physical-device qualifications remain open.

| Copy claim | Source evidence | Qualification before submission |
| --- | --- | --- |
| Geometry becomes a musical loop | `lib/features/composition/domain/score.dart`; `lib/features/editor/presentation/canvas.dart` | Run actual iOS playback. Do not describe drawing speed as changing the geometry-only default. |
| 13 instrument voices, 12 keys, 11 scales | `lib/creative_document/music_catalog.dart` | Voices are original synthesis, not sampled recordings. Confirm final build retains the catalog. |
| Original templates | `lib/features/home/domain/template_catalog.dart` | 20 source-defined geometric templates; no research art should be uploaded. |
| Bass, arpeggio and percussion layers | `lib/creative_document/accompaniment.dart`; `lib/features/editor/presentation/accompaniment_panel.dart` | Verify audio mix on iOS. |
| Pixel, colors, gradients, optional photo backgrounds | `lib/features/backgrounds/presentation/background_panel.dart`; `lib/features/editor/presentation/canvas.dart` | Run iOS import; camera needs a physical device. No stock photo artwork is needed for the screenshot set. |
| MIDI, WAV, MP4, PNG | `lib/features/export/presentation/export_sheet.dart`; `lib/features/export/data/ios_video_export_adapter.dart`; `ios/Runner/DrawMusicVideo.swift` | Inspect real iOS artifacts; confirm video/audio timing and actual save/share behavior. Native-source presence is not runtime proof. |
| Offline/local projects, no account | `lib/features/library/data/file_project_repository.dart`; `lib/main.dart`; `pubspec.yaml` | Audit final dependency/native binary as well as source. Exporting/sharing can place copies elsewhere. |
| Dark mode | `lib/app/app.dart`; `lib/features/settings/presentation/settings_page.dart` | Do not declare broader accessibility support without testing Apple's criteria. |

The draft avoids latency/FPS guarantees, professionally accurate acoustic timbres, learning outcomes, cloud backup, online collaboration, Apple Pencil-specific claims and paid-feature language. It also omits price claims, download counts, competitor names and ranking promises. Keep screenshots faithful to actual iOS use and app metadata accurate under [Apple's review guidelines](https://developer.apple.com/app-store/review/guidelines/), especially 2.3.3, 2.3.7 and 2.3.10.

The current [screenshot specification](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) requires at least one Dynamic Island medium iPhone screenshot and, for this universal app, a 13-inch iPad screenshot. The capture plan uses 1206×2622 for iPhone 17 Pro and 2064×2752 for iPad Pro 13-inch, subject to actual simulator capture dimensions. Final uploads must be opaque; PNG alpha is not allowed.

## Initial privacy and age-rating review

The final binary audit supports Data Not Collected; that label is published. Apple calculated 4+ from the completed questionnaire, with no Kids designation. The reasoning below preserves the basis for those answers.

Source review found no network client, analytics/advertising SDK, account system, hosted community or billing integration in `lib/`, `ios/` or `pubspec.yaml`. Photo selection/camera are optional local-background inputs; the user deliberately invokes system file saving/sharing. “Data Not Collected” and no tracking appear supportable for this source, subject to a final dependency/binary audit and confirmation that the release has the same behavior. Apple excludes solely on-device processing from its collection definition. See [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

**Policy link implemented:** `SettingsPage` now opens the owner-provided public policy in the system browser, with a selectable URL fallback if launching fails. Both outcomes pass widget tests. The metadata URL is set. The public page rendered successfully in the InApp browser on 4 November; the launcher success and failure paths pass widget tests. Opening from a physical device remains part of device acceptance. The public support page must provide real contact information. See [review guideline 5.1.1](https://developer.apple.com/app-store/review/guidelines/) and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

Answer the account's live age questionnaire based on the final build. Current source has no included violence, weapons, mature/sexual content, profanity, drugs, gambling, contests, loot boxes, medical guidance, ads, embedded web browsing, chat or in-app social feed. No parental-control or age-verification mechanism is present, so do not mark one as available. Apple defines user-generated content here in terms of broad distribution as part of the app experience; local personal drawings and explicit system exports do not establish a hosted UGC/social feature. No higher age override or Made for Kids designation is proposed. Allow Apple to calculate the rating; do not promise “4+” before the actual questionnaire. See [age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) and [set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).

Review contact was entered directly with specific owner approval; no private phone is stored here. Copyright is 2026 Imran Khan. Original content, free pricing, all 175 storefronts/future countries and automatic release after approval are configured. The privacy accuracy/update agreement was accepted after explicit owner consent. No fabricated review credentials are needed because there is no sign-in. Any additional account-specific legal or trader declarations must follow the actual account requirements.


## Executed release preparation, 4 November

Created Apple ID 6830542700 on the verified Imran Khan account, using the owner's already registered bundle ID. Public policy/support text was also rendered in the InApp browser without a Notion login. Saved metadata, all 12 screenshots, original-content declaration, 4+ rating, free pricing and worldwide availability. Privacy label was published after owner acceptance of Apple's explicit accuracy/update agreement. Contact details were entered with specific approval; private phone is intentionally excluded from source. Signed release build 24 passed Apple processing, was attached to version 2.0.1, and was submitted successfully. Apple now shows Waiting for Review; automatic release after approval is selected. Approval/live availability is not yet claimed.

The title matches the public Play listing exactly. Keywords are relevance-based hypotheses; no search volume or ranking lift was measured, and organic installs are not guaranteed. After release, evaluate actual impressions, product-page views and downloads before changing creative or keywords. No experiment, paid promotion or recurring monitoring was scheduled.
