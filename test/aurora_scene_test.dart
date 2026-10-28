import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/aurora_scene.dart';
import 'package:scribblesong/design_system/motion.dart';

Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = Uint8List.fromList(data!.buffer.asUint8List());
    image.dispose();
    return bytes;
  }))!;
}

int difference(Uint8List a, Uint8List b) {
  var total = 0;
  for (var i = 0; i < a.length; i += 4) {
    total +=
        (a[i] - b[i]).abs() +
        (a[i + 1] - b[i + 1]).abs() +
        (a[i + 2] - b[i + 2]).abs();
  }
  return total;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
  });

  testWidgets(
    'actual Aurora pauses hidden/background/reduced, retains state and is decorative only',
    (tester) async {
      final active = ValueNotifier(true), reduced = ValueNotifier(false);
      addTearDown(active.dispose);
      addTearDown(reduced.dispose);
      final scene = GlobalKey(), capture = GlobalKey();
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            builder: (context, reduce, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, enabled, _) => TickerMode(
                  enabled: enabled,
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 240,
                      child: GestureDetector(
                        onTap: () => taps++,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Semantics(
                              label: 'Real artwork',
                              child: ColoredBox(color: Color(0xff090b18)),
                            ),
                            RepaintBoundary(
                              key: capture,
                              child: AuroraScene(key: scene),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final state = scene.currentState;
      expect(tester.hasRunningAnimations, isTrue);
      expect(
        find.descendant(
          of: find.byType(AuroraScene),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AuroraScene),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      await tester.tapAt(tester.getCenter(find.byType(AuroraScene)));
      expect(
        taps,
        1,
        reason: 'Decorative scene must not steal artwork interaction',
      );
      active.value = false;
      await tester.pump();
      final hidden = await pixels(tester, capture);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
      expect(await pixels(tester, capture), orderedEquals(hidden));
      active.value = true;
      await tester.pump();
      expect(scene.currentState, same(state));
      expect(tester.hasRunningAnimations, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      reduced.value = true;
      await tester.pump();
      final still = await pixels(tester, capture);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.hasRunningAnimations, isFalse);
      expect(scene.currentState, same(state));
      expect(await pixels(tester, capture), orderedEquals(still));
      expect(
        still.where((value) => value != 0).length,
        greaterThan(1000),
        reason: 'Reduced motion retains actual luminous artwork',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Real artwork')).label,
        'Real artwork',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'rendered ribbon and orbit cross the ambient loop without a reset jump',
    (tester) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: RepaintBoundary(key: capture, child: const AuroraScene()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(
        CreativeMotion.ambient - const Duration(milliseconds: 48),
      );
      final before = await pixels(tester, capture);
      await tester.pump(const Duration(milliseconds: 24));
      final nearEnd = await pixels(tester, capture);
      await tester.pump(const Duration(milliseconds: 24));
      final restart = await pixels(tester, capture);
      final normal = difference(before, nearEnd),
          seam = difference(nearEnd, restart);
      expect(
        normal,
        greaterThan(0),
        reason: 'Actual sculpture must visibly animate',
      );
      expect(
        seam,
        lessThan(normal * 3),
        reason:
            'A loop boundary must not cause a large visual jump compared with equal-time neighboring motion (normal=$normal, seam=$seam)',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
