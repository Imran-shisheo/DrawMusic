import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart' show libraryProvider;
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/artwork_flight.dart';
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
import 'package:scribblesong/l10n/strings.dart';

import 'support/ui_capture_metrics.dart';
import 'support/ui_frame_clock.dart';
import 'support/ui_static_backdrop_probe.dart';
import 'support/ui_presentation_fence.dart';
import 'support/ui_flight_frame_observer.dart';

const _staticBackdropProbe = bool.fromEnvironment('UI_STATIC_BACKDROP_PROBE');
const _responsivePreset = String.fromEnvironment('UI_RESPONSIVE_PRESET');
const _homeProfileOnly = bool.fromEnvironment('UI_HOME_PROFILE_ONLY');
const _graphiteCapture = bool.fromEnvironment('UI_GRAPHITE_CAPTURE');
const _observeFlightFrames = bool.fromEnvironment('UI_GRAPHITE_FLIGHT_OBSERVE');
const _transitionCaptureOnly = bool.fromEnvironment(
  'UI_TRANSITION_CAPTURE_ONLY',
);
const _responsiveShots = {
  'compact': ['16-home-compact-large-text', '17-editor-compact-large-text'],
  'tablet': ['18-home-tablet', '19-editor-tablet'],
  'light': ['22-home-light', '23-editor-light'],
};
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

Future<void> _recordProductionGraphiteOpening(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  _CaptureHost host,
) async {
  await host.event('metadata', 'session', {
    'label': _label,
    'buildMode': 'profile',
    'captureMode': 'graphite-reference-capture',
    'animationsDisabled':
        binding.platformDispatcher.accessibilityFeatures.disableAnimations,
    'firstProductionWidgetMounted': false,
    'physicalSize': [
      tester.view.physicalSize.width,
      tester.view.physicalSize.height,
    ],
    'devicePixelRatio': tester.view.devicePixelRatio,
    'refreshHz': tester.view.display.refreshRate,
    'fixtures': 'Original real file repositories/PNG/WAV and completed guide; actual production app.main; no mocked ports',
    'openingScope': 'Recorder is ready before the first production runApp in this fixture-seeded profile diagnostic process. Excludes OS/VM startup and fixture preparation; no product controller is delayed or replayed.',
  });
  final observations = <Map<String, Object?>>[];
  final clock = Stopwatch();
  var sawLaunch = false;
  await host.event('record_start', '00-graphite-opening');
  try {
    clock.start();
    await app.main(); // The real cold widget mount, showWelcome:true.
    final end = DateTime.now().add(const Duration(seconds: 25));
    var previousValue = -1.0;
    while (true) {
      final decoration = find.byKey(
        const ValueKey('graphite-launch-decoration'),
      );
      if (decoration.evaluate().length == 1) {
        sawLaunch = true;
        final paint = tester.widget<CustomPaint>(
          find
              .descendant(of: decoration, matching: find.byType(CustomPaint))
              .first,
        );
        // Public Animation field on the actual production painter, not a
        // replacement clock/controller or a diagnostic animation overlay.
        final progress =
            (paint.painter as dynamic).progress as Animation<double>;
        if (progress.value != previousValue && observations.length < 128) {
          observations.add({
            'elapsedUs': clock.elapsedMicroseconds,
            'controllerValue': progress.value,
            'controllerStatus': progress.status.name,
            'engineFrameNumber':
                binding.platformDispatcher.frameData.frameNumber,
          });
          previousValue = progress.value;
        }
      }
      final home = homeCreateControl().hitTestable();
      if (sawLaunch &&
          decoration.evaluate().isEmpty &&
          home.evaluate().isNotEmpty) {
        break;
      }
      if (DateTime.now().isAfter(end)) {
        fail(
          'Actual production finite launch was not observed and completed; no replay/padding fallback',
        );
      }
      await tester.pump(const Duration(milliseconds: 25));
    }
    await binding.waitUntilFirstFrameRasterized.timeout(
      const Duration(seconds: 20),
    );
    await tester.pump(const Duration(milliseconds: 450));
  } finally {
    clock.stop();
    await host.event('record_stop', '00-graphite-opening');
  }
  final root = tester.widget<ScribbleSongApp>(find.byType(ScribbleSongApp));
  final scope = ProviderScope.containerOf(
    tester.element(find.byType(ScribbleSongApp)),
  );
  expect(root.showWelcome, isTrue);
  expect(scope.read(settingsProvider).preferences.tutorialCompleted, isTrue);
  expect(observations.length, greaterThanOrEqualTo(2));
  expect(
    observations.last['controllerValue'],
    greaterThan(observations.first['controllerValue']! as double),
  );
  await host.event('graphite_opening', 'opening', {
    'productionEntryPoint': 'lib/main.dart',
    'showWelcome': root.showWelcome,
    'fixtureGuideAlreadyCompleted': scope
        .read(settingsProvider)
        .preferences
        .tutorialCompleted,
    'firstFrameRasterized': binding.firstFrameRasterized,
    'readyHomeRendered': homeCreateControl()
        .hitTestable()
        .evaluate()
        .isNotEmpty,
    'launchEndedWithoutInput': find
        .byKey(const ValueKey('graphite-launch-decoration'))
        .evaluate()
        .isEmpty,
    'observations': observations,
    'actualElapsedUs': clock.elapsedMicroseconds,
    'scope': 'Actual finite production launch controller samples and original clip. Samples are not phase-by-phase compositor presentation or OS cold-start/performance proof.',
  });
}

// Compact graphite Home has one creation key in the persistent instrument dock;
// expanded-text Home additionally exposes its reachable first-content action.
Finder homeCreateControl() {
  final inline = find.byKey(const ValueKey('home-start'));
  return inline.evaluate().isNotEmpty
      ? inline
      : find.byKey(const ValueKey('root-new-drawing'));
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
    expect(
      _responsivePreset.isEmpty ||
          _responsiveShots.containsKey(_responsivePreset),
      isTrue,
    );
    expect(!(_staticBackdropProbe && _responsivePreset.isNotEmpty), isTrue);
    expect(
      !_graphiteCapture ||
          (_label == 'after' &&
              !_staticBackdropProbe &&
              _responsivePreset.isEmpty &&
              !_homeProfileOnly &&
              !_transitionCaptureOnly),
      isTrue,
    );
    expect(
      !_transitionCaptureOnly ||
          (_label == 'after' &&
              !_staticBackdropProbe &&
              _responsivePreset.isEmpty &&
              !_homeProfileOnly),
      isTrue,
    );
    expect(
      !_homeProfileOnly ||
          (_label == 'after' &&
              !_staticBackdropProbe &&
              _responsivePreset.isEmpty),
      isTrue,
    );
    final host = _CaptureHost();
    addTearDown(host.close);
    await _seedFixtures();
    if (_graphiteCapture) {
      await _recordProductionGraphiteOpening(tester, binding, host);
    } else {
      await app.main();
    }
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

    Future<Finder> rootTarget(String id) async {
      final target = key(id);
      final summary = key('nav-summary').hitTestable();
      if (target.hitTestable().evaluate().isEmpty &&
          summary.evaluate().isNotEmpty) {
        await tap(summary);
      }
      await until(() => target.hitTestable().evaluate().isNotEmpty);
      return target.hitTestable();
    }

    Future<void> control(String id, String fallback) async =>
        tap(key(id).evaluate().isNotEmpty ? key(id) : find.byTooltip(fallback));
    Future<void> tab(String name) async {
      final target = await rootTarget('nav-${name.toLowerCase()}');
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
      return uiRenderedRouteAnchor(tester.element(finder.first));
    }

    UiTextScaleWitness textScaleWitness(BuildContext context) =>
        UiTextScaleWitness(
          scaler: MediaQuery.textScalerOf(context),
          platformNominal: binding.platformDispatcher.textScaleFactor,
        );

    UiImeOcclusionWitness imeWitness() => UiImeOcclusionWitness(
      physicalHeight: tester.view.physicalSize.height,
      physicalInset: tester.view.viewInsets.bottom,
      dpr: tester.view.devicePixelRatio,
      field: tester.getRect(find.byType(TextField)),
      cancel: tester.getRect(find.widgetWithText(TextButton, 'Cancel')),
      focused: find
          .byType(EditableText)
          .evaluate()
          .any(
            (element) => (element.widget as EditableText).focusNode.hasFocus,
          ),
      cancelHitTestable: find
          .widgetWithText(TextButton, 'Cancel')
          .hitTestable()
          .evaluate()
          .isNotEmpty,
      mockInputRegistered: binding.testTextInput.isRegistered,
    );

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
          canvas.evaluate().isNotEmpty &&
          uiRenderedEditorAnchor(
            tester.element(canvas.first),
            hasPanel: hasPanel,
          ) &&
          find.text(title).evaluate().isNotEmpty;
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
        '24-graphite-editor' => editor('Morning tide'),
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
              textScaleWitness(context).matches(2),
        '17-editor-compact-large-text' =>
          editor('Morning tide') &&
              width <= 321 &&
              textScaleWitness(context).matches(2),
        '18-home-tablet' =>
          uri == '/home' && !hasPanel && renderedAnchor(home) && width >= 800,
        '19-editor-tablet' => editor('Morning tide') && width >= 800,
        '20-rename-native-ime' =>
          uri == '/drafts' &&
              renderedAnchor(find.byType(TextField)) &&
              tester.view.viewInsets.bottom > 100 &&
              !binding.testTextInput.isRegistered &&
              imeWitness().ready,
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
              textScaleWitness(context).matches(1) &&
              Theme.of(context).brightness == Brightness.light &&
              !MediaQuery.disableAnimationsOf(context),
        '23-editor-light' =>
          editor('Morning tide') &&
              width >= 410 &&
              width <= 412 &&
              textScaleWitness(context).matches(1) &&
              Theme.of(context).brightness == Brightness.light &&
              !MediaQuery.disableAnimationsOf(context),
        _ => false,
      };
    }

    Future<void> shot(String name) async {
      if (_responsivePreset.isNotEmpty &&
          !_responsiveShots[_responsivePreset]!.contains(name)) {
        throw StateError('Screenshot outside requested responsive subset');
      }
      if (_staticBackdropProbe) {
        throw StateError(
          'Diagnostic-only probe cannot emit normal screenshots',
        );
      }
      await until(() => expectedShot(name));
      final fence = UiPresentationFence(
        binding,
        isExpected: () => expectedShot(name),
        screenshotSnapshot: () {
          final context = tester.element(find.byType(Scaffold).first);
          return {
            ...textScaleWitness(context).toJson(),
            if (name == '20-rename-native-ime')
              'nativeImeGeometry': imeWitness().toJson(),
            'devicePixelRatio': tester.view.devicePixelRatio,
            'logicalViewportWidth': MediaQuery.sizeOf(context).width,
            'bodyMediumFontSize': Theme.of(context)
                .textTheme
                .bodyMedium!
                .fontSize!,
            'headlineLargeFontSize': Theme.of(context)
                .textTheme
                .headlineLarge!
                .fontSize!,
          };
        },
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
      if (_responsivePreset.isNotEmpty) {
        throw StateError('Responsive subset cannot record normal clips');
      }
      if (_staticBackdropProbe) {
        throw StateError('Diagnostic-only probe cannot emit normal recordings');
      }
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
      if (_responsivePreset.isNotEmpty) {
        throw StateError(
          'Responsive subset cannot report performance profiles',
        );
      }
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
      if (name.startsWith('diagnostic-static-backdrop-')) {
        result['scope'] = 'One opt-in same-run radial-backdrop diagnostic; not normal Home/product, video, smoothness or device acceptance';
        result['diagnosticOnly'] = true;
      }
      result['observationElapsedUs'] = end - start;
      if (visibleScope.isNotEmpty) result['visibleScope'] = visibleScope;
      await host.event('perf_finish', name, {
        'result': result,
        'recordingDuringMeasurement': false,
      });
    }

    Future<void> collectHomeClock({
      required Finder create,
      required Finder aurora,
      required AnimationController controller,
      required List<Map<String, Object?>> clockSamples,
      required Stopwatch stopwatch,
      required UiFrameClockObserver frameClock,
      void Function()? verify,
      Map<String, Object?> Function()? additionalFields,
    }) async {
      stopwatch.start();
      frameClock.start();
      try {
        for (var index = 0; index < 34; index++) {
          verify?.call();
          await wait(500);
          verify?.call();
          final createBox = tester.getRect(create);
          final auroraBox = tester.getRect(aurora);
          final logicalViewport =
              Offset.zero &
              (tester.view.physicalSize / tester.view.devicePixelRatio);
          clockSamples.add({
            if (additionalFields != null) ...additionalFields(),
            'staticCacheRawImages': tester
                .widgetList<RawImage>(
                  find.descendant(of: aurora, matching: find.byType(RawImage)),
                )
                .map(
                  (widget) => {
                    'width': widget.image?.width,
                    'height': widget.image?.height,
                  },
                )
                .toList(),
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
            'homeCreateHitTestable': create.hitTestable().evaluate().isNotEmpty,
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
    }

    Map<String, Object?>? subsetHomeReadiness;
    if (_responsivePreset.isNotEmpty ||
        _homeProfileOnly ||
        _transitionCaptureOnly ||
        _graphiteCapture) {
      await until(() {
        final home = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'HomePage',
        );
        final create = homeCreateControl(), artwork = key('home-artwork');
        if (home.evaluate().length != 1 ||
            create.hitTestable().evaluate().isEmpty ||
            artwork.evaluate().length != 1 ||
            !renderedAnchor(home)) {
          return false;
        }
        final projects = container()
            .read(libraryProvider)
            .asData
            ?.value
            .projects;
        if (projects == null ||
            projects.isEmpty ||
            !projects.any(
              (project) =>
                  project.id == 'capture-morning' &&
                  project.title == 'Morning tide',
            )) {
          return false;
        }
        final selected = tester.widget<Semantics>(artwork).properties.label;
        if (selected != projects.first.title) return false;
        subsetHomeReadiness = {
          'visibleHomeRendered': true,
          'homeCreateHitTestable': true,
          'realRepositoryFixtureLoaded': 'capture-morning',
          'actualRecentTitle': selected,
          'lazyGalleryRequired': false,
          'scrollForced': false,
        };
        return router().routeInformationProvider.value.uri.path == '/home';
      });
    } else {
      await until(() => find.text('Paper hills').evaluate().isNotEmpty);
    }
    // Widget existence alone did not prove native splash handoff in the first
    // after run. Wait for an actual engine-rasterized frame as well; the host
    // independently rejects the observed flat compositor/splash image.
    await binding.waitUntilFirstFrameRasterized.timeout(
      const Duration(seconds: 20),
    );
    await wait(1500);
    if (!_graphiteCapture) {
      await host.event('metadata', 'session', {
        'firstFrameRasterized': binding.firstFrameRasterized,
        'subsetHomeReadiness': ?subsetHomeReadiness,
        'label': _label,
        'buildMode': 'profile',
        'captureMode': _responsivePreset.isNotEmpty
            ? 'responsive-$_responsivePreset'
            : (_staticBackdropProbe
                  ? 'diagnostic-static-backdrop-only'
                  : (_homeProfileOnly
                        ? 'home-profile-only'
                        : (_transitionCaptureOnly
                              ? 'transition-capture-only'
                              : 'normal-product-ui-capture'))),
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
    }
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byType(Scaffold).first),
      ),
      isFalse,
    );
    if (_responsivePreset.isNotEmpty) {
      expect(_label, 'after');
      // The owned host applied the actual display/font preset before app.main.
      // No live wm/density/font change or MediaQuery override occurs here.
      if (_responsivePreset == 'light') {
        await preference(dark: false, reduce: false);
      }
      final names = _responsiveShots[_responsivePreset]!;
      await shot(names.first);
      await route('/editor/capture-morning');
      await shot(names.last);
      await host.event('responsive_complete', _responsivePreset, {
        'passed': true,
        'subsetOnly': true,
        'responsivePreset': _responsivePreset,
        'normalFullCapturePassed': false,
      });
      binding.reportData = {
        'responsiveSubsetPassed': true,
        'responsivePreset': _responsivePreset,
        'completedScreenshotNames': names,
        'normalFullCapturePassed': false,
      };
      expect(tester.takeException(), isNull);
      return;
    }
    if (_staticBackdropProbe) {
      expect(
        _label,
        'after',
        reason: 'Backdrop probe requires the current immersive source',
      );
      final home = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'HomePage',
      );
      final create = homeCreateControl();
      final aurora = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'AuroraScene',
      );
      expect(home, findsOneWidget);
      expect(aurora, findsOneWidget);
      expect(create.hitTestable(), findsOneWidget);
      expect(router().routeInformationProvider.value.uri.path, '/home');
      RenderDecoratedBox lookupBackdrop() {
        expect(home, findsOneWidget);
        expect(renderedAnchor(home), isTrue);
        final backdrop = find.descendant(
          of: home,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == 'SceneBackdrop',
          ),
        );
        expect(backdrop, findsOneWidget);
        final element = tester.element(backdrop),
            homeElement = tester.element(home);
        var belongsToHome = false;
        element.visitAncestorElements((ancestor) {
          if (identical(ancestor, homeElement)) belongsToHome = true;
          return true;
        });
        expect(belongsToHome, isTrue);
        final direct = <Element>[];
        element.visitChildElements(direct.add);
        expect(direct, hasLength(1));
        expect(direct.single.widget, isA<DecoratedBox>());
        final render = direct.single.findRenderObject();
        expect(render, isA<RenderDecoratedBox>());
        return render! as RenderDecoratedBox;
      }

      AnimationController actualController() {
        final controllers = tester
            .widgetList<AnimatedBuilder>(
              find.descendant(
                of: aurora,
                matching: find.byType(AnimatedBuilder),
              ),
            )
            .map((builder) => builder.animation)
            .whereType<AnimationController>()
            .toSet();
        expect(controllers, hasLength(1));
        return controllers.single;
      }

      List<ui.Image> actualTextures() => tester
          .widgetList<RawImage>(
            find.descendant(of: aurora, matching: find.byType(RawImage)),
          )
          .map((widget) => widget.image)
          .whereType<ui.Image>()
          .toList();
      await until(() => actualTextures().length == 1);
      final homeScaffold = find.descendant(
        of: home,
        matching: find.byType(Scaffold),
      );
      expect(homeScaffold, findsOneWidget);
      final context = tester.element(homeScaffold);
      final viewport =
          Offset.zero &
          (tester.view.physicalSize / tester.view.devicePixelRatio);
      final controller = actualController(),
          initialState = tester.state(aurora),
          texture = actualTextures().single;
      final originalAuroraBounds = tester.getRect(aurora),
          originalCreateBounds = tester.getRect(create);
      final originalDpr = tester.view.devicePixelRatio;
      final probe = UiStaticBackdropProbe(
        target: lookupBackdrop(),
        lookupCurrentTarget: lookupBackdrop,
        homeScaffold: context.findRenderObject()! as RenderBox,
        viewport: viewport,
        expectedSurface: Theme.of(context).colorScheme.surface,
      );
      void verify(bool solidMode) {
        probe.verify(solidMode: solidMode);
        expect(router().routeInformationProvider.value.uri.path, '/home');
        expect(tester.state(aurora), same(initialState));
        expect(actualController(), same(controller));
        expect(actualTextures(), hasLength(1));
        expect(actualTextures().single, same(texture));
        expect(controller.isAnimating, isTrue);
        expect(controller.duration, const Duration(seconds: 16));
        expect(TickerMode.valuesOf(tester.element(aurora)).enabled, isTrue);
        expect(binding.lifecycleState, AppLifecycleState.resumed);
        expect(MediaQuery.disableAnimationsOf(tester.element(create)), isFalse);
        expect(timeDilation, 1);
        expect(tester.view.devicePixelRatio, originalDpr);
        expect(tester.getRect(aurora), originalAuroraBounds);
        expect(tester.getRect(create), originalCreateBounds);
        expect(create.hitTestable(), findsOneWidget);
      }

      bool expected(bool solidMode) {
        try {
          verify(solidMode);
          return true;
        } catch (_) {
          return false;
        }
      }

      Future<void> phase(String name, bool solidMode) async {
        verify(solidMode);
        final samples = <Map<String, Object?>>[], watch = Stopwatch();
        final clock = UiFrameClockObserver(binding);
        final elapsedBefore = controller.lastElapsedDuration?.inMicroseconds;
        expect(elapsedBefore, isNotNull);
        await measure(
          name,
          () => collectHomeClock(
            create: create,
            aurora: aurora,
            controller: controller,
            clockSamples: samples,
            stopwatch: watch,
            frameClock: clock,
            verify: () => verify(solidMode),
            additionalFields: () => {
              'backdropSolid': solidMode,
              'sameAuroraStateControllerTexture': true,
            },
          ),
          visibleScope: {
            'diagnosticOnly': true,
            'probe': 'single-static-radial-backdrop',
            'solidMode': solidMode,
            'recordingDuringMeasurement': false,
            'target': probe.witness(),
            'devicePixelRatio': originalDpr,
            'nominalObservationMilliseconds': 17000,
            'sameAuroraStateControllerTextureRequired': true,
            'clockSamples': samples,
          },
        );
        verify(solidMode);
        expect(
          controller.lastElapsedDuration!.inMicroseconds,
          greaterThan(elapsedBefore!),
        );
      }

      Map<String, Object>? restoredFrames;
      try {
        await phase('diagnostic-static-backdrop-normal', false);
        probe.applySolid();
        await waitForNaturalProbeRasters(
          binding,
          expected: () => expected(true),
        );
        await phase('diagnostic-static-backdrop-solid', true);
      } finally {
        probe.restore();
        restoredFrames = await waitForNaturalProbeRasters(
          binding,
          expected: () => expected(false),
        );
        verify(false);
        await host.event('static_backdrop_restored', 'static-backdrop-probe', {
          'diagnosticOnly': true,
          'exactDecorationRestored': true,
          'freshLookupSameTarget': true,
          'restoredRasterEvidence': restoredFrames,
          'target': probe.witness(),
        });
      }
      await host.event('diagnostic_complete', 'static-backdrop-probe', {
        'passed': true,
        'diagnosticOnly': true,
        'normalFootageProduced': false,
      });
      binding.reportData = {
        'diagnosticPassed': true,
        'diagnosticOnly': true,
        'normalProductCapturePassed': false,
        'normalFootageProduced': false,
      };
      expect(tester.takeException(), isNull);
      return;
    }
    if (_graphiteCapture) {
      await shot('01-home');
      Finder libraryTab(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'LibraryTabs',
        ),
        matching: find.text(label),
      );
      Future<void> graphiteUntil(
        bool Function() condition, {
        int seconds = 30,
      }) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (!condition()) {
          if (DateTime.now().isAfter(end)) {
            fail('Graphite actual-state readiness timed out');
          }
          await wait(25);
        }
      }

      var actions = <Map<String, Object?>>[];
      var clock = Stopwatch();
      void note(
        String name,
        Rect bounds,
        BuildContext context, {
        int waitMs = 350,
      }) {
        actions.add({
          'action': name,
          'tapElapsedUs': clock.elapsedMicroseconds,
          'engineFrameNumber': binding.platformDispatcher.frameData.frameNumber,
          'reducedMotion': MediaQuery.disableAnimationsOf(context),
          'targetBounds': [
            bounds.left,
            bounds.top,
            bounds.width,
            bounds.height,
          ],
          'requestedPostTapWaitMs': waitMs,
        });
      }

      Future<void> action(
        String name,
        Finder target, {
        int waitMs = 350,
      }) async {
        await graphiteUntil(() => target.hitTestable().evaluate().isNotEmpty);
        final actual = target.hitTestable().last;
        note(
          name,
          tester.getRect(actual),
          tester.element(actual),
          waitMs: waitMs,
        );
        await tester.tap(actual); // Fatal missed-hit policy stays enabled.
        await wait(waitMs);
      }

      Future<void> recorded(
        String name,
        Future<Map<String, Object?>> Function() run,
      ) async {
        actions = [];
        clock = Stopwatch();
        late Map<String, Object?> witnesses;
        await clip(name, () async {
          clock.start();
          witnesses = await run();
          clock.stop();
        });
        await host.event('graphite_trace', name, {
          'actions': actions,
          'actualElapsedUs': clock.elapsedMicroseconds,
          'witnesses': witnesses,
        });
      }

      bool warmHome() =>
          expectedShot('01-home') &&
          key('graphite-launch-decoration').evaluate().isEmpty;
      await measure(
        'graphite-interactions-unrecorded',
        () async {
          await tab('Library');
          for (var i = 0; i < 4; i++) {
            await tap(libraryTab(i.isEven ? 'Exports' : 'Drafts'));
          }
          await tab('Home');
          await tap(key('home-artwork'));
          await graphiteUntil(() => expectedShot('24-graphite-editor'));
          await control('editor-back', 'Back to gallery');
          await graphiteUntil(warmHome);
          final scrollable = find
              .descendant(
                of: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == 'HomePage',
                ),
                matching: find.byType(Scrollable),
              )
              .hitTestable();
          await tester.drag(scrollable.first, const Offset(0, -240));
          await wait(400);
          await tester.drag(scrollable.first, const Offset(0, 240));
          await wait(400);
        },
        visibleScope: {
          'graphiteProductionInteractions': true,
          'screenRecordingActive': false,
          'scope': 'Actual Library switches, source artwork navigation/Back and Home drag; software-emulator UI/raster timing, not physical display drops or audio acceptance',
        },
      );
      await tester.ensureVisible(key('home-artwork'));
      await wait(350);
      await recorded('01-root-navigation', () async {
        await action('root-library', await rootTarget('nav-library'));
        for (var i = 0; i < 4; i++) {
          await action(
            'library-normal-$i',
            libraryTab(i.isEven ? 'Exports' : 'Drafts'),
          );
        }
        for (var i = 0; i < 6; i++) {
          await action(
            'library-rapid-$i',
            libraryTab(i.isEven ? 'Exports' : 'Drafts'),
            waitMs: 80,
          );
        }
        await graphiteUntil(() => expectedShot('02-drafts'));
        await action('root-settings', await rootTarget('nav-settings'));
        await action('root-home', await rootTarget('nav-home'));
        await graphiteUntil(warmHome);
        return {'retainedLibraryReady': true, 'warmLaunchNotReplayed': true};
      });
      await tab('Library');
      await tap(libraryTab('Drafts'));
      await shot('02-drafts');
      await tap(libraryTab('Exports'));
      await shot('03-exports');
      await tab('Settings');
      await shot('04-settings');
      await tab('Home');
      await recorded('02-editor-instrument', () async {
        final flightObserver = _observeFlightFrames
            ? UiFlightFrameObserver(binding, () {
                final mountedCanvas = find.byKey(
                  const ValueKey('drawing-canvas'),
                  skipOffstage: false,
                );
                final visibleCanvas = key('drawing-canvas');
                final hitCanvas = visibleCanvas.hitTestable();
                final visibleShuttle = key('artwork-flight-shuttle');
                final canvasElements = visibleCanvas.evaluate().toList();
                final contexts = canvasElements.isNotEmpty
                    ? canvasElements
                    : mountedCanvas.evaluate().isNotEmpty
                    ? mountedCanvas.evaluate().toList()
                    : key('home-artwork').evaluate().toList();
                final context = contexts.isEmpty ? null : contexts.first;
                GoRouterState? route;
                String? routeReadError;
                if (context != null) {
                  try {
                    route = GoRouterState.of(context);
                  } catch (error) {
                    routeReadError = error.runtimeType.toString();
                  }
                }
                final extra = route?.extra;
                final modal = context == null ? null : ModalRoute.of(context);
                final opacity = visibleShuttle.evaluate().isNotEmpty
                    ? tester.widget<Opacity>(visibleShuttle.first).opacity
                    : null;
                final rect = hitCanvas.evaluate().isNotEmpty
                    ? tester.getRect(hitCanvas.first)
                    : null;
                return {
                  'routePath': route?.uri.path,
                  'routeReadErrorType': routeReadError,
                  'routeType': modal?.runtimeType.toString(),
                  'routeTransitionDurationUs':
                      modal?.transitionDuration.inMicroseconds,
                  'routeReverseDurationUs':
                      modal?.reverseTransitionDuration.inMicroseconds,
                  'canvasMountedCount': mountedCanvas.evaluate().length,
                  'canvasVisibleCount': canvasElements.length,
                  'canvasHitTestableCount': hitCanvas.evaluate().length,
                  'canvasElementIdentity': canvasElements.isEmpty
                      ? null
                      : identityHashCode(canvasElements.first),
                  'canvasRect': rect == null
                      ? null
                      : [rect.left, rect.top, rect.width, rect.height],
                  'shuttleVisibleCount': visibleShuttle.evaluate().length,
                  'shuttleMountedCount': find
                      .byKey(
                        const ValueKey('artwork-flight-shuttle'),
                        skipOffstage: false,
                      )
                      .evaluate()
                      .length,
                  'shuttleOpacity': opacity,
                  'intentPresent': extra is ArtworkFlightIntent,
                  'intentCancelled': extra is ArtworkFlightIntent
                      ? extra.cancelled
                      : null,
                  'matchingHeroTags': extra is ArtworkFlightIntent
                      ? find
                            .byWidgetPredicate(
                              (widget) =>
                                  widget is Hero && widget.tag == extra.tag,
                              skipOffstage: false,
                            )
                            .evaluate()
                            .length
                      : 0,
                  'reducedMotion': context == null
                      ? null
                      : MediaQuery.disableAnimationsOf(context),
                  'routeAnimationValue': modal?.animation?.value,
                  'routeAnimationStatus': modal?.animation?.status.name,
                  'lifecycle': binding.lifecycleState?.name,
                };
              })
            : null;
        flightObserver?.start();
        try {
          await action('artwork-open', key('home-artwork'), waitMs: 0);
          await graphiteUntil(
            () =>
                key('drawing-canvas').hitTestable().evaluate().isNotEmpty &&
                key('artwork-flight-shuttle').evaluate().isNotEmpty,
          );
          final canvas = key('drawing-canvas').hitTestable().first;
          final bounds = tester.getRect(canvas);
          final intent =
              GoRouterState.of(tester.element(canvas)).extra as dynamic;
          expect(intent, isNotNull);
          expect(intent.cancelled, isFalse);
          note('canvas-first-input', bounds, tester.element(canvas), waitMs: 0);
          final gesture = await tester.startGesture(
            Offset(
              bounds.left + bounds.width * .28,
              bounds.top + bounds.height * .58,
            ),
          );
          expect(intent.cancelled, isTrue);
          for (var i = 1; i <= 4; i++) {
            await gesture.moveTo(
              Offset(
                bounds.left + bounds.width * (.28 + i * .04),
                bounds.top + bounds.height * (.58 - i * .025),
              ),
            );
            await wait(20);
          }
          await gesture.up();
          await wait(150);
          expect(tester.getRect(canvas), bounds);
        } finally {
          if (flightObserver != null) {
            final observed = flightObserver.stop();
            final samples =
                observed.remove('samples')! as List<Map<String, Object?>>;
            // Bounded JSON lines stay below native log-line limits. No source
            // documents, URI query/session IDs or test capabilities are dumped.
            debugPrintSynchronously(
              'UI_GRAPHITE_FLIGHT_SUMMARY ${jsonEncode(observed)}',
            );
            for (final sample in samples) {
              debugPrintSynchronously(
                'UI_GRAPHITE_FLIGHT_FRAME ${jsonEncode(sample)}',
              );
            }
          }
        }
        await action('voice-open', key('current-voice'));
        await action('voice-bell', key('voice-bell'));
        await action('play', find.byTooltip('Play'));
        await graphiteUntil(
          () => find.byTooltip('Pause').hitTestable().evaluate().isNotEmpty,
        );
        await action('pause', find.byTooltip('Pause'));
        await graphiteUntil(
          () => find.byTooltip('Play').hitTestable().evaluate().isNotEmpty,
        );
        await action('music-open', key('music-settings'));
        await action('music-close', find.byTooltip('Close'));
        await action('tools-open', key('editor-tools'));
        await action('tools-close', find.byTooltip('Close'));
        await action('background-open', key('editor-background'));
        await action('background-close', find.text('Cancel'));
        await action(
          'editor-back',
          find.byTooltip('Back to gallery'),
          waitMs: 0,
        );
        await graphiteUntil(
          () => key('home-artwork').hitTestable().evaluate().isNotEmpty,
        );
        await action('rapid-artwork-reopen', key('home-artwork'), waitMs: 0);
        await graphiteUntil(
          () => find.byTooltip('Play').hitTestable().evaluate().isNotEmpty,
        );
        await action('rapid-play', find.byTooltip('Play'), waitMs: 0);
        await graphiteUntil(
          () => find.byTooltip('Pause').hitTestable().evaluate().isNotEmpty,
        );
        await action('rapid-pause', find.byTooltip('Pause'));
        await action('rapid-back', find.byTooltip('Back to gallery'));
        await graphiteUntil(warmHome);
        return {
          'heroObserved': true,
          'firstInputCancelledPresentation': true,
          'canvasRectStable': true,
          'playingUiObserved': true,
          'pausedUiObserved': true,
          'warmLaunchNotReplayed': true,
          'audioScope': 'Actual production transport UI/native adapter; silent screenrecord is not physical audibility/latency proof',
        };
      });
      await tap(key('home-artwork'));
      await shot('24-graphite-editor');
      await tap(key('current-voice'));
      await shot('08-instruments');
      await tap(key('voice-bell'));
      await control('editor-export', 'Export loop');
      await shot('10-export-selection');
      await recorded('05-export-ready', () async {
        final strings = tester.element(key('export-start')).strings;
        await action('cancel-format-video', key('export-intent-mp4'));
        await action('cancel-start', key('export-start'), waitMs: 0);
        await graphiteUntil(() => key('export-working').evaluate().isNotEmpty);
        await action('cancel-job', key('export-start'), waitMs: 0);
        await graphiteUntil(
          () => find.text(strings.exportCancelled).evaluate().isNotEmpty,
          seconds: 60,
        );
        await wait(450); // Actual readable cancellation state, no added frames.
        await action('error-format-image', key('export-intent-png'));
        final root = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/exports',
        );
        final backup = Directory('${root.path}-graphite-owned-fixture-backup');
        final blocker = File(root.path);
        const marker =
            'Owned graphite fixture I/O fault; restore before retry.';
        expect(await root.exists(), isTrue);
        expect(await backup.exists(), isFalse);
        var restored = false;
        await root.rename(backup.path);
        try {
          await blocker.writeAsString(marker, flush: true);
          await action('error-start', key('export-start'), waitMs: 0);
          await graphiteUntil(
            () => find.text(strings.exportFailed).evaluate().isNotEmpty,
            seconds: 60,
          );
          await wait(450); // Leave the actual I/O error readable before retry.
        } finally {
          if (await blocker.exists()) {
            expect(await blocker.readAsString(), marker);
            await blocker.delete();
          }
          expect(await root.exists(), isFalse);
          await backup.rename(root.path);
          restored = await root.exists() && !await backup.exists();
        }
        expect(restored, isTrue);
        await action('retry-export', key('export-start'), waitMs: 0);
        await graphiteUntil(
          () => key('export-ready').evaluate().isNotEmpty,
          seconds: 60,
        );
        expect(find.text(strings.exportReady), findsOneWidget);
        final published = (await FileExportLibrary(root).list()).entries
            .where(
              (entry) =>
                  entry.available &&
                  entry.artifact.projectId == 'capture-morning' &&
                  entry.artifact.mime == 'image/png',
            )
            .toList();
        expect(published, isNotEmpty);
        final bytes = await File(published.first.artifact.path).readAsBytes();
        expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
        return {
          'cancelObserved': true,
          'actualIoErrorObserved': true,
          'fixtureDirectoryRestored': restored,
          'readyAfterRetry': true,
          'faultScope': 'Actual I/O failure from a temporary blocker in this fresh diagnostic app exports directory; original fixture directory restored, no mocked adapter or fake UI state',
        };
      });
      await shot('11-export-ready');
      await tap(find.byTooltip('Close'));
      await control('editor-back', 'Back to gallery');
      await graphiteUntil(warmHome);
      expect(
        container().read(settingsProvider).preferences.reduceMotion,
        isFalse,
      );
      await recorded('06-reduced-motion', () async {
        await host.event('system_motion', 'reduced');
        await graphiteUntil(
          () => MediaQuery.disableAnimationsOf(
            tester.element(homeCreateControl()),
          ),
        );
        expect(
          container().read(settingsProvider).preferences.reduceMotion,
          isFalse,
        );
        await action('system-library', await rootTarget('nav-library'));
        await action('system-exports', libraryTab('Exports'));
        await action('system-drafts', libraryTab('Drafts'));
        await action('system-home', await rootTarget('nav-home'));
        await host.event('system_motion', 'normal');
        await graphiteUntil(
          () => !MediaQuery.disableAnimationsOf(
            tester.element(homeCreateControl()),
          ),
        );
        await preference(reduce: true);
        expect(
          MediaQuery.disableAnimationsOf(tester.element(homeCreateControl())),
          isTrue,
        );
        await action('stored-library', await rootTarget('nav-library'));
        await action('stored-exports', libraryTab('Exports'));
        await action('stored-drafts', libraryTab('Drafts'));
        await action('stored-home', await rootTarget('nav-home'));
        await graphiteUntil(warmHome);
        return {
          'storedFalseDuringSystem': true,
          'systemRestoredBeforeStored': true,
          'systemAndStoredObserved': true,
          'warmLaunchNotReplayed': true,
        };
      });
      await shot('15-home-reduced-motion');
      await preference(reduce: false);
      expect(
        MediaQuery.disableAnimationsOf(tester.element(homeCreateControl())),
        isFalse,
      );
      await host.event('graphite_complete', 'graphite', {
        'passed': true,
        'normalFullCapturePassed': false,
        'storedMotionRestored': !container()
            .read(settingsProvider)
            .preferences
            .reduceMotion,
        'performanceScope': 'Real unrecorded profile timings are separate from five original silent clips; not physical FPS/audio/iOS acceptance',
      });
      binding.reportData = {
        'graphiteSubsetPassed': true,
        'normalFullCapturePassed': false,
      };
      expect(tester.takeException(), isNull);
      return;
    }
    if (_transitionCaptureOnly) {
      await shot('01-home');
      Future<void> transitionPhase(String name, bool reduced) async {
        await preference(dark: true, reduce: reduced);
        final actions = <Map<String, Object?>>[];
        final clock = Stopwatch();
        Future<void> action(String tag, Finder target, int settleMs) async {
          await until(() => target.hitTestable().evaluate().isNotEmpty);
          final actual = target.hitTestable().last;
          final bounds = tester.getRect(actual);
          final disabled = MediaQuery.disableAnimationsOf(
            tester.element(actual),
          );
          expect(disabled, reduced);
          final elapsed = clock.elapsedMicroseconds;
          await tester.tap(actual); // Fatal missed-hit policy remains enabled.
          actions.add({
            'action': tag,
            'tapElapsedUs': elapsed,
            'reducedMotion': disabled,
            'engineFrameNumber':
                binding.platformDispatcher.frameData.frameNumber,
            'targetBounds': [
              bounds.left,
              bounds.top,
              bounds.width,
              bounds.height,
            ],
            'requestedPostTapWaitMs': settleMs,
          });
          await wait(settleMs); // Real wall time under benchmarkLive policy.
        }

        Finder libraryTab(String label) => find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == 'LibraryTabs',
          ),
          matching: find.text(label),
        );
        await clip(name, () async {
          clock.start();
          await action('root-library', await rootTarget('nav-library'), 700);
          await until(
            () => libraryTab('Exports').hitTestable().evaluate().isNotEmpty,
          );
          for (var i = 0; i < 4; i++) {
            await action(
              'library-normal-$i',
              libraryTab(i.isEven ? 'Exports' : 'Drafts'),
              700,
            );
          }
          for (var i = 0; i < 6; i++) {
            await action(
              'library-rapid-$i',
              libraryTab(i.isEven ? 'Exports' : 'Drafts'),
              80,
            );
          }
          await until(() => expectedShot('02-drafts'));
          await action('root-settings', await rootTarget('nav-settings'), 700);
          await action('root-home', await rootTarget('nav-home'), 700);
          await action(
            'root-library-return',
            await rootTarget('nav-library'),
            700,
          );
          await action('root-home-editor', await rootTarget('nav-home'), 700);
          await action('editor-open', find.text('Paper hills'), 1000);
          await until(() => expectedShot('05-editor-drawn'));
          await action('editor-back', find.byTooltip('Back to gallery'), 700);
          await until(() => expectedShot('01-home'));
          await action('sheet-editor-open', find.text('Paper hills'), 1000);
          await until(() => expectedShot('05-editor-drawn'));
          await action('sheet-tools-open', key('editor-tools'), 700);
          await action('sheet-paper-open', key('editor-tool-paper'), 700);
          await until(
            () => find.text('Cancel').hitTestable().evaluate().isNotEmpty,
          );
          await action('sheet-close', find.text('Cancel'), 700);
          await until(() => find.byType(BottomSheet).evaluate().isEmpty);
          await action(
            'sheet-editor-back',
            find.byTooltip('Back to gallery'),
            700,
          );
          await until(() => expectedShot('01-home'));
          clock.stop();
        });
        debugPrint(
          'UI_TRANSITION_TRACE ${jsonEncode({'name': name, 'actions': actions, 'actualElapsedUs': clock.elapsedMicroseconds, 'scope': 'Actual hit-tested taps and wall-clock waits; rapid80ms is requested spacing, actual elapsed times are reported. No synthetic animation clock, padding, retiming or smoothness claim.'})}',
        );
        await host.event('transition_trace', name, {
          'actions': actions,
          'reducedMotion': reduced,
          'actualElapsedUs': clock.elapsedMicroseconds,
          'finalHomeRendered': true,
        });
      }

      await transitionPhase('01-root-navigation', false);
      await transitionPhase('06-reduced-motion', true);
      await host.event('transition_complete', 'transitions', {
        'passed': true,
        'subsetOnly': true,
        'normalFullCapturePassed': false,
      });
      binding.reportData = {
        'transitionSubsetPassed': true,
        'normalFullCapturePassed': false,
      };
      expect(tester.takeException(), isNull);
      return;
    }
    await shot('01-home');
    if (_label == 'after') {
      final create = homeCreateControl();
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
          await collectHomeClock(
            create: create,
            aurora: aurora,
            controller: controller,
            clockSamples: clockSamples,
            stopwatch: stopwatch,
            frameClock: frameClock,
          );
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
    if (_homeProfileOnly) {
      await host.event('home_profile_complete', 'home-profile', {
        'passed': true,
        'subsetOnly': true,
        'normalFullCapturePassed': false,
      });
      binding.reportData = {
        'homeProfileSubsetPassed': true,
        'normalFullCapturePassed': false,
      };
      expect(tester.takeException(), isNull);
      return;
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
        // The production field autofocuses and requests the real IME. A second
        // tap races the platform resize; observe actual focus/insets instead.
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
        final imeWatch = Stopwatch()..start();
        while (!imeWitness().ready &&
            imeWatch.elapsed < const Duration(seconds: 20)) {
          // benchmarkLive pump only yields real wall time; no synthetic frame,
          // inset or animation clock is injected into the product.
          await wait(100);
        }
        Future<void> retainImeDiagnostic(String stage) async {
          debugPrint(
            'UI_NATIVE_IME_UNACCEPTED ${jsonEncode({...imeWitness().toJson(), 'status': 'UNACCEPTED_DIAGNOSTIC_ONLY', 'stage': stage, 'layoutWaitUs': imeWatch.elapsedMicroseconds, 'engineFrameNumber': binding.platformDispatcher.frameData.frameNumber})}',
          );
          await host.event('snapshot', '20-rename-native-ime-unaccepted');
        }

        if (!imeWitness().ready) {
          await retainImeDiagnostic('native-layout-deadline');
          fail(
            'Real native IME panel did not make field and Cancel reachable within20s; unaccepted native PNG and geometry retained.',
          );
        }
        try {
          await shot('20-rename-native-ime');
        } catch (_) {
          await retainImeDiagnostic('expected-state-raster-deadline');
          rethrow;
        }
        // Preserve strict geometry assertions AFTER the exact-state raster
        // fence, using current real occlusion rather than first-arriving metrics.
        final keyboardInset = tester.view.viewInsets.bottom;
        final visibleBottom = imeWitness().visibleBottom;
        final fieldBounds = tester.getRect(find.byType(TextField));
        final cancel = find.widgetWithText(TextButton, 'Cancel');
        final cancelBounds = tester.getRect(cancel);
        expect(fieldBounds.bottom, lessThanOrEqualTo(visibleBottom));
        expect(cancelBounds.bottom, lessThanOrEqualTo(visibleBottom));
        expect(cancel.hitTestable(), findsOneWidget);
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
