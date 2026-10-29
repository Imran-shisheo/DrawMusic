import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uses the same compact navigation disclosure as a user. Destination keys
/// remain on the full labelled controls; never taps an offstage branch key.
Future<void> tapRootNavigation(WidgetTester tester, String key) async {
  var target = find.byKey(ValueKey(key)).hitTestable();
  if (target.evaluate().isEmpty) {
    final summary = find.byKey(const ValueKey('nav-summary')).hitTestable();
    expect(summary, findsOneWidget);
    await tester.tap(summary);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    final mounted = find.byKey(ValueKey(key));
    expect(mounted, findsOneWidget);
    await tester.ensureVisible(mounted);
    await tester.pump();
    target = mounted.hitTestable();
  }
  expect(target, findsOneWidget);
  await tester.tap(target);
}
