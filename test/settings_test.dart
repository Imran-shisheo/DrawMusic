import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/data/file_preferences_store.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'support/memory_preferences.dart';

void main() {
  test('preferences survive restart, recover corrupt primary and preserve damaged bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drawmusic-settings-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FilePreferencesStore(directory);
    expect((await store.load()).preferences.tutorialCompleted, isFalse);
    const first = UserPreferences(
      previewVolume: .25,
      haptics: true,
      tutorialCompleted: true,
    );
    await store.save(first);
    await store.save(first.copyWith(reduceMotion: true));
    final restarted = FilePreferencesStore(directory);
    final loaded = await restarted.load();
    expect(loaded.preferences.previewVolume, .25);
    expect(loaded.preferences.haptics, isTrue);
    expect(loaded.preferences.reduceMotion, isTrue);
    expect(loaded.preferences.tutorialCompleted, isTrue);
    await store.file.writeAsString('damaged');
    final recovered = await restarted.load();
    expect(recovered.recovered, isTrue);
    expect(recovered.preferences.reduceMotion, isFalse);
    await restarted.save(recovered.preferences);
    final preserved = await directory
        .list()
        .where((f) => f.path.contains('.preserved-'))
        .toList();
    expect(await File(preserved.single.path).readAsString(), 'damaged');
    expect(
      (await FilePreferencesStore(directory).load()).preferences.previewVolume,
      .25,
    );
  });

  test('invalid preferences never replace the last valid file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'drawmusic-settings-invalid-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FilePreferencesStore(directory);
    await store.save(const UserPreferences(previewVolume: .5));
    await expectLater(
      store.save(const UserPreferences(previewVolume: double.nan)),
      throwsFormatException,
    );
    expect((await store.load()).preferences.previewVolume, .5);
  });

  testWidgets(
    'first-use completion persists and help can be replayed without resetting it',
    (tester) async {
      final store = MemoryPreferencesStore();
      PackageInfo.setMockInitialValues(
        appName: 'ScribbleSong',
        packageName: 'com.imranshisheo.scribblesong',
        version: '1.3.0',
        buildNumber: '6',
        buildSignature: 'test',
      );
      Widget app() => ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith((ref) async => store),
        ],
        child: const ScribbleSongApp(showWelcome: true),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ScribbleSong'), findsOneWidget);
      await tester.ensureVisible(find.text('Start creating'));
      await tester.tap(find.text('Start creating'));
      await tester.pumpAndSettle();
      expect(store.preferences.tutorialCompleted, isTrue);
      expect(find.text('Home'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Haptic feedback'));
      await tester.tap(find.text('Haptic feedback'));
      await tester.pumpAndSettle();
      expect(store.preferences.haptics, isTrue);
      await tester.ensureVisible(find.text('Replay creation guide'));
      await tester.tap(find.text('Replay creation guide'));
      await tester.pumpAndSettle();
      expect(find.text('How to create a loop'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to settings'));
      await tester.tap(find.text('Back to settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings & help'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ScribbleSong'), findsNothing);
      expect(store.preferences.haptics, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed welcome save does not claim completion and supports retry',
    (tester) async {
      final store = MemoryPreferencesStore()..fail = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => store),
          ],
          child: const ScribbleSongApp(showWelcome: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start creating'));
      await tester.tap(find.text('Start creating'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to ScribbleSong'), findsOneWidget);
      expect(store.preferences.tutorialCompleted, isFalse);
      expect(
        find.text('Could not save preferences. Check storage, then retry.'),
        findsOneWidget,
      );
      store.fail = false;
      await tester.ensureVisible(find.text('Start creating'));
      await tester.tap(find.text('Start creating'));
      await tester.pumpAndSettle();
      expect(store.preferences.tutorialCompleted, isTrue);
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('welcome actions stay reachable at 320 dp and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final store = MemoryPreferencesStore(
      const UserPreferences(reduceMotion: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith((ref) async => store),
        ],
        child: const ScribbleSongApp(showWelcome: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.text('Start creating')),
      ),
      isTrue,
    );
    await tester.tap(find.text('Skip guide'));
    await tester.pumpAndSettle();
    expect(store.preferences.tutorialCompleted, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed preview-volume save keeps the saved preference and retries',
    (tester) async {
      final store = MemoryPreferencesStore(
        const UserPreferences(previewVolume: .75, tutorialCompleted: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => store),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.drag(find.byType(Slider), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(store.preferences.previewVolume, .75);
      expect(
        find.text('Could not save preferences. Check storage, then retry.'),
        findsOneWidget,
      );
      store.fail = false;
      await tester.tap(find.text('Retry preferences'));
      await tester.pumpAndSettle();
      expect(store.preferences.previewVolume, 0);
      expect(
        find.text(
          'Preview is muted. Exports still contain music. Also check your device media volume if playback is quiet.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
