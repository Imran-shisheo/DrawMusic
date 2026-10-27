import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/aurora_scene.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';

import 'aurora_scene_test.dart' show difference, pixels;

Widget _host({
  required Widget scene,
  Size size = const Size(320, 240),
  double dpr = 1,
  Brightness brightness = Brightness.dark,
  bool reduce = false,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: ThemeData(brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(devicePixelRatio: dpr, disableAnimations: reduce),
    child: Center(
      child: SizedBox(width: size.width, height: size.height, child: scene),
    ),
  ),
);

Future<ui.Image> _texture(
  WidgetTester tester, {
  bool Function(ui.Image)? where,
}) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    final images = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .map((widget) => widget.image)
        .whereType<ui.Image>();
    for (final image in images) {
      if (where == null || where(image)) return image;
    }
  }
  throw TestFailure('The bounded static sculpture texture was not produced.');
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('AURORA_CACHE_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('work/aurora-cache-review');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _CountingArtwork extends DrawingPainter {
  _CountingArtwork(super.document);
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    super.paint(canvas, size);
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
  });
  testWidgets(
    'retained sculpture texture and changing accents never repaint/rebuild a10000point artwork',
    (tester) async {
      final points = [
        for (var i = 0; i < 10000; i++)
          InkPoint(.05 + .9 * i / 9999, .5 + .4 * math.sin(i / 300)),
      ];
      final document = ProjectDocument(
        id: 'ambient-sibling',
        strokes: [
          Stroke(id: 'dense', instrument: Instrument.keys, points: points),
        ],
      );
      final artwork = _CountingArtwork(document);
      var builds = 0;
      await tester.pumpWidget(
        _host(
          scene: Builder(
            builder: (context) {
              builds++;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const AuroraScene(),
                  Positioned(
                    right: 0,
                    top: 0,
                    width: 100,
                    height: 125,
                    child: CustomPaint(painter: artwork),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final image = await _texture(tester);
      final initialPaints = artwork.paints, initialBuilds = builds;
      final dynamicPaint = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.willChange,
      );
      final dynamicBoundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(of: dynamicPaint, matching: find.byType(RepaintBoundary))
            .first,
      );
      dynamicBoundary.debugResetMetrics();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(image));
      expect(
        artwork.paints,
        initialPaints,
        reason: 'Ambient activity must not repaint real dense artwork.',
      );
      expect(
        builds,
        initialBuilds,
        reason:
            'The scene must not rebuild the containing Home/artwork widgets.',
      );
      expect(
        dynamicBoundary.debugAsymmetricPaintCount,
        greaterThan(20),
        reason: 'Live highlights/orbits repaint independently from retained sculpture pixels.',
      );
      expect(image.width * image.height, lessThanOrEqualTo(1048576));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(image.debugDisposed, isTrue);
    },
  );
  testWidgets(
    'first-frame vector and cached sculpture preserve visible color/shape at the same motion phase',
    (tester) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        _host(
          scene: RepaintBoundary(key: capture, child: const AuroraScene()),
        ),
      );
      final fallback = await pixels(tester, capture);
      await _capture(tester, capture, '01-original-vector-phase0');
      await _texture(tester);
      final cached = await pixels(tester, capture);
      await _capture(tester, capture, '02-bounded-texture-phase0');
      final mean = difference(fallback, cached) / (fallback.length / 4 * 3);
      debugPrint(
        'Aurora vector/cache mean absolute RGB delta at unchanged phase: $mean',
      );
      expect(
        mean,
        lessThan(1.5),
        reason: 'Caching may resample a fine antialias edge, but must not change the ribbon/lighting identity or flash blank.',
      );
      expect(cached.where((byte) => byte != 0).length, greaterThan(1000));
      await tester.pump(const Duration(milliseconds: 800));
      await _capture(tester, capture, '03-retained-motion-phase800ms');
      expect(
        difference(cached, await pixels(tester, capture)),
        greaterThan(10000),
        reason: 'Real path-following highlights, orbits and sculpture movement remain visible.',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'rapid size/theme/DPR replacement bounds allocations and disposes obsolete completions and retained images',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final created = <ui.Image>[], live = <ui.Image>{};
      var peakTextures = 0;
      final previousCreate = ui.Image.onCreate,
          previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        created.add(image);
        live.add(image);
        final resources = <ui.Image>[];
        for (final handle in live) {
          if (!resources.any(handle.isCloneOf)) resources.add(handle);
        }
        peakTextures = math.max(peakTextures, resources.length);
      };
      ui.Image.onDispose = (image) {
        live.remove(image);
        previousDispose?.call(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      });
      final firstGenerated = Completer<ui.Image>(),
          releaseFirst = Completer<void>();
      var generation = 0;
      Future<ui.Image> rasterize(
        ui.Picture picture,
        int width,
        int height,
      ) async {
        final image = await picture.toImage(width, height);
        if (generation++ == 0) {
          firstGenerated.complete(image);
          await releaseFirst.future;
        }
        return image;
      }

      final scene = GlobalKey();
      await tester.pumpWidget(
        _host(
          scene: AuroraScene(key: scene, rasterizeStatic: rasterize),
          size: const Size(1800, 1000),
          dpr: 3,
        ),
      );
      final state = scene.currentState;
      final obsolete = (await tester.runAsync(() => firstGenerated.future))!;
      expect(find.byType(RawImage), findsNothing);
      await tester.pumpWidget(
        _host(
          scene: AuroraScene(key: scene, rasterizeStatic: rasterize),
          size: const Size(480, 320),
          dpr: 1,
          brightness: Brightness.light,
        ),
      );
      releaseFirst.complete();
      final current = await _texture(
        tester,
        where: (image) => image.width < 600 && image.height < 400,
      );
      expect(scene.currentState, same(state));
      expect(current.width, inInclusiveRange(480, 520));
      expect(current.height, inInclusiveRange(320, 360));
      expect(
        obsolete.debugDisposed,
        isTrue,
        reason: 'The actual native completion held across resize must be discarded.',
      );
      await tester.pumpWidget(
        _host(
          scene: AuroraScene(key: scene, rasterizeStatic: rasterize),
          size: const Size(480, 320),
          dpr: 3,
        ),
      );
      await _texture(
        tester,
        where: (image) => image.width > 600 && image.height > 400,
      );
      expect(
        current.debugDisposed,
        isTrue,
        reason:
            'Replacing a retained DPR/theme image releases its owner handle.',
      );
      for (final image in created) {
        expect(image.width * image.height, lessThanOrEqualTo(1048576));
        expect(image.width, lessThanOrEqualTo(2048));
        expect(image.height, lessThanOrEqualTo(2048));
      }
      expect(
        peakTextures,
        equals(2),
        reason: 'At most one retained texture and one replacement resource, excluding shared clones.',
      );
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 200 && live.isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(
        live,
        isEmpty,
        reason: 'Unmount must release retained/render clones and every obsolete completion.',
      );
      expect(created.every((image) => image.debugDisposed), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unmount before native completion releases its eventual image without setState or ticker',
    (tester) async {
      final generated = Completer<ui.Image>(), release = Completer<void>();
      Future<ui.Image> rasterize(
        ui.Picture picture,
        int width,
        int height,
      ) async {
        final image = await picture.toImage(width, height);
        generated.complete(image);
        await release.future;
        return image;
      }

      await tester.pumpWidget(
        _host(scene: AuroraScene(rasterizeStatic: rasterize)),
      );
      final pending = (await tester.runAsync(() => generated.future))!;
      await tester.pumpWidget(const SizedBox());
      expect(tester.hasRunningAnimations, isFalse);
      release.complete();
      for (var i = 0; i < 200 && !pending.debugDisposed; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(pending.debugDisposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unavailable raster keeps luminous vector motion and never retries on each tick',
    (tester) async {
      var attempts = 0;
      Future<ui.Image> unavailable(
        ui.Picture picture,
        int width,
        int height,
      ) async {
        attempts++;
        throw StateError('Simulated unavailable decorative texture allocation');
      }

      final capture = GlobalKey();
      await tester.pumpWidget(
        _host(
          scene: RepaintBoundary(
            key: capture,
            child: AuroraScene(rasterizeStatic: unavailable),
          ),
        ),
      );
      final before = await pixels(tester, capture);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(attempts, 1);
      expect(find.byType(RawImage), findsNothing);
      expect(
        difference(before, await pixels(tester, capture)),
        greaterThan(10000),
      );
      await tester.pumpWidget(
        _host(
          scene: RepaintBoundary(
            key: capture,
            child: AuroraScene(rasterizeStatic: unavailable),
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pump();
      expect(
        attempts,
        2,
        reason: 'A changed theme may make one fresh allocation attempt.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'reduced or disabled first scene uses original still art without allocating ambient textures',
    (tester) async {
      await tester.pumpWidget(_host(scene: const AuroraScene(), reduce: true));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RawImage), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_host(scene: const AuroraScene(animated: false)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RawImage), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
