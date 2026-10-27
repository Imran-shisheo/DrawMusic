import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      Duration(seconds: operation == 'record_stop' ? 100 : 35),
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

    Future<void> shot(String name) async {
      await wait(250);
      await host.event('snapshot', name);
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
      // Record actual decorative motion before interacting. A still screenshot
      // cannot establish the immersive Home sculpture's motion requirement.
      await clip('00-home-ambient', () async => wait(18000));
      final create = key('home-start');
      expect(create.hitTestable(), findsOneWidget);
      final createContext = tester.element(create);
      expect(MediaQuery.disableAnimationsOf(createContext), isFalse);
      final bounds = tester.getRect(create);
      await measure(
        'home-ambient-visible',
        () async {
          await wait(17000);
          expect(create.hitTestable(), findsOneWidget);
          expect(
            MediaQuery.disableAnimationsOf(tester.element(create)),
            isFalse,
          );
        },
        visibleScope: {
          'route': router().routeInformationProvider.value.uri.toString(),
          'homeCreateHitTestableAtStartAndEnd': true,
          'homeCreateBounds': [
            bounds.left,
            bounds.top,
            bounds.width,
            bounds.height,
          ],
          'homeScrollOffset': Scrollable.maybeOf(createContext)
              ?.position
              .pixels,
          'animationsDisabled': false,
          'nominalObservationMilliseconds': 17000,
          'screenRecordingActive': false,
          'baselineComparison': 'No equivalent before phase exists; standalone after-source observation.',
        },
      );
    }
    await clip('01-root-navigation', () async {
      await tab('Library');
      await shot('02-drafts');
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
