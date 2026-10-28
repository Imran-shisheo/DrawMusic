import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/library/presentation/drafts.dart';
import 'package:scribblesong/features/library/presentation/library_tabs.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

void main() {
  for (final exports in [false, true]) {
    testWidgets(
      'library ${exports ? 'exports' : 'drafts'} supports French/RTL/dark/200 percent with pinned segments and reachable actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final document = ProjectDocument(
          id: 'layout-library',
          title: 'مرحبا 雨の歌 — Sunday ribbons',
        );
        final entries = [
          LibraryExport(
            id: 'drawing.mp4',
            artifact: ExportArtifact(
              '/fixture/drawing.mp4',
              'video/mp4',
              '雨の歌.mp4',
              document.id,
              0,
            ),
            createdAt: DateTime.utc(2026, 10, 27),
            bytes: 12000,
            available: true,
            preview: document,
          ),
        ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryProvider.overrideWith(
                (ref) async => ProjectListing([document], []),
              ),
              exportListingProvider.overrideWith(
                (ref) async => ExportListing(entries),
              ),
            ],
            child: MaterialApp(
              theme: buildTheme(brightness: Brightness.dark),
              locale: const Locale('fr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: exports ? const ExportsPage() : const DraftsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tabs = find.byType(LibraryTabs);
        final before = tester.getTopLeft(tabs);
        final menu = find.byWidgetPredicate(
          (widget) => widget is PopupMenuButton,
        );
        await tester.scrollUntilVisible(
          menu,
          120,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(menu.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(tabs), before);
        final rename = AppLocalizations.of(tester.element(menu))!.rename;
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(rename));
        await tester.pumpAndSettle();
        expect(find.text(rename).hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
