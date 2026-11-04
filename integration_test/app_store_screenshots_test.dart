import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/settings/data/file_preferences_store.dart';
import 'package:scribblesong/features/transport/data/ios_audio_engine.dart';
import 'package:scribblesong/main.dart' as app;

/// Real iOS UI and native screenshot capture, with original generated geometry.
/// Run on a dedicated simulator; no existing project or export is deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'capture six authentic App Store screens',
    (tester) async {
      Future<void> until(Future<bool> Function() condition) async {
        final end = DateTime.now().add(const Duration(seconds: 45));
        while (!await condition()) {
          if (DateTime.now().isAfter(end)) {
            fail(
              'Capture condition timed out. Visible text: '
              '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
      }

      Future<void> reveal(Finder target) async {
        expect(target, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
      }

      final support = await getApplicationSupportDirectory();
      final preferences = FilePreferencesStore(
        Directory('${support.path}/settings'),
      );
      final previousPreferences = (await preferences.load()).preferences;
      await preferences.save(
        previousPreferences.copyWith(
          tutorialCompleted: true,
          editorTipsCompleted: true,
          languageCode: 'en',
          darkTheme: false,
          previewVolume: .7,
        ),
      );
      final repository = FileProjectRepository(
        Directory('${support.path}/projects'),
      );
      final fixture = _originalRibbonDrawing();
      await repository.save(fixture);
      expect(
        (await repository.open(fixture.id)).document.encode(),
        fixture.encode(),
      );
      final documents = await getApplicationDocumentsDirectory();
      final output = Directory('${documents.path}/app-store-captures');
      await output.create(recursive: true);
      final captures = <Map<String, Object?>>[];
      final engine = IosAudioEngine();

      ProjectDocument current() =>
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;

      Future<void> capture(String name) async {
        await tester.pump();
        final bytes = await binding.takeScreenshot(name);
        expect(bytes.length, greaterThan(10000));
        await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
        final view = tester.view;
        captures.add({
          'name': name,
          'path': '${output.path}/$name.png',
          'pixelWidth': view.physicalSize.width.toInt(),
          'pixelHeight': view.physicalSize.height.toInt(),
          'devicePixelRatio': view.devicePixelRatio,
          'project': current().toJson(),
          'nativeTransport': {
            'playing': (await engine.status()).playing,
            'fraction': (await engine.status()).fraction,
          },
        });
        debugPrint('APP_STORE_CAPTURE ${output.path}/$name.png');
      }

      try {
        await app.main();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Library'));
        await tester.pumpAndSettle();
        await until(() async => find.text(fixture.title).evaluate().isNotEmpty);
        await tester.tap(find.text(fixture.title).first);
        await tester.pumpAndSettle();
        expect(current().strokes.length, fixture.strokes.length);

        // Save through the shipping UI, leave, and reopen the actual disk revision.
        await tester.tap(find.byTooltip('Save drawing'));
        await until(
          () async => find.text('Saved on this device').evaluate().isNotEmpty,
        );
        await tester.tap(find.byTooltip('Back to gallery'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(fixture.title).first);
        await tester.pumpAndSettle();
        expect(current().strokes.length, fixture.strokes.length);
        expect(
          (await repository.open(fixture.id)).document.strokes.length,
          fixture.strokes.length,
        );

        await tester.tap(find.byTooltip('Play'));
        await until(() async {
          final state = await engine.status();
          return state.playing && state.fraction > .2 && state.fraction < .75;
        });
        final firstFraction = (await engine.status()).fraction;
        await tester.pump(const Duration(milliseconds: 150));
        expect((await engine.status()).fraction, greaterThan(firstFraction));
        await capture('01-draw-it-hear-it');

        await tester.tap(find.byTooltip('Pause'));
        await tester.pumpAndSettle();
        await reveal(find.text('Glass stars'));
        expect(find.text('Glass stars').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Glass stars'));
        await tester.pumpAndSettle();
        await capture('02-find-your-sound');

        await reveal(find.byTooltip('Accompaniment'));
        await tester.tap(find.byTooltip('Accompaniment'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(SwitchListTile, 'Earth bass'),
          findsOneWidget,
        );
        expect(find.byType(Slider), findsNWidgets(3));
        await capture('03-give-it-a-groove');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        final scales = find.byWidgetPredicate(
          (widget) => widget is DropdownButton<MusicalScale>,
        );
        await reveal(scales);
        await tester.tap(scales);
        await tester.pumpAndSettle();
        await capture('04-change-the-mood');
        await tester.tapAt(
          Offset(
            8,
            tester.view.physicalSize.height / tester.view.devicePixelRatio - 12,
          ),
        );
        await tester.pumpAndSettle();

        await reveal(find.byTooltip('Drawing style'));
        await tester.tap(find.byTooltip('Drawing style'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pixel'));
        await tester.pumpAndSettle();
        expect(current().style, DrawingStyle.pixel);
        await tester.tap(find.byTooltip('Paper color'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<BackgroundKind>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Linear gradient').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(current().effectiveBackground.kind, BackgroundKind.linear);
        await capture('05-make-it-your-canvas');

        await tester.tap(find.byTooltip('Export loop'));
        await tester.pumpAndSettle();
        expect(find.text('Export MIDI'), findsOneWidget);
        expect(find.text('Export WAV'), findsOneWidget);
        expect(find.text('Export MP4'), findsOneWidget);
        expect(find.text('Export PNG'), findsOneWidget);
        await capture('06-let-your-ideas-travel');
        final manifest = {
          'platform': Platform.operatingSystem,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'fixtureProvenance': 'Original mathematical ribbon geometry authored for Doodimo. No reference-app assets.',
          'saveReopenVerified': true,
          'nativePlaybackAdvancementVerified': true,
          'physicalAudioAndRecipientDelivery':
              'not validated by simulator screenshots',
          'captures': captures,
        };
        binding.reportData!['appStoreManifest'] = manifest;
        await File('${output.path}/capture-manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifest),
          flush: true,
        );
      } finally {
        await engine.stop();
        await preferences.save(previousPreferences);
      }
    },
    skip: !Platform.isIOS,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

ProjectDocument _originalRibbonDrawing() {
  final strokes = <Stroke>[];
  const voices = [
    Instrument.keys,
    Instrument.bell,
    Instrument.mallet,
    Instrument.warmSynth,
    Instrument.pluck,
  ];
  for (var ribbon = 0; ribbon < voices.length; ribbon++) {
    strokes.add(
      Stroke(
        id: 'ribbon-$ribbon',
        instrument: voices[ribbon],
        width: .018,
        points: [
          for (var step = 0; step <= 150; step++)
            InkPoint(
              .1 + .8 * step / 150,
              .32 +
                  ribbon * .085 +
                  .14 * math.sin(step / 150 * math.pi * 2 - ribbon * .65),
              step * 10,
            ),
        ],
      ),
    );
  }
  for (var dot = 0; dot < 8; dot++) {
    final angle = dot * math.pi / 4;
    strokes.add(
      Stroke(
        id: 'star-$dot',
        instrument: Instrument.bell,
        width: .012,
        points: [
          InkPoint(.73 + math.cos(angle) * .055, .13 + math.sin(angle) * .044),
        ],
      ),
    );
  }
  return ProjectDocument(
    id: 'app-store-ribbons-${DateTime.now().microsecondsSinceEpoch}',
    title: 'Ribbon daydream',
    tempo: 108,
    root: RootKey.d,
    scale: MusicalScale.dorian,
    strokes: strokes,
    mix: const AccompanimentMix()
        .withLayer(
          AccompanimentLayer.bass,
          const LayerMix(enabled: true, level: .4),
        )
        .withLayer(
          AccompanimentLayer.drumKit,
          const LayerMix(enabled: true, level: .25),
        )
        .withLayer(
          AccompanimentLayer.arpeggio,
          const LayerMix(enabled: true, level: .35),
        ),
  );
}
