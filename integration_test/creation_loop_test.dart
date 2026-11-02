import 'support/functional_motion.dart';
import '../test/support/editor_controls.dart';
import '../test/support/export_gallery_navigation.dart';
import '../test/support/settings_navigation.dart';

import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/app/providers.dart';

import 'dart:io';
import 'dart:convert';

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

      Future<void> reveal(Finder target) async {
        await Scrollable.ensureVisible(tester.element(target), alignment: .2);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
      }

      Future<void> chooseExport(String extension) async {
        if (find.byKey(const ValueKey('export-ready')).evaluate().isNotEmpty) {
          await reveal(find.text('Choose another format'));
          await tester.tap(find.text('Choose another format'));
          await tester.pumpAndSettle();
        }
        final format = switch (extension) {
          '.mid' => 'midi',
          '.wav' => 'wav',
          '.mp4' => 'mp4',
          _ => 'png',
        };
        final intent = find.byKey(ValueKey('export-intent-$format'));
        await reveal(intent);
        await tester.tap(intent);
        await tester.pumpAndSettle();
      }

      final previousHitPolicy = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previousHitPolicy,
      );
      await prepareFunctionalMotion();
      await app.main();
      await tester.pumpAndSettle();
      if (find.text('Start creating').evaluate().isNotEmpty) {
        await tester.tap(find.text('Start creating'));
        await until(
          () async => find
              .byKey(const PageStorageKey('home-scroll'))
              .evaluate()
              .isNotEmpty,
        );
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
      await tester.scrollUntilVisible(
        find.text('Paper hills'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('home-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await reveal(find.text('Paper hills'));
      await tester.tap(find.text('Paper hills').hitTestable());
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
      await openEditorTool(tester, 'paper');
      await tester.pumpAndSettle();
      await reveal(find.byTooltip('Lilac paper'));
      await tester.tap(find.byTooltip('Lilac paper'));
      await reveal(find.byType(Slider));
      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DrawingCanvas>(find.byType(DrawingCanvas))
            .document
            .effectiveBackground
            .colors
            .first,
        0xfff3eef9,
      );
      await openEditorTool(tester, 'style');
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
      await chooseExport('.mp4');
      final resolution = find.byKey(const ValueKey('video-width-640'));
      await reveal(resolution);
      await tester.tap(resolution);
      await tester.pumpAndSettle();
      Future<File> export(String label, String extension) async {
        await chooseExport(extension);
        final root = await getApplicationDocumentsDirectory();
        final exportDirectory = Directory('${root.path}/exports');
        final before = await exportDirectory.exists()
            ? await exportDirectory.list().map((f) => f.path).toSet()
            : <String>{};
        await reveal(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
        await until(
          () async =>
              find.text('Export ready on this device.').evaluate().isNotEmpty,
          seconds: 240,
        );
        final files = await Directory('${root.path}/exports')
            .list()
            .where(
              (f) =>
                  f is File &&
                  f.path.endsWith(extension) &&
                  !before.contains(f.path),
            )
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
      final png = await export('Export PNG', '.png');
      await png.copy('${cache.path}/ui-export-image.png');
      final midi = await export('Export MIDI', '.mid');
      await midi.copy('${cache.path}/ui-export-notes.mid');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to gallery'));
      // Real disk saves can finish after pumpAndSettle sees no scheduled frame.
      await until(() async => find.text('Library').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exports'));
      await until(() async => find.byType(ExportsPage).evaluate().isNotEmpty);
      final initialCatalogContainer = ProviderScope.containerOf(
        tester.element(find.byType(ExportsPage)),
      );
      final initialCatalog = await initialCatalogContainer.read(
        exportListingProvider.future,
      );
      expect(initialCatalog.entries.length, 4);
      expect(
        initialCatalog.entries.map((entry) => entry.artifact.name),
        containsAll([
          'Paper hills.mp4',
          'Paper hills.wav',
          'Paper hills.png',
          'Paper hills.mid',
        ]),
      );
      await tester.pumpAndSettle();
      for (final extension in ['wav', 'png', 'mid', 'mp4']) {
        await revealExportGalleryItem(
          tester,
          find.text('Paper hills.$extension'),
        );
        expect(find.text('Paper hills.$extension'), findsOneWidget);
      }
      final wavActions = find.byTooltip('Actions for Paper hills.wav');
      await revealExportGalleryItem(tester, wavActions);
      await tester.tap(wavActions);
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
      expect(catalog.entries.length, 4);
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
      expect(reopened.effectiveBackground.colors.first, 0xfff3eef9);
      expect(reopened.effectiveBackground.opacity, closeTo(.5, .01));
      expect(reopened.style, DrawingStyle.pixel);
      expect(reopened.strokes.length, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await prepareFunctionalMotion();
      await app.main();
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
      await until(() async => find.byType(ExportsPage).evaluate().isNotEmpty);
      final persistedCatalogContainer = ProviderScope.containerOf(
        tester.element(find.byType(ExportsPage)),
      );
      final persistedCatalog = await persistedCatalogContainer.read(
        exportListingProvider.future,
      );
      expect(persistedCatalog.entries.length, 4);
      expect(
        persistedCatalog.entries.map((entry) => entry.artifact.name),
        containsAll([
          'Paper hills.mp4',
          'Paper hills.wav',
          'Paper hills.png',
          'Paper hills.mid',
        ]),
      );
      expect(
        persistedCatalog.entries.every(
          (entry) =>
              entry.available &&
              !entry.legacy &&
              entry.artifact.projectId == snapshot.id,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      for (final extension in ['mp4', 'wav', 'png', 'mid']) {
        await revealExportGalleryItem(
          tester,
          find.text('Paper hills.$extension'),
        );
        expect(find.text('Paper hills.$extension'), findsOneWidget);
      }
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Three streams'),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('home-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Three streams')),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      expect(find.text('Three streams').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Three streams').hitTestable());
      await until(() async => find.byType(DrawingCanvas).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      ProjectDocument expandedDoc() =>
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;
      expect(expandedDoc().mix.isActive, isTrue);
      await openEditorMusic(tester);
      await reveal(find.byType(DropdownButton<RootKey>));
      await tester.tap(find.byType(DropdownButton<RootKey>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('F♯').last);
      await tester.pumpAndSettle();
      await reveal(find.byType(DropdownButton<MusicalScale>));
      await tester.tap(find.byType(DropdownButton<MusicalScale>));
      await tester.pumpAndSettle();
      await reveal(find.text('Lydian').last);
      await tester.tap(find.text('Lydian').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await openEditorTool(tester, 'mix');
      await reveal(find.text('Arpeggio'));
      await tester.tap(find.text('Arpeggio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await openEditorTool(tester, 'paper');
      await tester.pumpAndSettle();
      await reveal(find.byKey(const ValueKey('background-mode-gradient')));
      await tester.tap(find.byKey(const ValueKey('background-mode-gradient')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(expandedDoc().root, RootKey.fSharp);
      expect(expandedDoc().scale, MusicalScale.lydian);
      expect(expandedDoc().effectiveBackground.kind, BackgroundKind.linear);
      await reveal(find.byTooltip('Play'));
      await tester.tap(find.byTooltip('Play'));
      await until(
        () async =>
            (await audio.status()).playing &&
            (await audio.status()).fraction > .05,
      );
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      final expanded = expandedDoc();
      await File('${cache.path}/expanded-project.json')
          .writeAsString(expanded.encode());
      await tester.tap(find.byTooltip('Save drawing'));
      await until(
        () async => find.text('Saved on this device').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('Export loop'));
      await tester.pumpAndSettle();
      await chooseExport('.mp4');
      // A host driver presses actual HOME only after native HD60 progress.
      // This tests OS delivery and real cancellation, not a mocked lifecycle.
      final lifecycleMarker = File('${cache.path}/qa-hd-background.json');
      if (await lifecycleMarker.exists()) await lifecycleMarker.delete();
      final lifecycleNonce = newId();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('video-width-1080')))
            .properties
            .selected,
        isTrue,
      );
      final fpsSelector = find.byKey(const ValueKey('video-fps-60'));
      await reveal(fpsSelector);
      await tester.tap(fpsSelector);
      await tester.pumpAndSettle();
      final ownedExports = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/exports',
      );
      final beforeCancellation = await ownedExports
          .list()
          .map((f) => f.path)
          .toSet();
      await reveal(find.text('Export MP4'));
      await tester.tap(find.text('Export MP4'));
      await tester.pump();
      await until(
        () async => tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .any((indicator) => (indicator.value ?? 0) > .05),
      );
      await lifecycleMarker.writeAsString(
        jsonEncode({
          'phase': 'ready',
          'nonce': lifecycleNonce,
          'width': 1080,
          'fps': 60,
        }),
        flush: true,
      );
      await until(
        () async => find
            .text('Export canceled. Your drawing is safe.')
            .evaluate()
            .isNotEmpty,
      );
      expect(
        await ownedExports.list().map((f) => f.path).toSet(),
        beforeCancellation,
      );
      expect(expandedDoc().encode(), expanded.encode());
      expect(find.text('Export ready on this device.'), findsNothing);
      await lifecycleMarker.writeAsString(
        jsonEncode({
          'phase': 'verified',
          'nonce': lifecycleNonce,
          'width': 1080,
          'fps': 60,
          'noPublishedArtifact': true,
          'noTemporaryFiles': true,
          'documentUnchanged': true,
        }),
        flush: true,
      );
      final standardFps = find.byKey(const ValueKey('video-fps-30'));
      await reveal(standardFps);
      await tester.tap(standardFps);
      await tester.pumpAndSettle();
      final expandedWidth = find.byKey(const ValueKey('video-width-640'));
      await reveal(expandedWidth);
      await tester.tap(expandedWidth);
      await tester.pumpAndSettle();
      for (final item in [
        ('Export MP4', '.mp4', 'video.mp4'),
        ('Export WAV', '.wav', 'audio.wav'),
        ('Export MIDI', '.mid', 'notes.mid'),
        ('Export PNG', '.png', 'image.png'),
      ]) {
        final file = await export(item.$1, item.$2);
        await file.copy('${cache.path}/expanded-${item.$3}');
      }
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to gallery'));
      await until(() async => find.text('Home').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.text('Home')),
      );
      final repository = await container.read(repositoryProvider.future);
      final recovered = (await repository.open(expanded.id)).document;
      expect(recovered.root, expanded.root);
      expect(recovered.mix.toJson(), expanded.mix.toJson());
      expect(
        recovered.effectiveBackground.toJson(),
        expanded.effectiveBackground.toJson(),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await openSettingsLanguage(tester);
      await tester.scrollUntilVisible(find.text('日本語'), 200);
      await reveal(find.text('日本語'));
      await tester.tap(find.text('日本語').hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('language-ja')))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Apply'));
      await until(
        () async =>
            container.read(settingsProvider).preferences.languageCode == 'ja',
      );
      await tester.pumpAndSettle();
      await revealSettingsLanguage(tester);
      expect(find.text('日本語'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
