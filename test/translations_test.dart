import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/language_page.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';

import 'package:scribblesong/features/settings/application/settings_controller.dart';

void main() {
  Map<String, dynamic> arb(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
  Set<String> fields(String text) =>
      RegExp(r'\{(\w+)\}')
          .allMatches(text)
          .map((match) => match.group(1)!)
          .toSet();

  test('all twelve locales explicitly translate every resource and preserve placeholders', () {
    final english = arb('en');
    final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
    expect(nativeLanguageNames.length, 12);
    expect(
      AppLocalizations.supportedLocales.map((v) => v.languageCode).toSet(),
      nativeLanguageNames.keys.toSet(),
    );
    for (final code in nativeLanguageNames.keys) {
      final localized = arb(code);
      expect(localized['@@locale'], code);
      expect(
        localized.keys.where((key) => !key.startsWith('@')).toSet(),
        keys,
        reason: 'No missing or obsolete $code resource keys',
      );
      for (final key in keys) {
        final value = localized[key] as String;
        expect(value.trim(), isNotEmpty, reason: '$code:$key');
        expect(
          fields(value),
          fields(english[key] as String),
          reason: '$code:$key placeholders',
        );
      }
      if (code != 'en') {
        for (final key in [
          'playbackUnavailable',
          'drawingSaveFailed',
          'imageImportFailed',
          'shareUnavailable',
          'exportFailed',
          'languageExplanation',
          'geometrySimplified',
          'compatibilityFallback',
          'pngEmptyDescription',
        ]) {
          expect(
            localized[key],
            isNot(english[key]),
            reason: '$code:$key must not fall back to English',
          );
        }
      }
      final prefs = UserPreferences.fromJson(
        UserPreferences(languageCode: code, previewVolume: .35).toJson(),
      );
      expect(prefs.languageCode, code);
      expect(prefs.previewVolume, .35);
    }
    expect(english['drawingDetails'], contains('{root}'));
    expect(english['scoreSummary'], contains('{root}'));
    expect(english['scoreSummary'], isNot(contains('pentatonic')));
  });

  test(
    'native chooser and camera descriptions cover all shipped languages',
    () {
      for (final code in nativeLanguageNames.keys.where(
        (code) => code != 'en',
      )) {
        final folder = code == 'fil'
            ? 'values-b+fil'
            : code == 'id'
            ? 'values-in'
            : 'values-$code';
        final chooser = File('android/app/src/main/res/$folder/strings.xml');
        expect(chooser.existsSync(), isTrue, reason: code);
        expect(
          chooser.readAsStringSync(),
          contains('export_open_chooser_title'),
        );
        final camera = File('ios/Runner/$code.lproj/InfoPlist.strings');
        expect(camera.existsSync(), isTrue, reason: code);
        expect(camera.readAsStringSync(), contains('NSCameraUsageDescription'));
      }
    },
  );

  for (final code in nativeLanguageNames.keys) {
    testWidgets(
      '$code large-text language page preserves pending choice until Apply',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = MemoryPreferencesStore(
          const UserPreferences(languageCode: 'en'),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesStoreProvider.overrideWith((ref) async => store),
            ],
            child: MaterialApp(
              locale: Locale(code),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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
        final strings = AppLocalizations.of(
          tester.element(find.byType(LanguagePage)),
        )!;
        final pageContext = tester.element(find.byType(LanguagePage));
        final date = pageContext.formatLocalDate(DateTime.utc(2026, 10, 26));
        expect(date, isNotEmpty);
        if (code == 'id') expect(pageContext.formatNumber(12345), '12.345');
        if (code == 'fr') {
          expect(pageContext.formatNumber(12345), isNot('12,345'));
        }
        if (code == 'ja') expect(date, contains('年'));
        final selected = find.byKey(ValueKey('language-$code'));
        await tester.scrollUntilVisible(
          selected,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(selected), alignment: .2);
        await tester.pumpAndSettle();
        expect(selected.hitTestable(), findsOneWidget);
        await tester.tap(selected);
        await tester.pumpAndSettle();
        expect(
          store.preferences.languageCode,
          'en',
          reason: 'Selection is transactional',
        );
        expect(find.text(strings.apply).hitTestable(), findsOneWidget);
        expect(find.text(strings.cancel).hitTestable(), findsOneWidget);
        await tester.tap(find.text(strings.apply));
        await tester.pumpAndSettle();
        expect(store.preferences.languageCode, code);
        expect(find.byType(LanguagePage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
