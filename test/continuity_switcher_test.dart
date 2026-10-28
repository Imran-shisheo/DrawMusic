import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/continuity_switcher.dart';

const keys = [ValueKey('a'), ValueKey('b'), ValueKey('c')];

class Item extends StatefulWidget {
  const Item({
    super.key,
    required this.label,
    required this.height,
    required this.color,
    required this.onTap,
  });
  final String label;
  final double height;
  final Color color;
  final VoidCallback onTap;
  @override
  State<Item> createState() => ItemState();
}

class ItemState extends State<Item> {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: 180,
    child: ColoredBox(
      color: widget.color,
      child: TextButton(onPressed: widget.onTap, child: Text(widget.label)),
    ),
  );
}

Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      try {
        return Uint8List.fromList(
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
              .asUint8List(),
        );
      } finally {
        image.dispose();
      }
    }))!;
void main() {
  testWidgets(
    'first frame and rapid reversals preserve pixels and mounted current state; settled cache bounded',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final capture = GlobalKey();
      var aHits = 0, bHits = 0;
      Widget host(int selected, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: RepaintBoundary(
              key: capture,
              child: ContinuitySwitcher(
                stateKeys: keys,
                child: Item(
                  key: keys[selected],
                  label: 'State $selected',
                  height: 100,
                  color: [Colors.red, Colors.blue, Colors.green][selected],
                  onTap: () => selected == 0 ? aHits++ : bHits++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(0));
      final aState = tester.state(find.byType(Item));
      final initial = await pixels(tester, capture);
      await tester.pumpWidget(host(1));
      expect(await pixels(tester, capture), orderedEquals(initial));
      await tester.tap(find.text('State 1'));
      expect(bHits, 1);
      expect(aHits, 0);
      await tester.pump(const Duration(milliseconds: 55));
      final blend = await pixels(tester, capture);
      await tester.pumpWidget(host(0));
      expect(await pixels(tester, capture), orderedEquals(blend));
      expect(tester.state(find.byKey(keys[0])), same(aState));
      await tester.pump(const Duration(milliseconds: 35));
      final reversal = await pixels(tester, capture);
      await tester.pumpWidget(host(2));
      expect(await pixels(tester, capture), orderedEquals(reversal));
      expect(find.byType(Item), findsNWidgets(3));
      await tester.pumpAndSettle();
      expect(find.byType(Item), findsOneWidget);
      expect(find.text('State 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'only current semantics focus and ticker stay active; reduced motion ends interrupted blend',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final semantics = tester.ensureSemantics();
      final aFocus = FocusNode(), bFocus = FocusNode();
      Widget host(int selected, bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: ContinuitySwitcher(
            stateKeys: keys,
            child: Focus(
              key: keys[selected],
              focusNode: selected == 0 ? aFocus : bFocus,
              child: Builder(
                builder: (context) => Semantics(
                  label: 'only $selected',
                  child: SizedBox(
                    height: 80,
                    child: Text(
                      'ticker:${TickerMode.valuesOf(context).enabled}',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(0, false));
      aFocus.requestFocus();
      await tester.pump();
      expect(aFocus.hasFocus, isTrue);
      await tester.pumpWidget(host(1, false));
      await tester.pump();
      expect(aFocus.hasFocus, isFalse);
      expect(aFocus.canRequestFocus, isFalse);
      expect(
        tester.getSemantics(find.byType(ContinuitySwitcher)).toStringDeep(),
        isNot(contains('only 0')),
      );
      expect(
        tester.getSemantics(find.byType(ContinuitySwitcher)).toStringDeep(),
        contains('only 1'),
      );
      expect(find.text('ticker:false'), findsOneWidget);
      expect(find.text('ticker:true'), findsOneWidget);
      await tester.pumpWidget(host(1, true));
      expect(find.text('ticker:false'), findsNothing);
      await tester.pumpWidget(host(0, true));
      expect(find.text('ticker:true'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ContinuitySwitcher)).toStringDeep(),
        contains('only 0'),
      );
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      aFocus.dispose();
      bFocus.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'new short and tall content alone determine layout without remount or overflow',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final bounds = GlobalKey();
      Widget host(int selected, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: ContinuitySwitcher(
                key: bounds,
                stateKeys: keys,
                child: Item(
                  key: keys[selected],
                  label: 'size $selected',
                  height: selected == 0 ? 280 : 60,
                  color: Colors.blue,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(0));
      expect(tester.getSize(find.byKey(bounds)).height, 280);
      await tester.pumpWidget(host(1));
      final state = tester.state(find.byKey(keys[1]));
      expect(tester.getSize(find.byKey(keys[1])).height, 60);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(bounds)).height, 60);
      expect(tester.state(find.byKey(keys[1])), same(state));
      await tester.pumpWidget(host(0));
      expect(tester.getSize(find.byKey(keys[0])).height, 280);
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getSize(find.byKey(bounds)).height, lessThan(280));
      await tester.pumpWidget(host(0, reduced: true));
      expect(tester.getSize(find.byKey(bounds)).height, 280);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'growing content stays inside animated bounds above live footer and reverses size continuously',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final capture = GlobalKey(), bounds = GlobalKey();
      var topHits = 0, footerHits = 0;
      Widget host(int selected) => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: capture,
            child: SizedBox(
              width: 180,
              height: 400,
              child: ColoredBox(
                color: Colors.black,
                child: Column(
                  children: [
                    ContinuitySwitcher(
                      key: bounds,
                      stateKeys: keys,
                      child: SizedBox(
                        key: keys[selected],
                        height: selected == 0 ? 60 : 280,
                        child: ColoredBox(
                          color: selected == 0 ? Colors.red : Colors.green,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: TextButton(
                              onPressed: () => topHits++,
                              child: const Text('Top control'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      width: 180,
                      child: ColoredBox(
                        color: Colors.purple,
                        child: TextButton(
                          onPressed: () => footerHits++,
                          child: const Text('Fixed footer'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 40));
      final height = tester.getSize(find.byKey(bounds)).height;
      expect(height, greaterThan(60));
      expect(height, lessThan(280));
      final image = await pixels(tester, capture);
      final sample = ((height + 55).floor() * 180 + 5) * 4;
      expect(
        image.sublist(sample, sample + 4),
        [0, 0, 0, 255],
        reason: 'Tall incoming paint must not spill below the animated content and footer.',
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(keys[1]),
          matching: find.text('Top control'),
        ),
      );
      expect(topHits, 1);
      await tester.tap(find.text('Fixed footer'));
      expect(footerHits, 1);
      final before = tester.getSize(find.byKey(bounds));
      await tester.pumpWidget(host(0));
      expect(
        tester.getSize(find.byKey(bounds)),
        before,
        reason: 'Mid-height reversal samples current outer bounds.',
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(bounds)).height, 60);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'transparent disjoint marks fade individually and reverse without a pixel jump',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      final capture = GlobalKey();
      Widget host(int selected) => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: capture,
            child: ColoredBox(
              color: Colors.white,
              child: ContinuitySwitcher(
                stateKeys: keys,
                child: SizedBox(
                  key: keys[selected],
                  width: 100,
                  height: 50,
                  child: Stack(
                    children: [
                      Positioned(
                        left: selected == 0 ? 0 : 80,
                        top: 0,
                        width: 20,
                        height: 20,
                        child: ColoredBox(
                          color: selected == 0
                              ? const Color(0xffff0000)
                              : const Color(0xff0000ff),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(0));
      final before = await pixels(tester, capture);
      final left = (10 * 100 + 10) * 4, right = (10 * 100 + 90) * 4;
      expect(before.sublist(left, left + 4), [255, 0, 0, 255]);
      expect(before.sublist(right, right + 4), [255, 255, 255, 255]);
      await tester.pumpWidget(host(1));
      expect(await pixels(tester, capture), orderedEquals(before));
      await tester.pump(const Duration(milliseconds: 60));
      final middle = await pixels(tester, capture);
      expect(
        middle[left + 1],
        greaterThan(0),
        reason: 'Outgoing red-only mark must already fade toward its white surface.',
      );
      expect(middle[left + 1], lessThan(255));
      expect(middle[right], greaterThan(0));
      expect(
        middle[right],
        lessThan(255),
        reason: 'Incoming blue-only mark grows gradually.',
      );
      await tester.pumpWidget(host(0));
      expect(await pixels(tester, capture), orderedEquals(middle));
      await tester.pumpAndSettle();
      expect(await pixels(tester, capture), orderedEquals(before));
      expect(tester.takeException(), isNull);
    },
  );
}
