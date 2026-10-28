// Identity/rebuild regressions, not native frame-rate measurements.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/home/domain/template_catalog.dart';
import 'package:scribblesong/features/home/presentation/templates.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/l10n/strings.dart';

Future<void> fonts() async {
  for (final family in ['NunitoSans', 'SpaceGrotesk']) {
    final loader = FontLoader(family);
    for (final file in Directory(
      'assets/fonts/$family',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}

Map<String, DrawingPainter> painters(WidgetTester tester) => {
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(TemplateGallery),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter,
      ),
    ),
  ))
    (paint.painter! as DrawingPainter).document.title:
        paint.painter! as DrawingPainter,
};

void main() {
  testWidgets(
    'five pixel scrolling preserves retained template documents and painters; responsive and inherited changes stay correct',
    (tester) async {
      tester.view.physicalSize = const Size(411, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.runAsync(fonts);
      final appearance = ValueNotifier((dark: true, scale: 1.0, locale: 'en'));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomePage()),
          GoRoute(
            path: '/editor/:id',
            builder: (_, s) =>
                Scaffold(body: Text('Opened ${s.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(
              (ref) async => const ProjectListing([], []),
            ),
          ],
          child: ValueListenableBuilder(
            valueListenable: appearance,
            builder: (_, value, _) => MaterialApp.router(
              theme: buildTheme(
                brightness: value.dark ? Brightness.dark : Brightness.light,
              ),
              themeAnimationDuration: Duration.zero,
              locale: Locale(value.locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(value.scale)),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      final template = originalTemplates.first;
      final caption = find.descendant(
        of: find.byType(TemplateGallery),
        matching: find.text(template.title),
      );
      final card = find.byKey(ValueKey(template.id));
      final priorDescription = tester.getSemantics(card).label;
      final priorCaptionColor = tester.widget<Text>(caption).style!.color;
      final before = painters(tester);
      expect(before.length, greaterThanOrEqualTo(2));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const PageStorageKey('home-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      for (var i = 1; i <= 16; i++) {
        position.jumpTo(i * 5.0);
        await tester.pump(const Duration(milliseconds: 16));
        expect(position.pixels, i * 5.0);
        final after = painters(tester);
        final retained = before.keys.toSet().intersection(after.keys.toSet());
        expect(retained.length, greaterThanOrEqualTo(2));
        for (final id in retained) {
          expect(
            after[id]!.document,
            same(before[id]!.document),
            reason: 'A scroll constraint must not regenerate the $id template.',
          );
          expect(
            after[id],
            same(before[id]),
            reason:
                'Unchanged columns must retain the row delegate and painters.',
          );
        }
      }
      tester.view.physicalSize = const Size(760, 850);
      await tester.pump();
      final resized = painters(tester);
      for (final painter in resized.values) {
        expect(
          painter.document.title,
          originalTemplates
              .singleWhere((t) => t.title == painter.document.title)
              .title,
        );
      }
      appearance.value = (dark: false, scale: 1.8, locale: 'fr');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final entry in painters(tester).entries) {
        if (resized.containsKey(entry.key)) {
          expect(entry.value.document, same(resized[entry.key]!.document));
        }
      }
      await tester.ensureVisible(caption);
      await tester.pump(const Duration(milliseconds: 300));
      final localized = AppLocalizations.of(tester.element(card))!;
      expect(localized.localeName, 'fr');
      expect(
        tester.getSemantics(card).label,
        contains(localized.templateDescription0),
      );
      expect(tester.getSemantics(card).label, isNot(priorDescription));
      expect(
        tester.widget<Text>(caption).style!.color,
        buildTheme().colorScheme.onSurface,
      );
      expect(
        tester.widget<Text>(caption).style!.color,
        isNot(priorCaptionColor),
      );
      await tester.tap(caption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Opened ${template.id}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
      router.dispose();
    },
  );
}
