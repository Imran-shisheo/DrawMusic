# Source register

Checked 2026-10-23. Documentation checks establish stated capabilities, not application compatibility, achieved latency, or a working integration. No dependency was added to an app.

| Topic | Primary source | Verified statement | Still needs a spike |
|---|---|---|---|
| Flutter painting | https://api.flutter.dev/flutter/rendering/CustomPainter-class.html | paint/shouldRepaint, Listenable repaint without rebuilding layout, optional semantics; dstOut needs isolated compositing | Stroke batching, frame budget, eraser performance |
| Riverpod | https://pub.dev/packages/flutter_riverpod | Reactive state and asynchronous loading/error handling | Provider lifetime during route changes; bulk stroke-state performance |
| Audio | https://pub.dev/packages/flutter_soloud | Android/iOS support, multiple voices, sample scheduling and mixer capture are documented | Real-device latency, interruption handling, timestamp semantics, exact output formats and export memory cost in selected version |
| Audio API | https://pub.dev/documentation/flutter_soloud/latest/flutter_soloud/SoLoud-class.html | Engine clock/playhead APIs and low-latency initialization documented | Clock alignment between UI and native audio under suspend/resume |
| Flutter audio integration | https://docs.flutter.dev/cookbook/audio/soloud | Initialization, source loading/playback and disposal workflow | No guarantee of this product’s target performance |
| Android native fallback | https://developer.android.com/games/sdk/oboe/low-latency-audio | Oboe/AAudio, low-latency mode, callback discipline and buffer tuning | Actual route-dependent output latency and exclusive-mode availability |
| Apple native fallback | https://developer.apple.com/documentation/avfaudio/avaudioengine | AVAudioEngine is the candidate native engine; full page rendering is JS-dependent in this research tool | Confirm offline rendering, session categories, routing and sample scheduling in platform spike |
| Navigation | https://pub.dev/packages/go_router | Declarative routes, subroutes, ShellRoute, deep links | Unsaved-edit guards and system predictive Back behavior |
| Local database | https://pub.dev/packages/drift | SQLite-backed persistence, transactions, migrations and reactive queries | Atomic file/database revision protocol and migration tests |
| Directories | https://pub.dev/packages/path_provider | Common app/private/cache directories on Android/iOS | Exact export destinations and cleanup rules |
| Native sharing | https://pub.dev/packages/share_plus | Platform share UI and files supported on Android/iOS | Recipient compatibility, canceled sheet behavior, large-video handling |
| Images/camera | https://pub.dev/packages/image_picker | Image library/camera, Android photo picker, lost-result recovery, camera cache lifetime | Cropper integration, HEIC/orientation, process-death restoration |
| Purchases (P1) | https://pub.dev/packages/in_app_purchase | Store products, purchases, subscriptions, restore APIs | Store configuration and entitlement verification; no transaction tested |

Versions seen in documentation: flutter_soloud 5.1.2; flutter_riverpod 3.4.3; go_router 18.1.1; drift 2.35.2; path_provider 2.1.6; share_plus 13.3.1; image_picker 1.2.4; in_app_purchase 3.3.1. These are research snapshots, not a proposed lockfile. Resolve compatible stable versions during implementation. Current path_provider/image_picker/in_app_purchase docs list Android 24+ and iOS 13+; share_plus docs require Flutter ≥3.38.1 and Dart ≥3.10. Reconfirm the complete dependency graph before choosing release minimums.
