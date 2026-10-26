import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository;

void main() {
  testWidgets(
    'lower gallery templates remain reachable after a completed phone scroll',
    (tester) async {
      tester.view.physicalSize = const Size(411, 731);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.text('Three streams');
      expect(target, findsOneWidget);
      expect(target.hitTestable(), findsNothing);
      await Scrollable.ensureVisible(tester.element(target), alignment: .2);
      await tester.pumpAndSettle();
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target.hitTestable());
      await tester.pumpAndSettle();
      final doc = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .document;
      expect(doc.title, 'Three streams');
      expect(doc.mix.isActive, isTrue);
      expect(doc.strokes.length, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
