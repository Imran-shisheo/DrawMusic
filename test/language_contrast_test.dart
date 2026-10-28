import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/doodimo_icon.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/language_page.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';

void main() {
  testWidgets(
    'compact 200 percent RTL language choices stay discoverable while help preserves pending selection',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryPreferencesStore(
        const UserPreferences(reduceMotion: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith((ref) async => store),
          ],
          child: MaterialApp(
            theme: buildTheme(brightness: Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LanguagePage(),
                    ),
                  ),
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();
      }

      await open();
      expect(
        find.byKey(const ValueKey('language-en')).hitTestable(),
        findsOneWidget,
        reason: 'First choice must be visible before scrolling at320dp/200%',
      );
      expect(
        find.byKey(const ValueKey('language-fr')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('language-fr')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-explanation')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Choose a language, then Apply. Your drawing titles stay unchanged.',
        ),
        findsOneWidget,
      );
      expect(
        store.preferences.languageCode,
        'en',
        reason: 'Help is informational and never applies a pending language',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('language-fr')))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('language-en')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.preferences.languageCode, 'en');
      await open();
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('language-en')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('language-fr')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(store.preferences.languageCode, 'fr');
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'selected language text and check contrast in $brightness; pending choice survives focus and respects Cancel/Apply',
      (tester) async {
        final store = MemoryPreferencesStore(
          const UserPreferences(reduceMotion: true),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesStoreProvider.overrideWith((ref) async => store),
            ],
            child: MaterialApp(
              theme: buildTheme(brightness: brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LanguagePage(),
                      ),
                    ),
                    child: const Text('Choose'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Choose'));
          await tester.pumpAndSettle();
        }

        void expectReadable(String code) {
          final tile = find.byKey(ValueKey('language-$code'));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: tile, matching: find.byType(RichText)).first,
          );
          final foreground = paragraph.text.style!.color!;
          final surface = tester.widget<AnimatedContainer>(
            find
                .ancestor(of: tile, matching: find.byType(AnimatedContainer))
                .first,
          );
          final background = (surface.decoration! as BoxDecoration).color!;
          double contrast(Color a, Color b) {
            final x = a.computeLuminance(), y = b.computeLuminance();
            return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
          }

          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: 'Actual rendered language label must stay readable on its selected surface',
          );
          final check = tester.widget<DoodimoIcon>(
            find.descendant(of: tile, matching: find.byType(DoodimoIcon)),
          );
          expect(contrast(check.color!, background), greaterThanOrEqualTo(3));
        }

        await open();
        expectReadable('en');
        await tester.tap(find.byKey(const ValueKey('language-fr')));
        await tester.pumpAndSettle();
        FocusScope.of(tester.element(find.byKey(const ValueKey('language-fr'))))
            .nextFocus();
        await tester.pump();
        expectReadable('fr');
        expect(store.preferences.languageCode, 'en');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(store.preferences.languageCode, 'en');
        await open();
        expectReadable('en');
        await tester.tap(find.byKey(const ValueKey('language-fr')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(store.preferences.languageCode, 'fr');
        expect(find.text('Choose'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
