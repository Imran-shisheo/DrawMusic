import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';

void main() {
  testWidgets('Create, Back and shell tabs remain usable', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ScribbleSongApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start drawing'));
    await tester.pumpAndSettle();
    expect(find.text('Untitled drawing'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drafts'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your drawings will live here.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & help'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
