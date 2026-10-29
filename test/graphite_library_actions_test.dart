import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:scribblesong/l10n/strings.dart';

class _Catalog implements ExportLibrary {
  _Catalog(this.entries);
  List<LibraryExport> entries;
  @override
  Future<ExportListing> list() async => ExportListing(entries);
  @override
  Future<void> record(
    ExportArtifact artifact,
    ProjectDocument document,
  ) async => throw StateError('Unexpected record');
  @override
  Future<void> remove(String id) async => throw StateError('Unexpected remove');
  @override
  Future<void> rename(String id, String title) async =>
      throw StateError('Unexpected rename');
  @override
  Future<void> restore(String id) async =>
      throw StateError('Unexpected restore');
}

class _Files implements ExportFileActions {
  final saved = <ExportArtifact>[];
  @override
  Future<void> open(ExportArtifact artifact) async =>
      throw StateError('Unexpected open');
  @override
  Future<PublicExportCopy?> save(ExportArtifact artifact) async {
    saved.add(artifact);
    return null; // An actual canceled-boundary result, not invented delivery.
  }
}

LibraryExport _entry(String id, {bool available = true}) => LibraryExport(
  id: id,
  artifact: ExportArtifact('/owned/$id', 'audio/wav', id, 'source-$id', 7),
  createdAt: DateTime.utc(2026, 10, 29),
  bytes: 1000,
  available: available,
  preview: ProjectDocument(
    id: 'frozen-${id.replaceAll('.', '-')}',
    title: 'Frozen $id',
    revision: 7,
  ),
);

void main() {
  testWidgets(
    'featured real artifact actions retarget after catalog change and disable for missing file',
    (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = _entry('first.wav');
      final second = _entry('second.wav');
      final catalog = _Catalog([first, second]);
      final files = _Files();
      final shared = <ExportArtifact>[];
      final container = ProviderContainer(
        overrides: [
          exportLibraryProvider.overrideWith((ref) async => catalog),
          exportFileActionsProvider.overrideWithValue(files),
          shareExportProvider.overrideWithValue((artifact, origin) async {
            shared.add(artifact);
            return ShareResultStatus.dismissed;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(brightness: Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ExportsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> press(String key) async {
        final control = find.byKey(ValueKey(key));
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expect(control.hitTestable(), findsOneWidget);
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

      String caption() => tester
          .widget<RichText>(
            find.byKey(const ValueKey('export-feature-caption')),
          )
          .text
          .toPlainText();
      expect(caption(), 'first.wav');
      await press('export-feature-share-first.wav');
      expect(shared, [first.artifact]);
      expect(
        find.text('Share sheet dismissed. Export is still saved.'),
        findsOneWidget,
      );
      await press('export-feature-save-first.wav');
      expect(files.saved, [first.artifact]);
      expect(
        find.text('Save canceled. Your export is still in the library.'),
        findsOneWidget,
      );

      catalog.entries = [second];
      container.invalidate(exportListingProvider);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('export-feature-share-first.wav')),
        findsNothing,
      );
      expect(caption(), 'second.wav');
      await press('export-feature-share-second.wav');
      expect(shared, [first.artifact, second.artifact]);
      expect(shared.last.projectId, 'source-second.wav');
      expect(shared.last.revision, 7);

      catalog.entries = [_entry('second.wav', available: false)];
      container.invalidate(exportListingProvider);
      await tester.pumpAndSettle();
      final share = tester.widget<FilledButton>(
        find.byKey(const ValueKey('export-feature-share-second.wav')),
      );
      final save = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('export-feature-save-second.wav')),
      );
      expect(share.onPressed, isNull);
      expect(save.onPressed, isNull);
      expect(shared, hasLength(2));
      expect(files.saved, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
