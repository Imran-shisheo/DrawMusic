import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/settings/presentation/language_page.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';
import 'package:scribblesong/l10n/strings.dart';

/// Settings groups are lazy. Reach Language through bounded user scrolling,
/// scoped to the active Settings list, rather than assuming the row is mounted.
Future<Finder> revealSettingsLanguage(WidgetTester tester) async {
  final page = find.byType(SettingsPage);
  expect(page, findsOneWidget);
  final label = tester.element(page).strings.language;
  final target = find.descendant(of: page, matching: find.text(label));
  final scrollable = find
      .descendant(of: page, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (
    var attempt = 0;
    attempt < 24 && position.pixels > position.minScrollExtent + 1;
    attempt++
  ) {
    await tester.drag(scrollable, const Offset(0, 220));
    await tester.pumpAndSettle();
  }
  expect(
    position.pixels,
    lessThanOrEqualTo(position.minScrollExtent + 1),
    reason: 'Settings must scroll to its beginning within the bounded user gesture budget',
  );
  await tester.scrollUntilVisible(
    target,
    180,
    maxScrolls: 24,
    scrollable: scrollable,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .2);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  return target;
}

Future<void> openSettingsLanguage(WidgetTester tester) async {
  final target = await revealSettingsLanguage(tester);
  await tester.tap(target.hitTestable());
  await tester.pumpAndSettle();
  expect(find.byType(LanguagePage), findsOneWidget);
}
