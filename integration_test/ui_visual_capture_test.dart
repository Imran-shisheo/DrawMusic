import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/export/data/file_export_adapter.dart';
import 'package:scribblesong/features/export/data/file_image_export_adapter.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';
import 'package:scribblesong/features/home/domain/template_catalog.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/data/file_preferences_store.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/main.dart' as app;

import 'support/ui_capture_metrics.dart';
import 'support/ui_frame_clock.dart';
import 'support/ui_presentation_fence.dart';

const _token = String.fromEnvironment('UI_CAPTURE_TOKEN');
const _port = int.fromEnvironment('UI_CAPTURE_PORT', defaultValue: 8765);
const _label = String.fromEnvironment(
  'UI_CAPTURE_LABEL',
  defaultValue: 'before',
);

/// Diagnostic target only. Normal lib/main.dart has no local capture server,
/// test content or network dependency. Host also requires GH Actions/QEMU.
class _CaptureHost {
  int sequence = 0;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  Future<void> event(
    String operation,
    String name, [
    Map<String, Object?> extra = const {},
  ]) async {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$_port/event'),
    );
    request.headers.contentType = ContentType.json;
    final payload = utf8.encode(
      jsonEncode({
        'token': _token,
        'sequence': ++sequence,
        'operation': operation,
        'name': name,
        ...extra,
      }),
    );
    // A bounded Content-Length is the capture protocol. HttpClient's default
    // streaming/chunked request has no length and is deliberately rejected.
    request.contentLength = payload.length;
    request.add(payload);
    // Stopping a clip includes bounded native finalization, ADB transfer and
    // whole-video decoding on the host before the event can claim success.
    final response = await request.close().timeout(
      Duration(
        seconds: operation == 'record_stop'
            ? 100
            : operation == 'record_start'
            ? 60
            : 35,
      ),
    );
    final value = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    if (response.statusCode != 200 ||
        value['ok'] != true ||
        value['sequence'] != sequence) {
      throw StateError('Capture host rejected $operation/$name: $value');
    }
  }

  void close() => client.close(force: true);
}

Future<void> _seedFixtures() async {
  final support = await getApplicationSupportDirectory();
  await FilePreferencesStore(Directory('${support.path}/settings')).save(
    const UserPreferences(tutorialCompleted: true, editorTipsCompleted: true),
  );
  final original = originalTemplates.first.create();
  final when = DateTime.utc(2026, 10, 26, 8);
  ProjectDocument drawing(
    String id,
    String title, {
    BackgroundDefinition? paper,
    List<Stroke>? strokes,
  }) => ProjectDocument(
    id: id,
    title: title,
    strokes: strokes ?? original.strokes,
    paper: paper,
    createdAt: when,
    updatedAt: when,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 256, 256),
    Paint()..color = const Color(0xffead7b5),
  );
  canvas.drawCircle(
    const Offset(164, 86),
    60,
    Paint()..color = const Color(0xffb7cec4),
  );
  canvas.drawRect(
    const Rect.fromLTWH(20, 150, 130, 80),
    Paint()..color = const Color(0xffcf9a86),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  final pixels = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final bytes = pixels!.buffer.asUint8List();
  final id = sha256.convert(bytes).toString();
  final assets = Directory('${support.path}/backgrounds');
  await assets.create(recursive: true);
  await File('${assets.path}/$id.png').writeAsBytes(bytes, flush: true);
  final documents = [
    drawing('capture-morning', 'Morning tide'),
    drawing(
      'capture-gradient',
      'Evening study',
      paper: BackgroundDefinition(
        kind: BackgroundKind.linear,
        colors: [0xffead9c9, 0xffb8d7ce],
      ),
    ),
    drawing(
      'capture-photo',
      'Amber window',
      paper: BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: id,
        crop: const CropWindow(left: .1, top: .1, width: .8, height: .8),
      ),
    ),
    drawing(
      'capture-missing',
      'Missing paper study',
      paper: BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: List.filled(64, 'f').join(),
      ),
    ),
    drawing(
      'capture-stress',
      'Ten thousand points',
      strokes: [
        Stroke(
          id: 'original-wave-stress',
          instrument: Instrument.keys,
          points: [
            for (var i = 0; i < 10000; i++)
              InkPoint(
                .04 + .92 * i / 9999,
                .5 + .2 * math.sin(i / 9999 * 8 * math.pi),
              ),
          ],
        ),
      ],
    ),
  ];
  final repository = FileProjectRepository(
    Directory('${support.path}/projects'),
  );
  for (final document in documents) {
    await repository.save(document);
  }
  final root = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/exports',
  );
  final library = FileExportLibrary(root);
  await library.record(
    await FileImageExportAdapter(root)
        .exportImage(documents[1], ExportCancellation(), width: 640),
    documents[1],
  );
  await library.record(
    await FileExportAdapter(root)
        .export(documents.first, ExportFormat.wav, ExportCancellation()),
    documents.first,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  debugDisableShadows = false;
  testWidgets('actual profile UI screenshots, interactions and frame timings', (
    tester,
  ) async {
    final previousHitTestPolicy = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() {
      WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
    });
    expect(
      kProfileMode,
      isTrue,
      reason: 'Debug mode is not motion-performance evidence',
    );
    expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(_token), isTrue);
    final host = _CaptureHost();
    addTearDown(host.close);
    await _seedFixtures();
    await app.main();
    Future<void> wait([int ms = 800]) =>
        tester.pump(Duration(milliseconds: ms));
    Future<void> until(bool Function() condition, {int seconds = 30}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!condition()) {
        if (DateTime.now().isAfter(end)) {
          fail(
            'UI capture timed out; visible texts: ${tester.widgetList<Text>(find.byType(Text)).map((v) => v.data).join(' | ')}',
          );
        }
        await wait(100);
      }
    }

    Finder key(String value) => find.byKey(ValueKey(value));
    Future<void> tap(Finder finder) async {
      await until(() => finder.evaluate().isNotEmpty);
      await tester.ensureVisible(finder.first);
      await tester.tap(finder.first);
      await wait();
    }

    Future<void> control(String id, String fallback) async =>
        tap(key(id).evaluate().isNotEmpty ? key(id) : find.byTooltip(fallback));
    Future<void> tab(String name) async {
      final target = key('nav-${name.toLowerCase()}');
      await tap(target.evaluate().isNotEmpty ? target : find.text(name));
    }

    GoRouter router() =>
        GoRouter.of(tester.element(find.byType(Scaffold).first));
    Future<void> route(String location) async {
      router().go(location);
      await wait(1100);
    }

    bool renderedAnchor(Finder finder) {
      if (finder.evaluate().isEmpty) return false;
      final context = tester.element(finder.first);
      final route = ModalRoute.of(context);
      if (route != null &&
          (!route.isCurrent ||
              (route.animation != null && route.animation!.value < 1))) {
        return false;
      }
      final box = context.findRenderObject();
      return box is RenderBox &&
          box.attached &&
          box.hasSize &&
          !box.size.isEmpty;
    }

    bool expectedShot(String name) {
      if (find.byType(Scaffold).evaluate().isEmpty) return false;
      final uri = router().routeInformationProvider.value.uri.path;
      final canvas = key('drawing-canvas');
      final home = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'HomePage',
      );
      final settings = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'SettingsPage',
      );
      final hasPanel =
          find.byType(BottomSheet).evaluate().isNotEmpty ||
          find.byType(Dialog).evaluate().isNotEmpty;
      final context = tester.element(find.byType(Scaffold).first);
      final width = MediaQuery.sizeOf(context).width;
      bool editor(String title) =>
          uri.startsWith('/editor/') &&
          !hasPanel &&
          find.text(title).evaluate().isNotEmpty &&
          renderedAnchor(canvas);
      return switch (name) {
        '01-home' => uri == '/home' && !hasPanel && renderedAnchor(home),
        '02-drafts' =>
          uri == '/drafts' &&
              !hasPanel &&
              renderedAnchor(
                find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == 'DraftsPage',
                ),
              ),
        '03-exports' =>
          uri == '/exports' &&
              !hasPanel &&
              renderedAnchor(
                find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == 'ExportsPage',
                ),
              ),
        '04-settings' =>
          uri == '/settings' && !hasPanel && renderedAnchor(settings),
        '05-editor-drawn' => editor('Paper hills'),
        '06-photo-editor' => editor('Amber window'),
        '07-photo-crop-panel' => renderedAnchor(
          key('background-crop-workspace').evaluate().isNotEmpty
              ? key('background-crop-workspace')
              : find.byType(BottomSheet),
        ),
        '08-instruments' =>
          key('voice-bell').evaluate().isNotEmpty
              ? renderedAnchor(key('voice-bell'))
              : editor('Amber window') &&
                    find
                        .widgetWithText(ChoiceChip, 'Glass stars')
                        .evaluate()
                        .isNotEmpty,
        '09-editor-playing' =>
          editor('Amber window') &&
              find.byTooltip('Pause').evaluate().isNotEmpty,
        '10-export-selection' => renderedAnchor(
          key('export-selection').evaluate().isNotEmpty
              ? key('export-selection')
              : find.text('Export PNG'),
        ),
        '11-export-ready' => renderedAnchor(
          key('export-ready').evaluate().isNotEmpty
              ? key('export-ready')
              : find.textContaining('Export ready'),
        ),
        '12-stress-editor' => editor('Ten thousand points'),
        '13-home-dark' =>
          uri == '/home' &&
              !hasPanel &&
              renderedAnchor(home) &&
              Theme.of(context).brightness == Brightness.dark,
        '14-settings-dark' =>
          uri == '/settings' &&
              !hasPanel &&
              renderedAnchor(settings) &&
              Theme.of(context).brightness == Brightness.dark,
        '15-home-reduced-motion' =>
          uri == '/home' &&
              !hasPanel &&
              renderedAnchor(home) &&
              MediaQuery.disableAnimationsOf(context),
        '16-home-compact-large-text' =>
          uri == '/home' &&
              !hasPanel &&
              renderedAnchor(home) &&
              width <= 321 &&
              MediaQuery.textScalerOf(context).scale(10) >= 19,
        '17-editor-compact-large-text' =>
          editor('Morning tide') &&
              width <= 321 &&
              MediaQuery.textScalerOf(context).scale(10) >= 19,
        '18-home-tablet' =>
          uri == '/home' && !hasPanel && renderedAnchor(home) && width >= 800,
        '19-editor-tablet' => editor('Morning tide') && width >= 800,
        '20-rename-native-ime' =>
          uri == '/drafts' &&
              renderedAnchor(find.byType(TextField)) &&
              tester.view.viewInsets.bottom > 100 &&
              !binding.testTextInput.isRegistered,
        '21-rename-focus-restored' =>
          uri == '/drafts' &&
              !hasPanel &&
              tester.view.viewInsets.bottom == 0 &&
              find
                  .byType(EditableText)
                  .evaluate()
                  .every(
                    (element) =>
                        !(element.widget as EditableText).focusNode.hasFocus,
                  ),
        '22-home-light' =>
          uri == '/home' &&
              !hasPanel &&
              renderedAnchor(home) &&
              width >= 410 &&
              width <= 412 &&
              MediaQuery.textScalerOf(context).scale(10) == 10 &&
              Theme.of(context).brightness == Brightness.light &&
              !MediaQuery.disableAnimationsOf(context),
        '23-editor-light' =>
          editor('Morning tide') &&
              width >= 410 &&
              width <= 412 &&
              MediaQuery.textScalerOf(context).scale(10) == 10 &&
              Theme.of(context).brightness == Brightness.light &&
              !MediaQuery.disableAnimationsOf(context),
        _ => false,
      };
    }

    Future<void> shot(String name) async {
      await until(() => expectedShot(name));
      final fence = UiPresentationFence(
        binding,
        isExpected: () => expectedShot(name),
      )..start();
      Map<String, Object> evidence;
      try {
        evidence = await fence.waitForRaster();
      } finally {
        fence.stop();
      }
      final refreshHz = tester.view.display.refreshRate;
      if (!refreshHz.isFinite || refreshHz <= 0) {
        fail('Screenshot compositor grace requires observed refresh rate');
      }
      final graceUs = (2000000 / refreshHz).ceil().clamp(1000, 100000);
      await Future<void>.delayed(Duration(microseconds: graceUs));
      expect(expectedShot(name), isTrue);
      final screenshotReadiness = {
        ...evidence,
        'expectedScene': name,
        'observedDisplayRefreshHz': refreshHz,
        'compositorGraceUs': graceUs,
        'compositorScope': 'Two observed display intervals, bounded to100ms, after matched raster; actual ADB pixels still need review. One real screenshot-only frame requested outside measured phases; no video padding/retiming.',
      };
      debugPrint(
        'UI_SCREENSHOT_RASTER_FENCE ${jsonEncode(screenshotReadiness)}',
      );
      await host.event('snapshot', name, {
        'screenshotReadiness': screenshotReadiness,
      });
    }

    Future<void> clip(String name, Future<void> Function() action) async {
      await host.event('record_start', name);
      try {
        await action();
      } finally {
        await host.event('record_stop', name);
      }
    }

    ProviderContainer container() =>
        ProviderScope.containerOf(tester.element(find.byType(ScribbleSongApp)));
    Future<void> preference({bool? dark, bool? reduce}) async {
      final scope = container();
      final previous = scope.read(settingsProvider).preferences;
      await scope
          .read(settingsProvider.notifier)
          .save(previous.copyWith(darkTheme: dark, reduceMotion: reduce));
      await wait(1000);
    }

    Future<void> measure(
      String name,
      Future<void> Function() action, {
      Map<String, Object?> visibleScope = const {},
    }) async {
      await host.event('perf_start', name);
      await wait(1500); // Flush earlier engine timing batches.
      final frames = <ui.FrameTiming>[];
      final start = DateTime.now().microsecondsSinceEpoch;
      void receive(List<ui.FrameTiming> values) => frames.addAll(values);
      binding.addTimingsCallback(receive);
      int end;
      try {
        await action();
        end = DateTime.now().microsecondsSinceEpoch;
        await wait(1500);
      } finally {
        binding.removeTimingsCallback(receive);
      }
      if (name == 'home-ambient-visible') {
        // Persist observer data even if zero engine samples subsequently make
        // the mandatory FrameTiming summary fail. Never turn absence into pass.
        await host.event('diagnostic', 'home-motion-clock', {
          'observations': visibleScope,
          'observationElapsedUs': end - start,
          'recordingDuringMeasurement': false,
        });
      }
      final measured = frames.where((value) {
        final wall = value.timestampInMicroseconds(
          ui.FramePhase.rasterFinishWallTime,
        );
        return wall >= start && wall <= end;
      }).toList();
      final result = summarizeUiFrames(
        measured,
        tester.view.display.refreshRate,
      );
      result['observationElapsedUs'] = end - start;
      if (visibleScope.isNotEmpty) result['visibleScope'] = visibleScope;
      await host.event('perf_finish', name, {
        'result': result,
        'recordingDuringMeasurement': false,
      });
    }

    await until(() => find.text('Paper hills').evaluate().isNotEmpty);
    // Widget existence alone did not prove native splash handoff in the first
    // after run. Wait for an actual engine-rasterized frame as well; the host
    // independently rejects the observed flat compositor/splash image.
    await binding.waitUntilFirstFrameRasterized.timeout(
      const Duration(seconds: 20),
    );
    await wait(1500);
    await host.event('metadata', 'session', {
      'firstFrameRasterized': binding.firstFrameRasterized,
      'label': _label,
      'buildMode': 'profile',
      'physicalSize': [
        tester.view.physicalSize.width,
        tester.view.physicalSize.height,
      ],
      'devicePixelRatio': tester.view.devicePixelRatio,
      'refreshHz': tester.view.display.refreshRate,
      'animationsDisabled': MediaQuery.disableAnimationsOf(
        tester.element(find.byType(Scaffold).first),
      ),
      'fixtures': 'Original seeded real repositories/PNG/WAV; no mocked adapters, user content or competitor assets',
    });
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byType(Scaffold).first),
      ),
      isFalse,
    );
    await shot('01-home');
    if (_label == 'after') {
      final create = key('home-start');
      expect(create.hitTestable(), findsOneWidget);
      final createContext = tester.element(create);
      expect(MediaQuery.disableAnimationsOf(createContext), isFalse);
      final bounds = tester.getRect(create);
      // Avoid a production-class import: the old before-source has no Aurora.
      // Observe the actual mounted widget/controller, never a diagnostic clock.
      final aurora = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'AuroraScene',
      );
      expect(aurora, findsOneWidget);
      final controllers = tester
          .widgetList<AnimatedBuilder>(
            find.descendant(of: aurora, matching: find.byType(AnimatedBuilder)),
          )
          .map((builder) => builder.animation)
          .whereType<AnimationController>()
          .toSet();
      expect(controllers, hasLength(1));
      final controller = controllers.single;
      final clockSamples = <Map<String, Object?>>[];
      final stopwatch = Stopwatch();
      final frameClock = UiFrameClockObserver(binding);
      // This phase precedes every recording: app motion/lifecycle and actual
      // clock progress survive a later encoder failure, without recorder load.
      await measure(
        'home-ambient-visible',
        () async {
          stopwatch.start();
          frameClock.start();
          try {
            for (var index = 0; index < 34; index++) {
              await wait(500);
              final createBox = tester.getRect(create);
              final auroraBox = tester.getRect(aurora);
              final logicalViewport =
                  Offset.zero &
                  (tester.view.physicalSize / tester.view.devicePixelRatio);
              clockSamples.add({
                'sample': index,
                'stopwatchElapsedUs': stopwatch.elapsedMicroseconds,
                'dateTimeWallUs': DateTime.now().microsecondsSinceEpoch,
                'currentFrameTimeStampUs':
                    frameClock.latest?['currentFrameTimeStampUs'],
                'currentSystemFrameTimeStampUs':
                    frameClock.latest?['currentSystemFrameTimeStampUs'],
                'postFrameDateTimeWallUs':
                    frameClock.latest?['postFrameDateTimeWallUs'],
                'postFrameObserverElapsedUs':
                    frameClock.latest?['postFrameObserverElapsedUs'],
                'observedFrameworkPostFrames': frameClock.observedPostFrames,
                'timeDilation': timeDilation,
                'auroraValue': controller.value,
                'auroraLastElapsedUs':
                    controller.lastElapsedDuration?.inMicroseconds,
                'auroraIsAnimating': controller.isAnimating,
                'auroraAnimationStatus': controller.status.name,
                'auroraTickerModeEnabled': TickerMode.valuesOf(
                  tester.element(aurora),
                ).enabled,
                'appLifecycle': binding.lifecycleState?.name,
                'reducedMotion': MediaQuery.disableAnimationsOf(
                  tester.element(create),
                ),
                'homeCreateHitTestable': create
                    .hitTestable()
                    .evaluate()
                    .isNotEmpty,
                'homeCreateBounds': [
                  createBox.left,
                  createBox.top,
                  createBox.width,
                  createBox.height,
                ],
                'auroraBounds': [
                  auroraBox.left,
                  auroraBox.top,
                  auroraBox.width,
                  auroraBox.height,
                ],
                'auroraIntersectsViewport': auroraBox.overlaps(logicalViewport),
              });
            }
          } finally {
            frameClock.stop();
            stopwatch.stop();
          }
        },
        visibleScope: {
          'route': router().routeInformationProvider.value.uri.toString(),
          'homeCreateHitTestableAtStart': true,
          'homeCreateBounds': [
            bounds.left,
            bounds.top,
            bounds.width,
            bounds.height,
          ],
          'homeScrollOffset': Scrollable.maybeOf(createContext)
              ?.position
              .pixels,
          'animationsDisabledAtStart': false,
          'nominalObservationMilliseconds': 17000,
          'screenRecordingActive': false,
          'controllerRuntimeType': controller.runtimeType.toString(),
          'controllerDurationUs': controller.duration?.inMicroseconds,
          'clockSamples': clockSamples,
          'schedulerClockObservation': 'Nullable cache from the latest real post-frame callback; missing/stale observations remain explicit, never fabricated idle-frame timestamps.',
          'clockObservationScope': 'Bounded reads of the actual Aurora AnimatedBuilder controller and real framework/Dart clocks; no app hooks, clock mutation, padding or timing acceptance inference.',
          'baselineComparison': 'No equivalent before phase exists; standalone after-source observation.',
        },
      );
      expect(create.hitTestable(), findsOneWidget);
      expect(MediaQuery.disableAnimationsOf(tester.element(create)), isFalse);
      // Only after unrecorded evidence is persisted, capture real decorative
      // motion. The native MP4 independently requires >=16s without retiming.
      await clip('00-home-ambient', () async {
        final startElapsed = controller.lastElapsedDuration?.inMicroseconds;
        final period = controller.duration?.inMicroseconds;
        final startValue = controller.value;
        final recordingWatch = Stopwatch()..start();
        expect(
          startElapsed,
          isNotNull,
          reason: 'Actual sculpture has no frame-clock history',
        );
        expect(period, isNotNull);
        expect(controller.isAnimating, isTrue);
        await wait(40000);
        recordingWatch.stop();
        final endElapsed = controller.lastElapsedDuration?.inMicroseconds;
        final advanced = startElapsed != null && endElapsed != null
            ? endElapsed - startElapsed
            : null;
        debugPrint(
          'UI_RECORDED_AURORA_CLOCK ${jsonEncode({'actualControllerStartElapsedUs': startElapsed, 'actualControllerEndElapsedUs': endElapsed, 'actualControllerAdvancedUs': advanced, 'authoredControllerPeriodUs': period, 'actualControllerStartValue': startValue, 'actualControllerEndValue': controller.value, 'actualControllerAnimatingAtEnd': controller.isAnimating, 'dartObservationElapsedUs': recordingWatch.elapsedMicroseconds, 'scope': 'Unwrapped actual sculpture controller interval while native recording is active; no clock mutation, padding, frame repetition or retiming.'})}',
        );
        expect(controller.isAnimating, isTrue);
        expect(advanced, isNotNull);
        expect(advanced!, greaterThanOrEqualTo(period!));
      });
    }
    await clip('01-root-navigation', () async {
      await tab('Library');
      await shot('02-drafts');
      if (_label == 'after') {
        expect(binding.testTextInput.isRegistered, isFalse);
        final initialInset = tester.view.viewInsets.bottom;
        expect(initialInset, 0);
        final actions = find.byTooltip('Manage Morning tide');
        await tester.scrollUntilVisible(
          actions,
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey<String>('drafts-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tap(actions);
        await tap(find.text('Rename'));
        await tap(find.byType(TextField));
        await until(
          () =>
              tester.view.viewInsets.bottom > initialInset + 100 &&
              find
                  .byType(EditableText)
                  .evaluate()
                  .any(
                    (element) =>
                        (element.widget as EditableText).focusNode.hasFocus,
                  ),
        );
        final keyboardInset = tester.view.viewInsets.bottom;
        final visibleBottom =
            (tester.view.physicalSize.height - keyboardInset) /
            tester.view.devicePixelRatio;
        final fieldBounds = tester.getRect(find.byType(TextField));
        final cancel = find.widgetWithText(TextButton, 'Cancel');
        final cancelBounds = tester.getRect(cancel);
        expect(fieldBounds.bottom, lessThanOrEqualTo(visibleBottom));
        expect(cancelBounds.bottom, lessThanOrEqualTo(visibleBottom));
        expect(cancel.hitTestable(), findsOneWidget);
        await shot('20-rename-native-ime');
        await tap(cancel);
        await until(() => expectedShot('21-rename-focus-restored'));
        expect(find.text('Morning tide'), findsWidgets);
        expect(actions.hitTestable(), findsOneWidget);
        await shot('21-rename-focus-restored');
        debugPrint(
          'UI_NATIVE_IME_CHECK ${jsonEncode({'mockTextInputRegistered': binding.testTextInput.isRegistered, 'initialPhysicalInset': initialInset, 'visiblePhysicalInset': keyboardInset, 'finalPhysicalInset': tester.view.viewInsets.bottom, 'visibleLogicalBottom': visibleBottom, 'fieldLogicalBottom': fieldBounds.bottom, 'cancelLogicalBottom': cancelBounds.bottom, 'scope': 'Actual platform IME insets and focused editable; reachable Cancel closes panel and keyboard without editing the document. No simulated insets or mock input.'})}',
        );
      }
      await tap(find.text('Exports'));
      await shot('03-exports');
      await tab('Settings');
      await shot('04-settings');
      await tab('Home');
      await wait(1200);
    });
    await clip('02-home-editor-back', () async {
      await tap(find.text('Paper hills'));
      await until(() => key('drawing-canvas').evaluate().isNotEmpty);
      await wait(1200);
      await shot('05-editor-drawn');
      await control('editor-back', 'Back to gallery');
      await wait(1000);
    });
    await route('/editor/capture-photo');
    await shot('06-photo-editor');
    await clip('03-paper-sheet', () async {
      if (key('editor-tools').evaluate().isNotEmpty) {
        await tap(key('editor-tools'));
        await tap(key('editor-tool-paper'));
      } else {
        await control('paper-controls', 'Paper color');
      }
      await wait();
      await shot('07-photo-crop-panel');
      await tap(find.text('Cancel'));
      await wait();
    });
    await clip('04-instrument-and-playback', () async {
      if (key('current-voice').evaluate().isNotEmpty) {
        await tap(key('current-voice'));
        await shot('08-instruments');
        await tap(
          key('voice-bell').evaluate().isNotEmpty
              ? key('voice-bell')
              : find.text('Glass stars'),
        );
      } else {
        final voice = find.widgetWithText(ChoiceChip, 'Glass stars');
        await tap(voice);
        await shot('08-instruments');
      }
      await control('transport-play', 'Play');
      await wait(1500);
      await shot('09-editor-playing');
      await control('transport-pause', 'Pause');
      await wait();
    });
    await clip('05-export-ready', () async {
      await control('editor-export', 'Export loop');
      await shot('10-export-selection');
      if (key('export-intent-png').evaluate().isNotEmpty) {
        await tap(key('export-intent-png'));
        await tap(key('export-start'));
      } else {
        await tap(find.text('Export PNG'));
      }
      await until(
        () =>
            find.textContaining('Export ready').evaluate().isNotEmpty ||
            key('export-ready').evaluate().isNotEmpty,
        seconds: 60,
      );
      await shot('11-export-ready');
      if (find.byTooltip('Close').evaluate().isNotEmpty) {
        await tap(find.byTooltip('Close'));
      } else {
        await tap(find.text('Close'));
      }
    });
    await route('/home');
    await measure('root-transitions', () async {
      for (var i = 0; i < 4; i++) {
        await tab('Library');
        await wait(300);
        await tab('Settings');
        await wait(300);
        await tab('Home');
        await wait(300);
      }
    });
    await route('/editor/capture-stress');
    await until(() => key('drawing-canvas').evaluate().isNotEmpty);
    await wait(1000);
    await measure('drawing-on-10000-points', () async {
      final rect = tester.getRect(key('drawing-canvas'));
      final gesture = await tester.startGesture(
        Offset(rect.left + rect.width * .1, rect.top + rect.height * .65),
      );
      for (var i = 1; i <= 120; i++) {
        await gesture.moveTo(
          Offset(
            rect.left + rect.width * (.1 + .8 * i / 120),
            rect.top +
                rect.height * (.65 + .05 * math.sin(i / 120 * 4 * math.pi)),
          ),
        );
        await wait(16);
      }
      await gesture.up();
      await wait(700);
    });
    await shot('12-stress-editor');
    await route('/home');
    await preference(dark: true);
    await shot('13-home-dark');
    await tab('Settings');
    await shot('14-settings-dark');
    await preference(dark: false, reduce: true);
    await clip('06-reduced-motion', () async {
      await tab('Home');
      await tab('Library');
      await tab('Settings');
      await tab('Home');
    });
    await shot('15-home-reduced-motion');
    await preference(reduce: false);
    await host.event('display', 'compact');
    await wait(1500);
    await shot('16-home-compact-large-text');
    await route('/editor/capture-morning');
    await shot('17-editor-compact-large-text');
    await control('editor-back', 'Back to gallery');
    await host.event('display', 'tablet');
    await wait(1500);
    await shot('18-home-tablet');
    await route('/editor/capture-morning');
    await shot('19-editor-tablet');
    await host.event('display', 'phone');
    await wait(1200);
    if (_label == 'after') {
      await route('/home');
      await preference(dark: false, reduce: false);
      await shot('22-home-light');
      await route('/editor/capture-morning');
      await shot('23-editor-light');
    }
    await host.event('complete', 'capture', {
      'passed': true,
      'performanceScope': 'Real profile build and engine frame timings, owned SwiftShader emulator; no physical smoothness/audio/iOS claim',
    });
    binding.reportData = {
      'passed': true,
      'label': _label,
      'realProfileBuild': kProfileMode,
      'screenshotsAndVideos': 'work/ui-capture',
      'physicalDeviceVerified': false,
    };
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
