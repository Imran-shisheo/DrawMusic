import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'ui_presentation_fence.dart';

/// Diagnostic-only render-property transaction. No app state, layout, motion,
/// scheduler clock or production widget is replaced. The caller must first
/// identify the visible HomePage and its direct SceneBackdrop child.
class UiStaticBackdropProbe {
  UiStaticBackdropProbe({
    required this.target,
    required this.lookupCurrentTarget,
    required this.homeScaffold,
    required this.viewport,
    required Color expectedSurface,
  }) {
    _checkGeometry();
    final decoration = target.decoration;
    if (decoration is! BoxDecoration ||
        decoration.gradient is! RadialGradient ||
        decoration.color != expectedSurface ||
        expectedSurface.a != 1 ||
        decoration.image != null ||
        decoration.border != null ||
        decoration.borderRadius != null ||
        decoration.boxShadow != null ||
        decoration.backgroundBlendMode != null ||
        decoration.shape != BoxShape.rectangle) {
      throw StateError(
        'Probe target is not the plain full Home radial backdrop',
      );
    }
    final radial = decoration.gradient! as RadialGradient;
    if (radial.center != const Alignment(.7, -.9) ||
        radial.radius != 1.1 ||
        radial.colors.length != 2 ||
        radial.stops?.length != 2 ||
        radial.stops!.first != 0 ||
        radial.stops!.last != 1) {
      throw StateError(
        'Probe target does not match SceneBackdrop radial geometry',
      );
    }
    original = decoration;
    // The constructor rejected every other decoration property: only the
    // gradient changes, and the already-existing opaque surface color remains.
    solid = BoxDecoration(color: decoration.color);
  }

  final RenderDecoratedBox target;
  final RenderDecoratedBox Function() lookupCurrentTarget;
  final RenderBox homeScaffold;
  final Rect viewport;
  late final BoxDecoration original, solid;

  Rect _bounds(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;
  void _checkGeometry() {
    if (!identical(lookupCurrentTarget(), target)) {
      throw StateError('The actual Home backdrop render target was replaced');
    }
    if (!target.attached ||
        !target.hasSize ||
        !homeScaffold.attached ||
        !homeScaffold.hasSize ||
        target.size.isEmpty ||
        viewport.isEmpty ||
        !viewport.isFinite) {
      throw StateError('Probe requires attached laid-out visible Home bounds');
    }
    var containsHome = false;
    for (RenderObject? node = homeScaffold; node != null; node = node.parent) {
      if (identical(node, target)) containsHome = true;
      if (node is RenderOffstage && node.offstage) {
        throw StateError('Probe cannot target an offstage branch');
      }
    }
    final bounds = _bounds(target), home = _bounds(homeScaffold);
    bool near(double a, double b) => (a - b).abs() <= .5;
    if (!containsHome ||
        !near(bounds.left, home.left) ||
        !near(bounds.top, home.top) ||
        !near(bounds.right, home.right) ||
        !near(bounds.bottom, home.bottom) ||
        !near(bounds.width, viewport.width) ||
        bounds.top < viewport.top - .5 ||
        bounds.bottom > viewport.bottom + .5 ||
        bounds.height < viewport.height * .5) {
      throw StateError(
        'Probe target is not the full visible Home Scaffold backdrop',
      );
    }
  }

  void verify({required bool solidMode}) {
    _checkGeometry();
    if (!identical(target.decoration, solidMode ? solid : original)) {
      throw StateError(
        'Backdrop probe decoration changed outside its transaction',
      );
    }
  }

  void applySolid() {
    verify(solidMode: false);
    target.decoration = solid; // Normal invalidation; no manual frame request.
    verify(solidMode: true);
  }

  void restore() {
    if (target.attached) target.decoration = original;
    // Re-resolve after a framework rebuild. Do not modify an unrelated new
    // render target or allow normal footage after an invalid transaction.
    verify(solidMode: false);
  }

  Map<String, Object> witness() {
    final bounds = _bounds(target);
    final radial = original.gradient! as RadialGradient;
    return {
      'target': 'visible HomePage direct SceneBackdrop RenderDecoratedBox',
      'logicalBounds': [bounds.left, bounds.top, bounds.width, bounds.height],
      'viewport': [
        viewport.left,
        viewport.top,
        viewport.width,
        viewport.height,
      ],
      'surfaceArgb': original.color!.toARGB32(),
      'gradientType': radial.runtimeType.toString(),
      'gradientCenter': [.7, -.9],
      'gradientRadius': radial.radius,
      'gradientArgb': radial.colors.map((color) => color.toARGB32()).toList(),
      'onlyDifference':
          'original radial gradient vs null; same opaque surface color',
    };
  }
}

/// Waits for two exact expected-state engine raster completions supplied by
/// natural Aurora frames. Unlike a screenshot fence, this never requests one.
Future<Map<String, Object>> waitForNaturalProbeRasters(
  SchedulerBinding binding, {
  required bool Function() expected,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final ledger = UiRasterEvidenceLedger(), matched = <int>{};
  final records = <Map<String, Object>>[];
  final watch = Stopwatch()..start();
  var active = true;
  void timing(List<FrameTiming> frames) => ledger.rasterFrames(frames);
  void frame(Duration _) {
    if (!active) return;
    ledger.frameworkFrame(
      number: binding.platformDispatcher.frameData.frameNumber,
      expected: expected(),
      systemTimestampUs: binding.currentSystemFrameTimeStamp.inMicroseconds,
    );
    binding.addPostFrameCallback(frame);
  }

  binding.addTimingsCallback(timing);
  binding.addPostFrameCallback(frame);
  try {
    while (watch.elapsed < timeout) {
      final evidence = ledger.evidence();
      if (evidence != null && expected()) {
        final id = evidence['rasterFrameNumber']! as int;
        if (matched.add(id)) records.add(evidence);
        if (matched.length >= 2) {
          return {
            'matchedNaturalFrames': records,
            'manualFrameRequests': 0,
            'waitUs': watch.elapsedMicroseconds,
          };
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException(
      'No two natural expected-state raster completions',
      timeout,
    );
  } finally {
    active = false;
    binding.removeTimingsCallback(timing);
    watch.stop();
  }
}
