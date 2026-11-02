import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/artwork_flight.dart';

class _LiveCanvas extends StatefulWidget {
  const _LiveCanvas({super.key, required this.points});
  final List<Offset> points;
  @override
  State<_LiveCanvas> createState() => _LiveCanvasState();
}

class _LiveCanvasState extends State<_LiveCanvas> {
  var builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => widget.points.add(event.localPosition),
      child: const ColoredBox(color: Colors.white),
    );
  }
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );
  testWidgets('reduced source opens immediately without a captured flight', (
    tester,
  ) async {
    var called = false;
    ArtworkFlightIntent? received;
    final document = ProjectDocument(id: 'reduced-source');
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 125,
                child: ArtworkFlightSource(
                  routeId: 'template-paper-hills',
                  document: document,
                  artwork: const ColoredBox(color: Colors.blue),
                  onOpen: (intent) async {
                    called = true;
                    received = intent;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ArtworkFlightSource));
    expect(called, isTrue);
    expect(received, isNull);
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final cancelMode in ['none', 'pointer', 'background']) {
    testWidgets(
      'actual pixels fly from nested route; stable live canvas, reverse and '
      '$cancelMode cancellation',
      (tester) async {
        final source = ProjectDocument(
          id: 'template-preview',
          title: 'Actual selected art',
          background: 0xffff0000,
        );
        final destination = ProjectDocument(id: 'fresh-template-document');
        final navigator = GlobalKey<NavigatorState>();
        final canvasKey = GlobalKey<_LiveCanvasState>();
        final points = <Offset>[];
        ArtworkFlightIntent? request;
        var opens = 0;
        late VoidCallback openAgain;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: HeroControllerScope.none(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 100,
                        height: 125,
                        child: ArtworkFlightSource(
                          routeId: 'template-paper-hills',
                          document: source,
                          artwork: const ColoredBox(color: Colors.blue),
                          builder: (context, anchor, open) {
                            openAgain = open;
                            return GestureDetector(onTap: open, child: anchor);
                          },
                          onOpen: (intent) async {
                            opens++;
                            request = intent;
                            await navigator.currentState!.push<void>(
                              PageRouteBuilder<void>(
                                transitionDuration: const Duration(
                                  milliseconds: 380,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 260,
                                ),
                                pageBuilder: (context, animation, secondary) =>
                                    Scaffold(
                                      body: Center(
                                        child: SizedBox(
                                          width: 240,
                                          height: 300,
                                          child: ArtworkFlightDestination(
                                            intent: intent,
                                            document: destination,
                                            child: _LiveCanvas(
                                              key: canvasKey,
                                              points: points,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                transitionsBuilder: (
                                  context,
                                  animation,
                                  secondary,
                                  child,
                                ) => child,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byType(ArtworkFlightSource));
        openAgain(); // A duplicate queued callback cannot push another route.
        expect(
          opens,
          1,
        ); // Navigation is not delayed for image encoding/decode.
        expect(request, isNotNull);
        expect(request!.cancelled, isFalse);
        expect(identical(request!.document, source), isTrue);
        expect(request!.routeId, 'template-paper-hills');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final state = canvasKey.currentState!;
        final rectangle = tester.getRect(find.byKey(canvasKey));
        expect(
          find.byKey(const ValueKey('artwork-flight-shuttle')),
          findsOneWidget,
        );
        final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
        final pixels = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        expect(
          pixels!.buffer.asUint8List(pixels.offsetInBytes, 4),
          [33, 150, 243, 255], // Actual Material blue, not red model paper.
        );
        if (cancelMode == 'pointer') {
          await tester.tapAt(rectangle.center + const Offset(10, 20));
          await tester.pump();
          expect(points, [const Offset(130, 170)]);
          expect(request!.cancelled, isTrue);
          expect(
            tester
                .widget<Opacity>(
                  find.byKey(const ValueKey('artwork-flight-shuttle')),
                )
                .opacity,
            0,
          );
        }
        if (cancelMode == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          expect(request!.cancelled, isTrue);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(points, isEmpty);
          expect(
            tester
                .widget<Opacity>(
                  find.byKey(const ValueKey('artwork-flight-shuttle')),
                )
                .opacity,
            0,
          );
        }
        await tester.pump(const Duration(milliseconds: 60));
        expect(identical(state, canvasKey.currentState), isTrue);
        expect(tester.getRect(find.byKey(canvasKey)), rectangle);
        expect(state.builds, 1);
        navigator.currentState!.pop(); // Reverse before forward has finished.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(image.debugDisposed, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(image.debugDisposed, isTrue);
        expect(opens, 1);
        expect(find.byType(ArtworkFlightSource), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rapid Back and reopen cancels old shuttle without delaying input',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final requests = <ArtworkFlightIntent?>[];
      final source = ProjectDocument(id: 'rapid-source');
      late VoidCallback open;
      var inputs = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 125,
                child: ArtworkFlightSource(
                  routeId: 'rapid-source',
                  document: source,
                  artwork: const ColoredBox(color: Colors.blue),
                  builder: (context, anchor, callback) {
                    open = callback;
                    return GestureDetector(onTap: callback, child: anchor);
                  },
                  onOpen: (intent) async {
                    requests.add(intent);
                    final index = requests.length;
                    await navigator.currentState!.push<void>(
                      PageRouteBuilder<void>(
                        transitionDuration: const Duration(milliseconds: 380),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 260,
                        ),
                        pageBuilder: (context, animation, secondary) =>
                            Scaffold(
                              body: Center(
                                child: SizedBox(
                                  width: 240,
                                  height: 300,
                                  child: ArtworkFlightDestination(
                                    intent: intent,
                                    document: ProjectDocument(
                                      id: 'fresh-$index',
                                    ),
                                    child: GestureDetector(
                                      key: ValueKey('rapid-canvas-$index'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => inputs++,
                                      child: const ColoredBox(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        transitionsBuilder: (
                          context,
                          animation,
                          secondary,
                          child,
                        ) => child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(ArtworkFlightSource));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(requests.single, isNotNull);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 15));
      open(); // Re-enter during reverse; no animation-end/navigation delay.
      expect(requests, hasLength(2));
      expect(requests.first!.cancelled, isTrue);
      expect(requests.last, isNull); // Honest opaque connected-route fallback.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byKey(const ValueKey('rapid-canvas-2')));
      expect(inputs, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ArtworkFlightSource), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced/direct entry skips flight and keeps ready input', (
    tester,
  ) async {
    final points = <Offset>[];
    final document = ProjectDocument(id: 'direct');
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox.expand(
              child: ArtworkFlightDestination(
                document: document,
                child: _LiveCanvas(points: points),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(40, 60));
    expect(points, [const Offset(40, 60)]);
    expect(find.byKey(const ValueKey('artwork-flight-shuttle')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
