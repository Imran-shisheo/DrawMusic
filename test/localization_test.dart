import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/l10n/strings.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/data/file_preferences_store.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/language_page.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

class ObservedPreferences extends MemoryPreferencesStore {
  ObservedPreferences()
    : super(
        const UserPreferences(
          tutorialCompleted: true,
          editorTipsCompleted: true,
        ),
      );
  int writes = 0;
  @override
  Future<void> save(UserPreferences value) async {
    writes++;
    await super.save(value);
  }
}

void main() {
  test('unsupported and missing saved languages fall back without losing preferences', () async {
    final root = await Directory.systemTemp.createTemp('locale-test');
    addTearDown(() => root.delete(recursive: true));
    final store = FilePreferencesStore(root);
    await store.save(
      const UserPreferences(
        previewVolume: .35,
        languageCode: 'ja',
        editorTipsCompleted: true,
      ),
    );
    final loaded = (await FilePreferencesStore(root).load()).preferences;
    expect(loaded.languageCode, 'en');
    expect(loaded.previewVolume, .35);
    expect(loaded.editorTipsCompleted, isTrue);
    final legacy = loaded.toJson()..remove('languageCode');
    expect(UserPreferences.fromJson(legacy).languageCode, 'en');
  });
  testWidgets(
    'unsupported device locale uses English; language cancel/apply retain tabs and drawing',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ja')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final preferences = ObservedPreferences(), repo = MemoryRepository();
      final drawing = ProjectDocument(
        id: 'unicode',
        title: 'موسيقى — 日本語 👩🏽‍🎨',
        background: 0x80f3eef9,
        style: DrawingStyle.pixel,
        strokes: [
          Stroke(
            id: 'dot',
            instrument: Instrument.bell,
            points: [InkPoint(.5, .5)],
          ),
        ],
      );
      await repo.save(drawing);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => preferences),
            repositoryProvider.overrideWith((ref) async => repo),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.text('Home'))).languageCode,
        'en',
      );
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(find.text(drawing.title), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.text('Choose language'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(preferences.writes, 0);
      expect(find.text('Settings & help'), findsOneWidget);
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(preferences.writes, 1);
      expect(find.text('Settings & help'), findsOneWidget);
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(find.text(drawing.title), findsOneWidget);
      expect(repo.documents[drawing.id]!.encode(), drawing.encode());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'RTL large-text language selection keeps Apply/Cancel reachable and failed save retryable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final preferences = ObservedPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => preferences),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LanguagePage(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      preferences.fail = true;
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Choose language'), findsOneWidget);
      expect(find.textContaining('Could not save preferences'), findsOneWidget);
      preferences.fail = false;
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Choose language'), findsNothing);
      expect(preferences.preferences.languageCode, 'en');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'display formatting groups numbers and localizes dates independently of stored data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text(context.formatNumber(12345)),
                  Text(
                    context.formatLocalDate(DateTime.utc(2026, 10, 24, 18, 5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12,345'), findsOneWidget);
      expect(find.textContaining('Oct'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
    },
  );
}
