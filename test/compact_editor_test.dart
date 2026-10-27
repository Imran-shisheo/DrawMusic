import 'support/editor_controls.dart';

import 'package:flutter/material.dart';
import 'package:scribblesong/design_system/creative_dock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'compact editor $size $direction: safe areas, 200% text, errors and modals',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewPadding();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final semantics = tester.ensureSemantics();
          try {
            final repository = MemoryRepository()..fail = true;
            final document = ProjectDocument(
              id: 'compact',
              title: 'موسيقى طويلة — A long title 日本語',
              strokes: [
                Stroke(
                  id: 'ink',
                  instrument: Instrument.keys,
                  points: [InkPoint(.1, .4), InkPoint(.9, .5)],
                ),
              ],
            );
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  initialDocumentProvider.overrideWithValue(document),
                  repositoryProvider.overrideWith((ref) async => repository),
                  preferencesStoreProvider.overrideWith(
                    (ref) async => MemoryPreferencesStore(),
                  ),
                  audioEngineProvider.overrideWithValue(TestAudio()),
                ],
                child: MaterialApp(
                  theme: buildTheme(),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) =>
                      Directionality(textDirection: direction, child: child!),
                  home: const EditorWorkspace(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final canvas = find.byKey(const ValueKey('drawing-canvas'));
            final rect = tester.getRect(canvas);
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.top, greaterThanOrEqualTo(24));
            expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
            expect(
              find.textContaining('Could not save this drawing'),
              findsOneWidget,
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await openEditorMusic(tester);
            await tester.ensureVisible(find.text('Cancel'));
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            repository.fail = false;
            await tester.tap(find.byTooltip('Save drawing'));
            await tester.pumpAndSettle();
            expect(
              repository.documents['compact']!.encode(),
              document.encode(),
            );
            await tester.tap(find.byTooltip('Export loop'));
            await tester.pumpAndSettle();
            for (final (format, label) in [
              ('png', 'Export PNG'),
              ('midi', 'Export MIDI'),
              ('wav', 'Export WAV'),
              ('mp4', 'Export MP4'),
            ]) {
              final intent = find.byKey(ValueKey('export-intent-$format'));
              await tester.ensureVisible(intent);
              await tester.pumpAndSettle();
              await tester.tap(intent);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('export-start')).hitTestable(),
                findsOneWidget,
              );
              expect(find.text(label), findsOneWidget);
            }
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await tester.tap(find.byTooltip('Close'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'root routes $size $direction: large text and keyboard naming',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewPadding();
            tester.view.resetViewInsets();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final router = buildRouter();
          addTearDown(router.dispose);
          final repo = MemoryRepository();
          final doc = ProjectDocument(
            id: 'root-layout',
            title: 'موسيقى — 日本語 long drawing',
          );
          await repo.save(doc);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  repositoryProvider.overrideWith((ref) async => repo),
                  preferencesStoreProvider.overrideWith(
                    (ref) async => MemoryPreferencesStore(),
                  ),
                  exportListingProvider.overrideWith(
                    (ref) async => ExportListing([]),
                  ),
                  audioEngineProvider.overrideWithValue(TestAudio()),
                ],
                child: MaterialApp.router(
                  theme: buildTheme(),
                  routerConfig: router,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) =>
                      Directionality(textDirection: direction, child: child!),
                ),
              ),
            );
            await tester.pumpAndSettle();
            Future<void> tab(String name) async {
              await tester.tap(
                find.descendant(
                  of: find.byType(CreativeDock),
                  matching: find.text(name),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
            }

            await tab('Library');
            final menu = find.byWidgetPredicate(
              (widget) => widget is PopupMenuButton,
            );
            await tester.scrollUntilVisible(
              menu,
              240,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await Scrollable.ensureVisible(tester.element(menu), alignment: .1);
            await tester.pumpAndSettle();
            await tester.tap(menu);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Rename'));
            await tester.pumpAndSettle();
            tester.view.viewInsets = FakeViewPadding(bottom: size.height * .45);
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), '');
            await tester.pumpAndSettle();
            expect(find.text('Use a name of 1–60 characters'), findsOneWidget);
            await tester.enterText(find.byType(TextField), 'اسم جديد 日本語');
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Apply'));
            expect(find.text('Apply').hitTestable(), findsOneWidget);
            await tester.ensureVisible(find.text('Cancel'));
            await tester.tap(find.text('Cancel'));
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            expect(repo.documents[doc.id]!.title, doc.title);
            await tester.tap(find.text('Exports'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.textContaining('Completed exports will appear here'),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(
              find.textContaining('Completed exports will appear here'),
              findsOneWidget,
            );
            await tab('Settings');
            await tester.scrollUntilVisible(
              find.text('Replay creation guide'),
              200,
            );
            await Scrollable.ensureVisible(
              tester.element(find.text('Replay creation guide')),
              alignment: .2,
            );
            await tester.pumpAndSettle();
            expect(
              find.text('Replay creation guide').hitTestable(),
              findsOneWidget,
            );
            await tester.tap(find.text('Replay creation guide'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Back to settings'));
            await tester.tap(find.text('Back to settings'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(find.text('Language'), -200);
            await Scrollable.ensureVisible(
              tester.element(find.text('Language')),
              alignment: .2,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Language'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Cancel'));
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
