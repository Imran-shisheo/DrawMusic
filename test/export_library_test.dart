import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/export/data/file_export_adapter.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:share_plus/share_plus.dart';

import 'export_test.dart' show sample;
import 'support/memory_preferences.dart';
import 'support/export_gallery_navigation.dart';

class RecordingFileActions implements ExportFileActions {
  final opened = <ExportArtifact>[];
  final saved = <ExportArtifact>[];
  bool cancelSave = false;
  @override
  Future<void> open(ExportArtifact artifact) async {
    opened.add(artifact);
  }

  @override
  Future<PublicExportCopy?> save(ExportArtifact artifact) async {
    saved.add(artifact);
    return cancelSave
        ? null
        : PublicExportCopy(
            'content://test/1',
            'Downloads/DrawMusic',
            await File(artifact.path).length(),
          );
  }
}

void main() {
  test('export display names preserve Unicode and remove path separators', () {
    expect(readableExportName('雨の曲', 'wav'), '雨の曲.wav');
    expect(readableExportName('مرحبا', 'mp4'), 'مرحبا.mp4');
    expect(readableExportName('a/b\\c', 'mid'), 'a_b_c.mid');
  });

  test('real exported files retain snapshot details across restart and rename without changing bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drawmusic-library-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final document = sample();
    final artifact = await FileExportAdapter(directory)
        .export(document, ExportFormat.wav, ExportCancellation());
    final original = await File(artifact.path).readAsBytes();
    final library = FileExportLibrary(directory);
    await library.record(artifact, document);
    var listing = await FileExportLibrary(directory).list();
    final entry = listing.entries.single;
    expect(entry.available, isTrue);
    expect(entry.preview!.id, document.id);
    expect(entry.preview!.strokes.length, document.strokes.length);
    expect(entry.artifact.projectId, document.id);
    expect(entry.artifact.revision, document.revision);
    await library.rename(entry.id, '  My loop  ');
    listing = await FileExportLibrary(directory).list();
    expect(listing.entries.single.artifact.name, 'My loop.wav');
    expect(await File(artifact.path).readAsBytes(), original);
    await expectLater(
      library.rename(entry.id, '../escape'),
      throwsFormatException,
    );
    await expectLater(library.remove('../escape.wav'), throwsFormatException);
    expect(await File(artifact.path).readAsBytes(), original);
  });
  test('older files remain discoverable, corrupt details are preserved and temporary files stay hidden', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drawmusic-library-legacy-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final artifact = await FileExportAdapter(directory)
        .export(sample(), ExportFormat.midi, ExportCancellation());
    await File('${directory.path}/unfinished.wav.tmp')
        .writeAsString('not finished');
    final library = FileExportLibrary(directory);
    var listing = await library.list();
    expect(listing.entries.single.legacy, isTrue);
    expect(listing.entries.single.available, isTrue);
    final id = listing.entries.single.id;
    final details = File('${artifact.path}.json');
    await details.writeAsString('broken metadata');
    listing = await library.list();
    expect(listing.detailFailures, 1);
    expect(listing.entries.single.available, isTrue);
    await library.rename(id, 'Recovered music');
    final preserved = await directory
        .list()
        .where((f) => f.path.contains('.preserved-'))
        .toList();
    expect(await File(preserved.single.path).readAsString(), 'broken metadata');
    expect(
      (await library.list()).entries.single.artifact.name,
      'Recovered music.mid',
    );
  });
  test('missing files keep source details and deletion Undo survives repository recreation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drawmusic-library-delete-',
    );
    addTearDown(() => directory.delete(recursive: true));
    var now = DateTime.utc(2026, 10, 24);
    FileExportLibrary library() =>
        FileExportLibrary(directory, clock: () => now);
    final document = sample();
    final artifact = await FileExportAdapter(directory)
        .export(document, ExportFormat.wav, ExportCancellation());
    await library().record(artifact, document);
    final id = (await library().list()).entries.single.id;
    await library().remove(id);
    expect((await library().list()).entries, isEmpty);
    now = now.add(const Duration(seconds: 4));
    await library().restore(id);
    expect((await library().list()).entries.single.available, isTrue);
    await File(artifact.path).delete();
    var missing = (await library().list()).entries.single;
    expect(missing.available, isFalse);
    expect(missing.artifact.projectId, document.id);
    // A missing file can still be removed, without deleting its editable source.
    await library().remove(id);
    now = now.add(const Duration(seconds: 8));
    expect((await library().list()).entries, isEmpty);
    expect(await File('${artifact.path}.json').exists(), isFalse);
  });
  test(
    'expired deleted export is purged while another export survives',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'drawmusic-library-purge-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var now = DateTime.utc(2026, 10, 24);
      final library = FileExportLibrary(directory, clock: () => now);
      final first = await FileExportAdapter(directory)
          .export(sample(), ExportFormat.midi, ExportCancellation());
      final second = await FileExportAdapter(directory)
          .export(sample(), ExportFormat.wav, ExportCancellation());
      await library.record(first, sample());
      await library.record(second, sample());
      final firstId = File(first.path).uri.pathSegments.last;
      await library.remove(firstId);
      now = now.add(const Duration(seconds: 8));
      final listing = await library.list();
      expect(listing.entries.single.artifact.mime, 'audio/wav');
      expect(await File(first.path).exists(), isFalse);
      expect(await File(second.path).exists(), isTrue);
    },
  );

  testWidgets(
    'Library opens saved exports, shares the renamed file, saves and undoes removal',
    (tester) async {
      final setup = await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'drawmusic-library-ui-',
        );
        final artifact = await FileExportAdapter(directory)
            .export(sample(), ExportFormat.midi, ExportCancellation());
        final library = FileExportLibrary(directory);
        await library.record(artifact, sample());
        return (directory, artifact, library);
      });
      final (directory, artifact, library) = setup!;
      addTearDown(
        () => tester.runAsync(() => directory.delete(recursive: true)),
      );
      final actions = RecordingFileActions();
      final shared = <ExportArtifact>[];
      var shareStatus = ShareResultStatus.dismissed;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith((ref) async => ProjectListing([], [])),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            exportLibraryProvider.overrideWith((ref) async => library),
            exportFileActionsProvider.overrideWithValue(actions),
            shareExportProvider.overrideWithValue((artifact, origin) async {
              shared.add(artifact);
              return shareStatus;
            }),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exports'));
      await tester.pump();
      // Real filesystem listing requires real asynchronous progress beyond animation settlement.
      Future<void> ready(String text) async {
        for (var i = 0; i < 100 && find.text(text).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await ready(artifact.name);
      await revealExportGalleryItem(tester, find.text(artifact.name));
      await tester.tap(find.text(artifact.name));
      await tester.pumpAndSettle();
      expect(actions.opened.single.path, artifact.path);
      Future<void> menu(String name, String action) async {
        await revealExportGalleryItem(
          tester,
          find.byTooltip('Actions for $name'),
        );
        await tester.tap(find.byTooltip('Actions for $name'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await menu(artifact.name, 'Rename');
      await tester.enterText(find.byType(TextField), 'Renamed loop');
      await tester.tap(find.text('Apply'));
      await ready('Renamed loop.mid');
      await menu('Renamed loop.mid', 'Share');
      expect(shared.single.name, 'Renamed loop.mid');
      expect(
        find.text('Share sheet dismissed. Export is still saved.'),
        findsOneWidget,
      );
      for (final (status, message) in [
        (
          ShareResultStatus.unavailable,
          'Sharing unavailable. The library file is preserved.',
        ),
        (
          ShareResultStatus.success,
          'Share sheet closed. Delivery is handled by the selected app.',
        ),
      ]) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        shareStatus = status;
        await menu('Renamed loop.mid', 'Share');
        expect(find.text(message), findsOneWidget);
        expect(shared.last.name, 'Renamed loop.mid');
        expect(
          await tester.runAsync(() => File(artifact.path).exists()),
          isTrue,
        );
      }
      await menu('Renamed loop.mid', 'Save a copy');
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(actions.saved.single.name, 'Renamed loop.mid');
      await menu('Renamed loop.mid', 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await ready('Undo');
      await tester.tap(find.text('Undo'));
      await ready('Renamed loop.mid');
      expect(await tester.runAsync(() => File(artifact.path).exists()), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
