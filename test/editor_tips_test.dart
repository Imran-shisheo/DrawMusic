import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'support/memory_preferences.dart';
import 'support/editor_controls.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  test(
    'legacy preferences acquire unseen editor tips without losing settings',
    () {
      final json = const UserPreferences(
        previewVolume: .4,
        tutorialCompleted: true,
      ).toJson()..remove('editorTipsCompleted');
      final loaded = UserPreferences.fromJson(json);
      expect(loaded.editorTipsCompleted, isFalse);
      expect(loaded.tutorialCompleted, isTrue);
      expect(loaded.previewVolume, .4);
      expect(
        UserPreferences.fromJson(
          loaded.copyWith(editorTipsCompleted: true).toJson(),
        ).editorTipsCompleted,
        isTrue,
      );
    },
  );
  testWidgets(
    'first editor offers every tip, blocks tap-through and completion is replayable',
    (tester) async {
      final store = MemoryPreferencesStore(
        const UserPreferences(tutorialCompleted: true),
      );
      final repo = MemoryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => store),
            repositoryProvider.overrideWith((ref) async => repo),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(showWelcome: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      expect(find.text('Draw a melody'), findsOneWidget);
      final canvas = find.byType(DrawingCanvas);
      await tester.tapAt(tester.getCenter(canvas));
      await tester.pumpAndSettle();
      expect(tester.widget<DrawingCanvas>(canvas).document.strokes, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(store.preferences.editorTipsCompleted, isFalse);
      expect(find.byTooltip('Play'), findsOneWidget);
      await openEditorTool(tester, 'tips');
      await tester.pumpAndSettle();
      for (final title in [
        'Listen and pause',
        'Choose a voice',
        'Set the pace',
        'Key and scale',
      ]) {
        await tester.tap(find.text('Next tip'));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(store.preferences.editorTipsCompleted, isTrue);
      await tester.tap(find.byTooltip('Back to gallery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      expect(find.text('Skip tips'), findsNothing);
      await openEditorTool(tester, 'tips');
      await tester.pumpAndSettle();
      expect(find.text('Draw a melody'), findsOneWidget);
      await tester.tap(find.text('Skip tips'));
      await tester.pumpAndSettle();
      expect(store.preferences.editorTipsCompleted, isTrue);
    },
  );
  testWidgets(
    'narrow large-text tips keep Skip reachable and failed saving stays honest',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MemoryPreferencesStore(
        const UserPreferences(tutorialCompleted: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => store),
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(showWelcome: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      expect(find.text('Skip tips').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      store.fail = true;
      await tester.tap(find.text('Skip tips'));
      await tester.pumpAndSettle();
      expect(store.preferences.editorTipsCompleted, isFalse);
      expect(
        find.textContaining('Completion could not be saved'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('drawing-canvas')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
