// Catalog/UI regression for the hosted creation-loop failure. These fixtures
// exercise real gallery laziness and action routing, not native media encoding.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:scribblesong/features/library/presentation/library_document_card.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

import 'support/memory_preferences.dart';
import 'support/export_gallery_navigation.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

class _CanceledSave implements ExportFileActions {
  final saved = <ExportArtifact>[];
  @override
  Future<void> open(ExportArtifact artifact) async =>
      throw StateError('Unexpected Open');
  @override
  Future<PublicExportCopy?> save(ExportArtifact artifact) async {
    saved.add(artifact);
    return null; // Honest canceled native-boundary fixture, never fake success.
  }
}

class _GalleryCatalog implements ExportLibrary {
  _GalleryCatalog(this.entries);
  final List<LibraryExport> entries;
  @override
  Future<ExportListing> list() async => ExportListing(entries);
  @override
  Future<void> record(
    ExportArtifact artifact,
    ProjectDocument document,
  ) async => throw StateError('Unexpected Record');
  @override
  Future<void> remove(String id) async => throw StateError('Unexpected Remove');
  @override
  Future<void> restore(String id) async =>
      throw StateError('Unexpected Restore');
  @override
  Future<void> rename(String id, String title) async =>
      throw StateError('Unexpected Rename');
}

void main() {
  testWidgets(
    'four export names remain reachable and WAV action targets WAV after scrolling to oldest MP4',
    (tester) async {
      // Match shipped type metrics instead of the widget runner's Ahem font.
      // Real I/O runs outside FakeAsync, as in the product capture harness.
      await tester.runAsync(() async {
        for (final family in ['NunitoSans', 'SpaceGrotesk']) {
          final loader = FontLoader(family);
          for (final file
              in Directory(
                'assets/fonts/$family',
              ).listSync().whereType<File>().where(
                (file) =>
                    file.path.endsWith('.ttf') || file.path.endsWith('.ttc'),
              )) {
            loader.addFont(file.readAsBytes().then(ByteData.sublistView));
          }
          await loader.load();
        }
      });
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('four-export-gallery-'),
      ))!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      final png = File('${root.path}/Paper hills.png');
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xffc4d3f2), BlendMode.src);
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(80, 100);
          try {
            await png.writeAsBytes(
              (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
                  .asUint8List(),
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      });
      final doc = ProjectDocument(
        id: 'saved-paper-hills',
        title: 'Paper hills',
      );
      final entries = <LibraryExport>[
        for (final (extension, mime) in [
          ('mid', 'audio/midi'),
          ('png', 'image/png'),
          ('wav', 'audio/wav'),
          ('mp4', 'video/mp4'),
        ])
          LibraryExport(
            id: 'saved.$extension',
            artifact: ExportArtifact(
              '${root.path}/Paper hills.$extension',
              mime,
              'Paper hills.$extension',
              doc.id,
              doc.revision,
            ),
            createdAt: DateTime.utc(2026, 10, 27),
            bytes: 123456,
            available: true,
            preview: doc,
          ),
      ];
      final actions = _CanceledSave();
      final repo = MemoryRepository()..documents[doc.id] = doc;
      final router = buildRouter();
      addTearDown(router.dispose);
      Future<void> mount(GoRouter route) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWith((ref) async => repo),
              preferencesStoreProvider.overrideWith(
                (ref) async => MemoryPreferencesStore(),
              ),
              audioEngineProvider.overrideWithValue(TestAudio()),
              exportLibraryProvider.overrideWith(
                (ref) async => _GalleryCatalog(entries),
              ),
              exportFileActionsProvider.overrideWithValue(actions),
            ],
            child: MaterialApp.router(
              theme: buildTheme(brightness: Brightness.dark),
              routerConfig: route,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
      }

      await mount(router);
      router.go('/exports');
      await tester.pumpAndSettle();
      expect(entries, hasLength(4));
      await revealExportGalleryItem(tester, find.text('Paper hills.wav'));
      expect(find.text('Paper hills.wav'), findsOneWidget);
      Future<void> expectOldestRowClipped() async {
        // The featured artwork intentionally pushes rows farther below the
        // opening viewport. Reproduce a cached-but-clipped oldest row with
        // actual scroll gestures instead of requiring all rows to mount at0.
        await revealExportGalleryItem(tester, find.text('Paper hills.mp4'));
        final list = find.byKey(const PageStorageKey('exports-scroll'));
        final viewport = tester.getRect(list);
        final oldest = find.ancestor(
          of: find.text('Paper hills.mp4'),
          matching: find.byType(LibraryDocumentCard),
        );
        expect(oldest, findsOneWidget);
        final movement = viewport.bottom - tester.getRect(oldest).bottom + 24;
        if (movement > 0) {
          final gesture = await tester.startGesture(viewport.center);
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.moveBy(Offset(0, movement));
          // Hold before release so fling momentum cannot skip the intended
          // cached-but-partially-clipped geometry.
          await tester.pump(const Duration(milliseconds: 400));
          await gesture.up();
          await tester.pumpAndSettle();
        }
        expect(oldest, findsOneWidget);
        expect(
          tester.getRect(oldest).bottom,
          greaterThan(viewport.bottom),
          reason: 'With real product fonts the cached oldest row still extends outside the visible gallery.',
        );
      }

      await expectOldestRowClipped();
      for (final extension in ['wav', 'png', 'mid', 'mp4']) {
        await revealExportGalleryItem(
          tester,
          find.text('Paper hills.$extension'),
        );
        final filename = find.text('Paper hills.$extension');
        expect(filename, findsOneWidget);
        final viewport = tester.getRect(
          find.byKey(const PageStorageKey('exports-scroll')),
        );
        expect(
          tester.getRect(filename).top,
          greaterThanOrEqualTo(viewport.top),
        );
        expect(
          tester.getRect(filename).bottom,
          lessThanOrEqualTo(viewport.bottom),
        );
      }
      final wavActions = find.byTooltip('Actions for Paper hills.wav');
      await revealExportGalleryItem(tester, wavActions);
      await tester.tap(wavActions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save a copy'));
      await tester.pumpAndSettle();
      expect(
        find.text('Save canceled. Your export is still in the library.'),
        findsOneWidget,
      );
      expect(actions.saved, hasLength(1));
      expect(actions.saved.single.name, 'Paper hills.wav');
      expect(actions.saved.single.mime, 'audio/wav');
      expect(actions.saved.single.path, '${root.path}/Paper hills.wav');
      expect(tester.takeException(), isNull);
      final firstContainer = ProviderScope.containerOf(
        tester.element(find.byType(ExportsPage)),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final freshRouter = buildRouter();
      addTearDown(freshRouter.dispose);
      await mount(freshRouter);
      freshRouter.go('/exports');
      await tester.pumpAndSettle();
      final freshContainer = ProviderScope.containerOf(
        tester.element(find.byType(ExportsPage)),
      );
      expect(identical(freshContainer, firstContainer), isFalse);
      final freshCatalog = await freshContainer.read(
        exportListingProvider.future,
      );
      expect(
        freshCatalog.entries.map((entry) => entry.artifact.name),
        containsAll([
          'Paper hills.mp4',
          'Paper hills.wav',
          'Paper hills.png',
          'Paper hills.mid',
        ]),
      );
      // A fresh scope/router starts at the featured artwork. Reproduce the
      // same clipped-row geometry with a new user scroll sequence.
      await expectOldestRowClipped();
      for (final extension in ['mp4', 'wav', 'png', 'mid']) {
        await revealExportGalleryItem(
          tester,
          find.text('Paper hills.$extension'),
        );
        final filename = find.text('Paper hills.$extension');
        expect(filename, findsOneWidget);
        final viewport = tester.getRect(
          find.byKey(const PageStorageKey('exports-scroll')),
        );
        expect(
          tester.getRect(filename).top,
          greaterThanOrEqualTo(viewport.top),
        );
        expect(
          tester.getRect(filename).bottom,
          lessThanOrEqualTo(viewport.bottom),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
