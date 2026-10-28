import 'support/editor_controls.dart';

import 'package:flutter/material.dart';
import 'package:scribblesong/design_system/creative_dock.dart';
import 'package:scribblesong/design_system/creative_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  testWidgets(
    'tabs keep scroll and library section; modal and editor Back preserve origin',
    (tester) async {
      final repo = MemoryRepository();
      for (var i = 0; i < 30; i++) {
        await repo.save(ProjectDocument(id: 'draft_$i', title: 'Drawing $i'));
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            repositoryProvider.overrideWith((ref) async => repo),
            libraryProvider.overrideWith(
              (ref) async => ProjectListing(repo.documents.values.toList(), []),
            ),
            exportListingProvider.overrideWith(
              (ref) async => ExportListing([]),
            ),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(),
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
      }

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      final homeScroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(homeScroll, greaterThan(0));
      await tab('Library');
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final draftScroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(draftScroll, greaterThan(0));
      await tab('Settings');
      await tab('Home');
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        homeScroll,
      );
      await tab('Library');
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        draftScroll,
      );
      await tester.tap(find.text('Exports'));
      await tester.pumpAndSettle();
      await tab('Settings');
      await tab('Library');
      expect(
        find.textContaining('Completed exports will appear here.'),
        findsOneWidget,
      );
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('drawing-canvas')),
        const Offset(40, 30),
      );
      await tester.pumpAndSettle();
      await openEditorTool(tester, 'clear');
      await tester.pumpAndSettle();
      expect(find.text('Clear this drawing?'), findsOneWidget);
      expect(find.byType(CreativePanel), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Clear this drawing?'), findsNothing);
      expect(find.byType(CreativePanel), findsNothing);
      expect(find.byTooltip('Play'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Completed exports will appear here.'),
        findsOneWidget,
      );
      expect(find.byType(CreativeDock), findsOneWidget);
    },
  );
}
