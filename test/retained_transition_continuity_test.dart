import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/retained_transition.dart';

Future<List<int>> pixel(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = data!.buffer.asUint8List().sublist(0, 4);
    image.dispose();
    return result;
  }))!;
}

void main() {
  testWidgets(
    'first frame, reversal and third destination preserve painted coverage',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final boundary = GlobalKey();
      final children = [
        for (final color in [Colors.red, Colors.blue, Colors.green])
          ColoredBox(color: color),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (_, index, _) =>
                  RetainedBranchContainer(index: index, children: children),
            ),
          ),
        ),
      );
      final initial = await pixel(tester, boundary);
      selected.value = 1;
      await tester.pump();
      expect(
        await pixel(tester, boundary),
        initial,
        reason: 'The outgoing page must still cover the first incoming frame.',
      );
      await tester.pump(const Duration(milliseconds: 80));
      final beforeReverse = await pixel(tester, boundary);
      expect(beforeReverse, isNot(initial));
      expect(beforeReverse[3], 255);
      selected.value = 0;
      await tester.pump();
      expect(
        await pixel(tester, boundary),
        beforeReverse,
        reason: 'Reversal cannot reset visible progress.',
      );
      await tester.pump(const Duration(milliseconds: 40));
      final beforeThird = await pixel(tester, boundary);
      selected.value = 2;
      await tester.pump();
      expect(
        await pixel(tester, boundary),
        beforeThird,
        reason: 'A third destination must blend from the actual painted composition.',
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect((await pixel(tester, boundary))[3], 255);
      }
      await tester.pump(const Duration(milliseconds: 80));
      expect(await pixel(tester, boundary), [76, 175, 80, 255]);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'departing content has no input or semantics and reduction completes an interrupted blend',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final semantics = tester.ensureSemantics();
      var selected = 0, reduced = false, firstTaps = 0, secondTaps = 0;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) {
              change = update;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: RetainedBranchContainer(
                  index: selected,
                  children: [
                    Center(
                      child: TextButton(
                        onPressed: () => firstTaps++,
                        child: const Text('First action'),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => secondTaps++,
                        child: const Text('Second action'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      change(() => selected = 1);
      await tester.pump();
      final semanticTree = tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!
          .toStringDeep();
      expect(semanticTree, isNot(contains('First action')));
      expect(semanticTree, contains('Second action'));
      await tester.tap(find.text('Second action'));
      expect(firstTaps, 0);
      expect(secondTaps, 1);
      await tester.pump(const Duration(milliseconds: 40));
      change(() => reduced = true);
      await tester.pump();
      expect(find.text('First action'), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Second action'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
