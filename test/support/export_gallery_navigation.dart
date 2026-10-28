import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gallery entries are lazy. Reveal the requested real filename/action in the
/// actual exports list instead of requiring all four rows to remain mounted.
/// Reset with bounded user gestures so this also works when returning from the
/// oldest export to an earlier row, without directly mutating ScrollPosition.
Future<void> revealExportGalleryItem(WidgetTester tester, Finder target) async {
  final list = find.byKey(const PageStorageKey('exports-scroll'));
  expect(list, findsOneWidget);
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (
    var attempt = 0;
    attempt < 24 && position.pixels > position.minScrollExtent + 1;
    attempt++
  ) {
    await tester.drag(list, const Offset(0, 220));
    await tester.pumpAndSettle();
  }
  expect(
    position.pixels,
    lessThanOrEqualTo(position.minScrollExtent + 1),
    reason: 'The actual export gallery must scroll back to its beginning.',
  );
  await tester.scrollUntilVisible(
    target,
    180,
    maxScrolls: 24,
    scrollable: scrollable,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .2);
  await tester.pumpAndSettle();
  expect(target, findsOneWidget);
  expect(target.hitTestable(), findsOneWidget);
}
