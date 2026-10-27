import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/immersive_surface.dart';

import '../integration_test/support/ui_static_backdrop_probe.dart';

Widget _host(
  GlobalKey backdrop,
  GlobalKey scaffold, {
  GlobalKey? capture,
  Widget body = const SizedBox.expand(),
}) {
  Widget scene = SceneBackdrop(
    key: backdrop,
    child: Scaffold(
      key: scaffold,
      backgroundColor: Colors.transparent,
      body: body,
    ),
  );
  if (capture != null) scene = RepaintBoundary(key: capture, child: scene);
  return MaterialApp(theme: ThemeData.dark(), home: scene);
}

Rect _viewport(WidgetTester tester) =>
    Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
Future<Uint8List> _pixels(WidgetTester tester, GlobalKey capture) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Uint8List.fromList(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }))!;

void main() {
  testWidgets(
    'solid diagnostic restores exact rendered gradient after an exception without remount',
    (tester) async {
      final backdrop = GlobalKey(),
          scaffold = GlobalKey<ScaffoldState>(),
          capture = GlobalKey();
      await tester.pumpWidget(_host(backdrop, scaffold, capture: capture));
      RenderDecoratedBox lookup() =>
          backdrop.currentContext!.findRenderObject()! as RenderDecoratedBox;
      final target = lookup();
      final before = await _pixels(tester, capture),
          state = scaffold.currentState;
      final scheduled = tester.binding.hasScheduledFrame;
      final probe = UiStaticBackdropProbe(
        target: target,
        lookupCurrentTarget: lookup,
        homeScaffold: scaffold.currentContext!.findRenderObject()! as RenderBox,
        viewport: _viewport(tester),
        expectedSurface: Theme.of(scaffold.currentContext!).colorScheme.surface,
      );
      expect(
        tester.binding.hasScheduledFrame,
        scheduled,
        reason: 'Inspection alone never requests a frame.',
      );
      final original = target.decoration;
      var caught = false, applied = false;
      try {
        probe.applySolid();
        await tester
            .pump(); // Unit test only; native probe uses natural frames.
        expect((target.decoration as BoxDecoration).gradient, isNull);
        expect(await _pixels(tester, capture), isNot(orderedEquals(before)));
        applied = true;
        throw StateError('Simulated B phase failure');
      } on StateError catch (error) {
        expect(error.message, 'Simulated B phase failure');
        caught = true;
      } finally {
        probe.restore();
      }
      await tester.pump();
      expect(caught, isTrue);
      expect(
        applied,
        isTrue,
        reason: 'The B pixels must actually change before exercising abort restoration.',
      );
      expect(target.decoration, same(original));
      expect(scaffold.currentState, same(state));
      expect(await _pixels(tester, capture), orderedEquals(before));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'wrong gradient owner surface or small target is rejected without altering it',
    (tester) async {
      final backdrop = GlobalKey(), scaffold = GlobalKey(), small = GlobalKey();
      final body = Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: DecoratedBox(
            key: small,
            decoration: const BoxDecoration(
              color: Colors.black,
              gradient: RadialGradient(colors: [Colors.red, Colors.blue]),
            ),
          ),
        ),
      );
      await tester.pumpWidget(_host(backdrop, scaffold, body: body));
      final root =
          backdrop.currentContext!.findRenderObject()! as RenderDecoratedBox;
      final wrong =
          small.currentContext!.findRenderObject()! as RenderDecoratedBox;
      final originalRoot = root.decoration, originalWrong = wrong.decoration;
      UiStaticBackdropProbe attempt(RenderDecoratedBox target, Color color) =>
          UiStaticBackdropProbe(
            target: target,
            lookupCurrentTarget: () => target,
            homeScaffold:
                scaffold.currentContext!.findRenderObject()! as RenderBox,
            viewport: _viewport(tester),
            expectedSurface: color,
          );
      expect(() => attempt(wrong, Colors.black), throwsStateError);
      expect(() => attempt(root, Colors.red), throwsStateError);
      expect(root.decoration, same(originalRoot));
      root.decoration = const BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
      );
      final linear = root.decoration;
      expect(() => attempt(root, Colors.black), throwsStateError);
      expect(root.decoration, same(linear));
      expect(wrong.decoration, same(originalWrong));
      root.decoration = originalRoot;
    },
  );
  testWidgets(
    'a framework-replaced render target fails closed without touching the replacement',
    (tester) async {
      final backdrop = GlobalKey(), scaffold = GlobalKey();
      await tester.pumpWidget(_host(backdrop, scaffold));
      var current =
          backdrop.currentContext!.findRenderObject()! as RenderDecoratedBox;
      final probe = UiStaticBackdropProbe(
        target: current,
        lookupCurrentTarget: () => current,
        homeScaffold: scaffold.currentContext!.findRenderObject()! as RenderBox,
        viewport: _viewport(tester),
        expectedSurface: Theme.of(scaffold.currentContext!).colorScheme.surface,
      );
      probe.applySolid();
      final replacementBackdrop = GlobalKey(),
          replacementScaffold = GlobalKey();
      await tester.pumpWidget(_host(replacementBackdrop, replacementScaffold));
      current =
          replacementBackdrop.currentContext!.findRenderObject()!
              as RenderDecoratedBox;
      final replacement = current.decoration;
      expect(() => probe.verify(solidMode: true), throwsStateError);
      expect(probe.restore, throwsStateError);
      expect(current.decoration, same(replacement));
      expect(
        (current.decoration as BoxDecoration).gradient,
        isA<RadialGradient>(),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('natural restoration observer never creates frames while idle', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final scheduled = tester.binding.hasScheduledFrame;
      final result = waitForNaturalProbeRasters(
        tester.binding,
        expected: () => true,
        timeout: const Duration(milliseconds: 25),
      );
      expect(tester.binding.hasScheduledFrame, scheduled);
      await expectLater(result, throwsA(isA<TimeoutException>()));
      expect(tester.binding.hasScheduledFrame, scheduled);
    });
  });
}
