import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  setUpAll(() async {
    for (final (family, faces) in [
      ('NunitoSans', ['Regular', 'Medium', 'SemiBold', 'Bold']),
      ('SpaceGrotesk', ['SemiBold', 'Bold']),
    ]) {
      final loader = FontLoader(family);
      for (final face in faces) {
        loader.addFont(
          rootBundle.load('assets/fonts/$family/$family-$face.ttf'),
        );
      }
      await loader.load();
    }
  });

  testWidgets(
    'real French coach at320dp/200% initially exposes title and useful body with bundled fonts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MemoryPreferencesStore(
        const UserPreferences(
          languageCode: 'fr',
          tutorialCompleted: true,
          reduceMotion: true,
        ),
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
      await tester.tap(find.byKey(const ValueKey('root-new-drawing')));
      await tester.pumpAndSettle();
      final canvas = find.byType(DrawingCanvas);
      final strings = tester.element(canvas).strings;
      final title = find.text(strings.drawAMelody);
      final body = find.text(
        strings.leftToRightFollowsEightBeatsHigherMarksMakeHigherNotesVert,
      );
      final viewport = find
          .ancestor(of: body, matching: find.byType(SingleChildScrollView))
          .first;
      final bounds = tester.getRect(viewport);
      expect(
        tester.getRect(title).bottom,
        lessThanOrEqualTo(bounds.bottom),
        reason: 'Tip title must be fully visible initially, not hidden below the counter',
      );
      expect(
        bounds.bottom - tester.getRect(body).top,
        greaterThanOrEqualTo(64),
        reason: 'At least two32px body lines must be visible before scrolling',
      );
      expect(find.text(strings.skipTips).hitTestable(), findsOneWidget);
      expect(find.text(strings.nextTip).hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pump();
      expect(tester.widget<DrawingCanvas>(canvas).document.strokes, isEmpty);
      await tester.tap(find.text(strings.nextTip));
      await tester.pumpAndSettle();
      expect(find.text(strings.listenAndPause), findsOneWidget);
      await tester.tap(find.text(strings.skipTips));
      await tester.pumpAndSettle();
      expect(store.preferences.editorTipsCompleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
