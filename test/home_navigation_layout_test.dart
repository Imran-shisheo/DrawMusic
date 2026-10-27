import 'package:flutter/material.dart';
import 'package:scribblesong/design_system/creative_dock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository;

void main() {
  setUpAll(() async {
    final loader = FontLoader('NunitoSans');
    for (final face in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/NunitoSans/NunitoSans-$face.ttf'),
      );
    }
    await loader.load();
  });
  testWidgets(
    'compact French 200 percent keeps Start reachable and dock labels inside its bounds',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(languageCode: 'fr', reduceMotion: true),
              ),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-start')).hitTestable(),
        findsOneWidget,
      );
      final dock = find.byType(CreativeDock);
      final dockBounds = tester.getRect(dock);
      for (final text
          in find
              .descendant(of: dock, matching: find.byType(Text))
              .evaluate()) {
        final bounds = tester.getRect(find.byWidget(text.widget));
        expect(bounds.top, greaterThanOrEqualTo(dockBounds.top));
        expect(bounds.bottom, lessThanOrEqualTo(dockBounds.bottom));
      }
      final homeBody = tester.getRect(
        find.byKey(const PageStorageKey('home-scroll')),
      );
      expect(homeBody.bottom, lessThanOrEqualTo(dockBounds.top));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'phone Home exposes creation and the first template names without an overlapping dock',
    (tester) async {
      tester.view.physicalSize = const Size(411, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(reduceMotion: true),
              ),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-start')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Paper hills').hitTestable(), findsOneWidget);
      expect(find.text('Little rain').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.text('Paper hills')).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(CreativeDock)).top),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
