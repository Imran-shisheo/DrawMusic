import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/creative_panel.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/l10n/strings.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return ((first > second ? first : second) + .05) /
      ((first > second ? second : first) + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('$brightness semantic foregrounds meet normal-text contrast', () {
      final scheme = buildTheme(brightness: brightness).colorScheme;
      for (final (foreground, background) in [
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, scheme.surface),
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.primary, scheme.surface),
        (scheme.tertiary, scheme.surface),
      ]) {
        expect(
          contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
      expect(contrast(scheme.outline, scheme.surface), greaterThanOrEqualTo(3));
    });
  }

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'adaptive panel $size supports keyboard, Back and caller state',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final value = TextEditingController(text: 'Unsaved name');
        addTearDown(value.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showCreativePanel<void>(
                      context: context,
                      builder: (context) => CreativePanel(
                        title: 'A focused creative panel',
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Apply'),
                          ),
                        ],
                        child: Column(
                          children: [
                            TextField(controller: value, autofocus: true),
                            for (var i = 0; i < 8; i++)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Scroll to keep every control reachable.',
                                ),
                              ),
                          ],
                        ),
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
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Kept through transition',
        );
        expect(find.text('Apply').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CreativePanel), findsNothing);
        expect(value.text, 'Kept through transition');
        expect(find.text('Open').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
