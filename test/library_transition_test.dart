import 'support/root_navigation.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/creative_panel.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/library/presentation/library_branch_frame.dart';
import 'package:scribblesong/features/library/presentation/library_tabs.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

Future<void> openApp(
  WidgetTester tester, {
  double scale = 1,
  Size size = const Size(411, 850),
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final repo = MemoryRepository();
  for (var i = 0; i < 30; i++) {
    await repo.save(ProjectDocument(id: 'draft-$i', title: 'Drawing $i'));
  }
  final app = ProviderScope(
    overrides: [
      preferencesStoreProvider.overrideWith(
        (ref) async =>
            MemoryPreferencesStore(const UserPreferences(languageCode: 'fr')),
      ),
      repositoryProvider.overrideWith((ref) async => repo),
      libraryProvider.overrideWith(
        (ref) async => ProjectListing(repo.documents.values.toList(), []),
      ),
      exportListingProvider.overrideWith(
        (ref) async => ExportListing([
          for (var i = 0; i < 30; i++)
            LibraryExport(
              id: 'export-$i.png',
              artifact: ExportArtifact(
                '/fixture/$i.png',
                'image/png',
                'Image $i.png',
                'draft-$i',
                0,
              ),
              createdAt: DateTime.utc(2026, 10, 28),
              bytes: 100,
              available: false,
            ),
        ]),
      ),
      audioEngineProvider.overrideWithValue(TestAudio()),
    ],
    child: const ScribbleSongApp(),
  );
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tapRootNavigation(tester, 'nav-library');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder tab(int index) => find
    .descendant(of: find.byType(LibraryTabs), matching: find.byType(InkWell))
    .at(index);
ScrollableState scroll(WidgetTester tester, String key) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(PageStorageKey(key), skipOffstage: false),
        matching: find.byType(Scrollable, skipOffstage: false),
        skipOffstage: false,
      ),
    );

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'library selector and independent scroll survive rapid reversal at scale $scale',
      (tester) async {
        await openApp(tester, scale: scale);
        expect(find.byType(LibraryTabs), findsOneWidget);
        final selector = tester.element(find.byType(LibraryTabs));
        final frame = tester.state(find.byType(LibraryBranchFrame));
        final rect = tester.getRect(find.byType(LibraryTabs));
        await tester.drag(
          find.byKey(const PageStorageKey('drafts-scroll')),
          const Offset(0, -550),
        );
        await tester.pump(const Duration(milliseconds: 800));
        final draftOffset = scroll(tester, 'drafts-scroll').position.pixels;
        expect(draftOffset, greaterThan(0));
        await tester.tap(tab(1));
        await tester.pump();
        expect(tester.element(find.byType(LibraryTabs)), same(selector));
        expect(tester.getRect(find.byType(LibraryTabs)), rect);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(
          find.byKey(const PageStorageKey('exports-scroll')),
          const Offset(0, -350),
        );
        await tester.pump(const Duration(milliseconds: 800));
        final exportOffset = scroll(tester, 'exports-scroll').position.pixels;
        expect(exportOffset, greaterThan(0));
        for (var i = 0; i < 8; i++) {
          await tester.tap(tab(i.isEven ? 0 : 1));
          await tester.pump();
          expect(tester.getRect(find.byType(LibraryTabs)), rect);
          expect(tester.element(find.byType(LibraryTabs)), same(selector));
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(scroll(tester, 'drafts-scroll').position.pixels, draftOffset);
        expect(scroll(tester, 'exports-scroll').position.pixels, exportOffset);
        await tapRootNavigation(tester, 'nav-settings');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tapRootNavigation(tester, 'nav-library');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.state(find.byType(LibraryBranchFrame)), same(frame));
        expect(scroll(tester, 'exports-scroll').position.pixels, exportOffset);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    '320x640 200 percent navigation frees gallery and preserves reachable draft actions and both scrolls',
    (tester) async {
      await tester.runAsync(() async {
        final loader = FontLoader('NunitoSans');
        for (final file in Directory(
          'assets/fonts/NunitoSans',
        ).listSync().whereType<File>()) {
          if (file.path.endsWith('.ttf')) {
            loader.addFont(file.readAsBytes().then(ByteData.sublistView));
          }
        }
        await loader.load();
      });
      await openApp(tester, scale: 2, size: const Size(320, 640));
      final strings = AppLocalizations.of(
        tester.element(find.byType(LibraryTabs)),
      )!;
      final summary = find.byKey(const ValueKey('nav-summary'));
      expect(
        tester.getSize(find.byKey(const ValueKey('root-new-drawing'))),
        const Size(48, 48),
      );
      expect(tester.getRect(summary).height, lessThanOrEqualTo(64));
      final more = find.byTooltip(strings.manageDrawing('Drawing 20'));
      await tester.scrollUntilVisible(
        more,
        250,
        maxScrolls: 80,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey('drafts-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(more.hitTestable(), findsOneWidget);
      final draftOffset = scroll(tester, 'drafts-scroll').position.pixels;
      await tester.tap(more);
      await tester.pumpAndSettle();
      for (final text in [
        strings.rename,
        strings.duplicate,
        strings.exportShare,
        strings.delete,
      ]) {
        await tester.ensureVisible(find.text(text));
        await tester.pump();
        expect(find.text(text).hitTestable(), findsOneWidget);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(tab(1));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey('exports-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final exportOffset = scroll(tester, 'exports-scroll').position.pixels;
      expect(exportOffset, greaterThan(0));
      // Two taps in the same frame must produce one panel and Back returns to
      // the same retained export branch with its independent scroll untouched.
      final point = tester.getCenter(summary);
      await tester.tapAt(point);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-menu')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-menu')), findsNothing);
      expect(scroll(tester, 'exports-scroll').position.pixels, exportOffset);
      await tapRootNavigation(tester, 'nav-settings');
      await tester.pumpAndSettle();
      await tapRootNavigation(tester, 'nav-library');
      await tester.pumpAndSettle();
      expect(scroll(tester, 'exports-scroll').position.pixels, exportOffset);
      await tester.tap(tab(0));
      await tester.pumpAndSettle();
      expect(scroll(tester, 'drafts-scroll').position.pixels, draftOffset);
      expect(more.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 640.0]) {
    testWidgets(
      'RTL large-text selector keeps whole words and reverses continuously at width $width',
      (tester) async {
        await tester.runAsync(() async {
          final loader = FontLoader('NunitoSans');
          for (final file in Directory(
            'assets/fonts/NunitoSans',
          ).listSync().whereType<File>()) {
            if (file.path.endsWith('.ttf')) {
              loader.addFont(file.readAsBytes().then(ByteData.sublistView));
            }
          }
          await loader.load();
        });
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        var exports = false;
        late StateSetter change;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: StatefulBuilder(
                      builder: (context, update) {
                        change = update;
                        return LibraryTabs(exports: exports);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final label in ['Brouillons', 'Exports']) {
          final text = find.text(label);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          );
          expect(
            boxes.map((box) => box.top).toSet(),
            hasLength(1),
            reason: 'The complete translated word must fit one line without text shrinking.',
          );
          expect(MediaQuery.textScalerOf(tester.element(text)).scale(14), 28);
        }
        final bounds = tester.getRect(find.byType(LibraryTabs));
        final indicator = find.descendant(
          of: find.byType(AnimatedAlign),
          matching: find.byType(Container),
        );
        final initial = tester.getTopLeft(indicator);
        change(() => exports = true);
        await tester.pump();
        expect(tester.getRect(find.byType(LibraryTabs)), bounds);
        await tester.pump(const Duration(milliseconds: 80));
        final intermediate = tester.getTopLeft(indicator);
        if (width == 320) {
          expect(intermediate.dy, greaterThan(initial.dy));
          expect(intermediate.dx, initial.dx);
        } else {
          expect(intermediate.dx, lessThan(initial.dx));
          expect(intermediate.dy, initial.dy);
        }
        change(() => exports = false);
        await tester.pump();
        expect(
          (tester.getTopLeft(indicator) - intermediate).distance,
          lessThan(.00001),
        );
        expect(tester.getRect(find.byType(LibraryTabs)), bounds);
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.getTopLeft(indicator), initial);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Back during editor and panel entrance returns safely without duplicate ownership',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.byKey(const ValueKey('root-new-drawing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EditorPage), findsNothing);
      expect(find.byType(LibraryTabs), findsOneWidget);
      final context = tester.element(find.byType(LibraryTabs));
      final closed = showCreativePanel<void>(
        context: context,
        builder: (_) => const CreativePanel(
          title: 'Motion interruption',
          child: TextField(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await closed;
      expect(find.byType(CreativePanel), findsNothing);
      expect(find.byType(LibraryTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
