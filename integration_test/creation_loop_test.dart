import 'package:scribblesong/creative_document/document.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/main.dart' as app;
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/transport/data/android_audio_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android creation, boundary playback, save/reopen and real exports',
    (tester) async {
      Future<void> until(
        Future<bool> Function() condition, {
        int seconds = 120,
      }) async {
        final deadline = DateTime.now().add(Duration(seconds: seconds));
        while (!await condition()) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              'Timed out waiting for the Android creation/export flow. Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data ?? text.textSpan?.toPlainText() ?? '').join(' | ')}',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump();
      }

      app.main();
      await tester.pumpAndSettle();
      if (find.text('Start creating').evaluate().isNotEmpty) {
        await tester.tap(find.text('Start creating'));
        await until(() async => find.text('Paper hills').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(-600, 0));
      final preferences = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );
      await until(
        () async =>
            preferences.read(settingsProvider).preferences.previewVolume == 0,
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paper hills'));
      await tester.pumpAndSettle();
      if (find.text('Skip tips').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip tips'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('drawing-canvas')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play'));
      final audio = AndroidAudioEngine();
      await until(
        () async =>
            (await audio.status()).playing &&
            (await audio.status()).fraction > 0,
      );
      await tester.tap(find.byTooltip('Faster'));
      await tester.pump();
      final expected = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .document;
      expect(expected.tempo, 121);
      await until(
        () async => (await audio.status()).revision == expected.revision,
      );
      expect((await audio.status()).playing, isTrue);
      expect((await audio.status()).tempo, 121);
      await tester.tap(find.byTooltip('Replay'));
      await tester.tap(find.byTooltip('Faster'));
      await tester.pump();
      final replayed = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .document;
      expect(replayed.tempo, 122);
      await until(
        () async =>
            (await audio.status()).playing &&
            (await audio.status()).revision == replayed.revision &&
            (await audio.status()).tempo == 122,
      );

      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paper color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Lilac paper'));
      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DrawingCanvas>(find.byType(DrawingCanvas))
            .document
            .background,
        0x80f3eef9,
      );
      await tester.tap(find.byTooltip('Drawing style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pixel'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document.style,
        DrawingStyle.pixel,
      );
      await tester.tap(find.byTooltip('Save drawing'));
      await until(
        () async => find.text('Saved on this device').evaluate().isNotEmpty,
      );
      final snapshot = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .document;
      expect(snapshot.strokes.length, 2);
      final cache = await getTemporaryDirectory();
      await File('${cache.path}/ui-project.json')
          .writeAsString(snapshot.encode());
      await tester.tap(find.byTooltip('Export loop'));
      await tester.pumpAndSettle();
      final resolution = find.byType(DropdownButton<int>);
      await tester.ensureVisible(resolution);
      await tester.tap(resolution);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact · 640 × 800 · 30 fps').last);
      await tester.pumpAndSettle();
      Future<File> export(String label, String extension) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
        await until(
          () async =>
              find.text('Export ready on this device.').evaluate().isNotEmpty,
          seconds: 240,
        );
        final root = await getApplicationDocumentsDirectory();
        final files = await Directory('${root.path}/exports')
            .list()
            .where((f) => f is File && f.path.endsWith(extension))
            .cast<File>()
            .toList();
        expect(files.length, 1);
        expect(await files.single.length(), greaterThan(0));
        return files.single;
      }

      final video = await export('Export MP4', '.mp4');
      await video.copy('${cache.path}/ui-export-video.mp4');
      final wav = await export('Export WAV', '.wav');
      await wav.copy('${cache.path}/ui-export-audio.wav');
      final midi = await export('Export MIDI', '.mid');
      await midi.copy('${cache.path}/ui-export-notes.mid');
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to gallery'));
      // Real disk saves can finish after pumpAndSettle sees no scheduled frame.
      await until(() async => find.text('Library').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exports'));
      await until(
        () async => find.text('Paper hills.wav').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.text('Paper hills.mp4'), findsOneWidget);
      expect(find.text('Paper hills.mid'), findsOneWidget);
      await tester.tap(find.byTooltip('Actions for Paper hills.wav'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save a copy'));
      final savedCopy = find.text(
        'Saved Paper hills.wav to Downloads/DrawMusic.',
      );
      await until(
        () async =>
            savedCopy.evaluate().isNotEmpty ||
            find
                .text(
                  'Could not save a public copy. Check storage and retry. The library file is preserved.',
                )
                .evaluate()
                .isNotEmpty,
      );
      expect(
        savedCopy,
        findsOneWidget,
        reason: 'The public Save action must complete through the registered native channel.',
      );
      final catalogContainer = ProviderScope.containerOf(
        tester.element(find.byType(ExportsPage)),
      );
      final catalog = await catalogContainer.read(exportListingProvider.future);
      expect(catalog.entries.length, 3);
      expect(
        catalog.entries.every(
          (entry) =>
              entry.available &&
              !entry.legacy &&
              entry.artifact.projectId == snapshot.id,
        ),
        isTrue,
      );
      await File('${catalog.entries.first.artifact.path}.json')
          .copy('${cache.path}/ui-export-metadata.json');
      await tester.tap(find.text('Drafts'));
      await until(() async => find.text('Paper hills').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paper hills'));
      await until(() async => find.byType(DrawingCanvas).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      final reopened = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .document;
      expect(reopened.id, snapshot.id);
      expect(reopened.tempo, 122);
      expect(reopened.background, 0x80f3eef9);
      expect(reopened.style, DrawingStyle.pixel);
      expect(reopened.strokes.length, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      app.main();
      await until(() async => find.text('Home').evaluate().isNotEmpty);
      expect(find.text('Start creating'), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final restarted = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );
      await until(() async => !restarted.read(settingsProvider).loading);
      expect(restarted.read(settingsProvider).preferences.previewVolume, 0);
      expect(
        restarted.read(settingsProvider).preferences.editorTipsCompleted,
        isTrue,
      );
      expect(
        restarted.read(settingsProvider).preferences.tutorialCompleted,
        isTrue,
      );
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exports'));
      await until(
        () async => find.text('Paper hills.mp4').evaluate().isNotEmpty,
      );
      expect(find.text('Paper hills.wav'), findsOneWidget);
      expect(find.text('Paper hills.mid'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
