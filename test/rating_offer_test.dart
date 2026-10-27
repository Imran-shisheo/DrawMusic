import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/rating/presentation/rating_offer.dart';

void main() {
  testWidgets(
    'optional review offer is dismissible at compact large text and returns focus',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      bool? choice;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  focusNode: focus,
                  onPressed: () async {
                    choice = await showRatingOffer(context);
                  },
                  child: const Text('Saved work'),
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Saved work'));
      await tester.pumpAndSettle();
      expect(find.text('Optional app review'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(choice, isFalse);
      expect(focus.hasFocus, isTrue);
      expect(find.text('Saved work'), findsOneWidget);
    },
  );

  testWidgets(
    'Back declines optional review; Continue only opts into native request',
    (tester) async {
      bool? choice;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  choice = await showRatingOffer(context);
                },
                child: const Text('Done'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(choice, isFalse);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(choice, isTrue);
      expect(find.text('Done'), findsOneWidget);
    },
  );
}
