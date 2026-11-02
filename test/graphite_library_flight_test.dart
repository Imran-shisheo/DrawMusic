import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/artwork_flight.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/library/presentation/drafts.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  testWidgets(
    'draft artwork flight uses unique retained sources and leaves live canvas stable during input and Back',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryRepository();
      for (final id in ['one', 'two']) {
        await repository.save(ProjectDocument(id: id, title: 'Drawing $id'));
      }
      final audio = TestAudio();
      var engines = 0;
      final router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repository),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            audioEngineProvider.overrideWith((ref) {
              engines++;
              return audio;
            }),
          ],
          child: MaterialApp.router(
            theme: buildTheme(brightness: Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-library')));
      await tester.pumpAndSettle();
      final sources = find.descendant(
        of: find.byType(DraftsPage),
        matching: find.byType(ArtworkFlightSource),
      );
      expect(sources, findsNWidgets(2));
      final heroes = tester.widgetList<Hero>(
        find.descendant(of: sources, matching: find.byType(Hero)),
      );
      expect(heroes.map((hero) => hero.tag).toSet(), hasLength(2));

      await tester.ensureVisible(find.text('Drawing one'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drawing one'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(EditorPage), findsOneWidget);
      final page = tester.widget<EditorPage>(find.byType(EditorPage));
      expect(page.projectId, 'one');
      expect(page.flightIntent, isNotNull);
      expect(page.flightIntent!.routeId, 'one');
      expect(page.flightIntent!.document.id, 'one');
      final canvas = find.byType(DrawingCanvas);
      expect(canvas, findsOneWidget);
      final state = tester.state<DrawingCanvasState>(canvas);
      final rect = tester.getRect(canvas);
      final pointer = await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(page.flightIntent!.cancelled, isTrue);
      await pointer.moveBy(const Offset(12, -8));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        identical(state, tester.state<DrawingCanvasState>(canvas)),
        isTrue,
      );
      expect(tester.getRect(canvas), rect);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(engines, 1);
      await tester.tap(find.byTooltip('Back to gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorPage), findsNothing);
      expect(find.byType(DraftsPage), findsOneWidget);
      expect(sources, findsNWidgets(2));
      expect(repository.documents['one']!.strokes, isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
