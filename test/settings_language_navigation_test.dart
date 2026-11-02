import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';

import 'support/memory_preferences.dart';
import 'support/root_navigation.dart';
import 'support/settings_navigation.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'real Settings lazy Language navigation and Japanese Apply at scale$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final prefs = MemoryPreferencesStore(
          const UserPreferences(reduceMotion: true),
        );
        final repo = MemoryRepository();
        final document = ProjectDocument(
          id: 'saved-before-language',
          title: '日本語 — محفوظ',
          strokes: [
            Stroke(
              id: 'ink',
              instrument: Instrument.bell,
              points: [InkPoint(.2, .4), InkPoint(.8, .6)],
            ),
          ],
        );
        await repo.save(document);
        final before = repo.documents[document.id]!.encode();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesStoreProvider.overrideWith((ref) async => prefs),
              repositoryProvider.overrideWith((ref) async => repo),
              audioEngineProvider.overrideWithValue(TestAudio()),
            ],
            child: const ScribbleSongApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tapRootNavigation(tester, 'nav-settings');
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsPage)),
        );
        expect(
          find.text('Language').hitTestable(),
          findsNothing,
          reason: 'Regression starts with the real below-fold settings entry',
        );
        if (scale == 2) {
          expect(
            find.text('Language'),
            findsNothing,
            reason: 'Large-text lazy list reproduces the native zero-widget finder failure',
          );
        }
        await openSettingsLanguage(tester);
        final japanese = find.byKey(const ValueKey('language-ja'));
        await tester.scrollUntilVisible(japanese, 200, maxScrolls: 24);
        await Scrollable.ensureVisible(tester.element(japanese), alignment: .2);
        await tester.pumpAndSettle();
        await tester.tap(japanese.hitTestable());
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(japanese).selected, isTrue);
        expect(prefs.preferences.languageCode, 'en');
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(container.read(settingsProvider).preferences.languageCode, 'ja');
        expect(prefs.preferences.languageCode, 'ja');
        await revealSettingsLanguage(tester);
        expect(find.text('日本語').hitTestable(), findsOneWidget);
        expect(repo.documents[document.id]!.encode(), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
