import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scribblesong/design_system/immersive_surface.dart';
import 'package:scribblesong/design_system/brand_colors.dart';

Widget original(Widget child, bool luminous) => Builder(
  builder: (context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        gradient: luminous
            ? RadialGradient(
                center: const Alignment(.7, -.9),
                radius: 1.1,
                colors: dark
                    ? [const Color(0xff21204a), DoodimoColors.ink]
                    : [const Color(0xffdfe3ff), const Color(0xfff4f7ff)],
                stops: const [0, 1],
              )
            : null,
      ),
      child: child,
    );
  },
);
Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Uint8List.fromList(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }))!;
Widget host(
  GlobalKey capture, {
  required bool candidate,
  required bool dark,
  required bool luminous,
  required Widget child,
}) => MaterialApp(
  theme: dark ? ThemeData.dark() : ThemeData.light(),
  themeAnimationDuration: Duration.zero,
  home: Center(
    child: RepaintBoundary(
      key: capture,
      child: candidate
          ? SceneBackdrop(luminous: luminous, child: child)
          : original(child, luminous),
    ),
  ),
);

class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    height: 180,
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('Tap $taps'),
    ),
  );
}

class PulsePainter extends CustomPainter {
  PulsePainter(this.pulse) : super(repaint: pulse);
  final ValueNotifier<int> pulse;
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawCircle(const Offset(30, 30), 12, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) => false;
}

void main() {
  testWidgets(
    'production root is rejected by the pinned f9 diagnostic lookup',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: SceneBackdrop(
            key: key,
            child: const Scaffold(backgroundColor: Colors.transparent),
          ),
        ),
      );
      final actual = key.currentContext!.findRenderObject();
      expect(actual, isA<RenderStack>());
      expect(actual, isNot(isA<RenderDecoratedBox>()));
    },
  );
  testWidgets(
    'identical original pixels across themes lighting and resize, with no residual layer after unmount',
    (tester) async {
      final capture = GlobalKey();
      for (final dark in [true, false]) {
        for (final luminous in [true, false]) {
          for (final size in [const Size(240, 180), const Size(180, 300)]) {
            final child = SizedBox.fromSize(
              size: size,
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text('Scene'),
              ),
            );
            await tester.pumpWidget(
              host(
                capture,
                candidate: false,
                dark: dark,
                luminous: luminous,
                child: child,
              ),
            );
            final before = await pixels(tester, capture);
            await tester.pumpWidget(
              host(
                capture,
                candidate: true,
                dark: dark,
                luminous: luminous,
                child: child,
              ),
            );
            expect(
              await pixels(tester, capture),
              orderedEquals(before),
              reason: 'dark=$dark luminous=$luminous size=$size',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'theme and lighting changes retain interactive child state and only one named button',
    (tester) async {
      final capture = GlobalKey(), child = GlobalKey<CounterState>();
      final semantics = tester.ensureSemantics();

      Uint8List? previousPixels;
      for (final dark in [true, false, true]) {
        for (final luminous in [true, false]) {
          final previous = child.currentState;
          await tester.pumpWidget(
            host(
              capture,
              candidate: true,
              dark: dark,
              luminous: luminous,
              child: Counter(key: child),
            ),
          );
          if (previous != null) expect(child.currentState, same(previous));
          final currentPixels = await pixels(tester, capture);
          if (previousPixels != null) {
            expect(
              currentPixels,
              isNot(orderedEquals(previousPixels)),
              reason: 'Retained background must update after lighting/theme changes.',
            );
          }
          previousPixels = currentPixels;
          final before = child.currentState!.taps;
          await tester.tap(find.text('Tap $before'));
          await tester.pump();
          expect(child.currentState!.taps, before + 1);
          expect(find.bySemanticsLabel('Tap ${before + 1}'), findsOneWidget);
        }
      }
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'passes loose constraints and unbounded scroll axis to original child sizing',
    (tester) async {
      for (final vertical in [true, false]) {
        for (final candidate in [false, true]) {
          final key = GlobalKey();
          final child = SizedBox(key: key, width: 260, height: 420);
          Widget scene = candidate
              ? SceneBackdrop(child: child)
              : original(child, true);
          await tester.pumpWidget(
            MaterialApp(
              home: SingleChildScrollView(
                scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
                child: scene,
              ),
            ),
          );
          expect(
            tester.getSize(find.byKey(key)),
            vertical ? const Size(800, 420) : const Size(260, 600),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets(
    'animated child paints do not replace retained static background display list',
    (tester) async {
      final pulse = ValueNotifier(0);
      addTearDown(pulse.dispose);
      final childPainter = PulsePainter(pulse);
      await tester.pumpWidget(
        MaterialApp(
          home: SceneBackdrop(child: CustomPaint(painter: childPainter)),
        ),
      );
      final paintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.isComplex && !w.willChange,
      );
      expect(paintFinder, findsOneWidget);
      final render = tester.renderObject<RenderCustomPaint>(paintFinder);
      final boundary = render.parent! as RenderRepaintBoundary;
      final layer = boundary.debugLayer!;
      final picture = (layer.firstChild! as PictureLayer).picture;
      final initial = childPainter.paints;
      for (var i = 1; i <= 5; i++) {
        pulse.value = i;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(childPainter.paints, initial + 5);
      expect(boundary.debugLayer, same(layer));
      expect((layer.firstChild! as PictureLayer).picture, same(picture));
      await tester.pumpWidget(const SizedBox());
      expect(
        layer.debugDisposed,
        isTrue,
        reason: 'Unmount releases retained scene layer.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
