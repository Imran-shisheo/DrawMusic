import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

bool uiRenderedRouteAnchor(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null &&
      (!route.isCurrent ||
          (route.animation != null && route.animation!.value < 1))) {
    return false;
  }
  final box = context.findRenderObject();
  return box is RenderBox && box.attached && box.hasSize && !box.size.isEmpty;
}

/// Imperative context.push does not update the browser-style URL by default.
/// Inspect the actual canvas route, while excluding hidden/outgoing/modal state.
bool uiRenderedEditorAnchor(
  BuildContext canvasContext, {
  required bool hasPanel,
}) =>
    !hasPanel &&
    uiRenderedRouteAnchor(canvasContext) &&
    GoRouterState.of(canvasContext).uri.path.startsWith('/editor/');

/// Real platform insets and current laid-out controls must agree. Native IME
/// metrics can arrive before the framework has laid out the resized panel.
class UiImeOcclusionWitness {
  const UiImeOcclusionWitness({
    required this.physicalHeight,
    required this.physicalInset,
    required this.dpr,
    required this.field,
    required this.cancel,
    required this.focused,
    required this.cancelHitTestable,
    required this.mockInputRegistered,
  });
  final double physicalHeight, physicalInset, dpr;
  final Rect field, cancel;
  final bool focused, cancelHitTestable, mockInputRegistered;
  double get visibleBottom => (physicalHeight - physicalInset) / dpr;
  bool get ready =>
      dpr.isFinite &&
      dpr > 0 &&
      physicalInset > 100 &&
      visibleBottom.isFinite &&
      visibleBottom > 0 &&
      focused &&
      !mockInputRegistered &&
      cancelHitTestable &&
      [field, cancel].every(
        (rect) =>
            rect.isFinite &&
            !rect.isEmpty &&
            rect.top >= 0 &&
            rect.bottom <= visibleBottom,
      );
  Map<String, Object> toJson() => {
    'physicalHeight': physicalHeight,
    'physicalInset': physicalInset,
    'devicePixelRatio': dpr,
    'visibleLogicalBottom': visibleBottom,
    'fieldBounds': [field.left, field.top, field.width, field.height],
    'cancelBounds': [cancel.left, cancel.top, cancel.width, cancel.height],
    'focused': focused,
    'cancelHitTestable': cancelHitTestable,
    'mockInputRegistered': mockInputRegistered,
    'ready': ready,
  };
}

/// Diagnostic configuration identity, never a linear font-size assumption.
/// Android's nominal preference and the widget snapshot must both arrive.
class UiTextScaleWitness {
  UiTextScaleWitness({
    required TextScaler scaler,
    required this.platformNominal,
  }) : scalerType = scaler.runtimeType.toString(),
       scalerDescription = scaler.toString(),
       // SystemTextScaler snapshots this nominal value. The deprecated API is
       // required ONLY for diagnostic configuration matching, never arithmetic
       // or product layout. scale(fontSize) remains the actual font evidence.
       // ignore: deprecated_member_use
       snapshotNominal = scaler.textScaleFactor,
       scaledFonts = {
         for (final font in [10, 12, 14, 16, 20, 24, 32, 42])
           '$font': scaler.scale(font.toDouble()),
       };

  final double platformNominal, snapshotNominal;
  final String scalerType, scalerDescription;
  final Map<String, double> scaledFonts;

  bool matches(double requestedNominal) =>
      platformNominal.isFinite &&
      snapshotNominal.isFinite &&
      (platformNominal - requestedNominal).abs() < 0.01 &&
      (snapshotNominal - requestedNominal).abs() < 0.01;

  Map<String, Object> toJson() => {
    'platformNominalTextScaleFactor': platformNominal,
    'mediaQuerySnapshotNominalTextScaleFactor': snapshotNominal,
    'textScalerRuntimeType': scalerType,
    'textScalerDescription': scalerDescription,
    'actualScaledFonts': scaledFonts,
    'scope': 'Nominal platform preference and MediaQuery snapshot identity; actual font-size samples may be nonlinear. No scaler override.',
  };
}

/// Joins an expected-state framework witness to the EXACT engine frame's
/// raster completion. Old/in-flight frames and changed routes cannot qualify.
/// This is raster evidence, not an Android compositor/display guarantee.
class UiRasterEvidenceLedger {
  final Map<int, Map<String, int>> _witnesses = {};
  final Map<int, FrameTiming> _rasters = {};
  var _generation = 0;
  var _latestExpected = false;

  void reset() {
    _generation++;
    _latestExpected = false;
    _witnesses.clear();
    _rasters.clear();
  }

  void frameworkFrame({
    required int number,
    required bool expected,
    required int systemTimestampUs,
  }) {
    if (!expected) {
      _generation++;
      _latestExpected = false;
      _witnesses.clear();
      return;
    }
    _latestExpected = true;
    if (number < 0) return; // No guessing a frame identity from timestamps.
    _witnesses[number] = {
      'generation': _generation,
      'systemFrameTimestampUs': systemTimestampUs,
    };
    while (_witnesses.length > 64) {
      _witnesses.remove(_witnesses.keys.first);
    }
  }

  void rasterFrames(List<FrameTiming> frames) {
    for (final frame in frames) {
      if (frame.frameNumber >= 0) _rasters[frame.frameNumber] = frame;
    }
    while (_rasters.length > 64) {
      _rasters.remove(_rasters.keys.first);
    }
  }

  Map<String, Object>? evidence() {
    if (!_latestExpected) return null;
    final ids = _witnesses.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final id in ids) {
      final witness = _witnesses[id]!;
      final raster = _rasters[id];
      if (witness['generation'] != _generation || raster == null) continue;
      return {
        'matchedEngineFrameNumber': id,
        'postFrameSystemTimestampUs': witness['systemFrameTimestampUs']!,
        'rasterFrameNumber': raster.frameNumber,
        'rasterFinishWallUs': raster.timestampInMicroseconds(
          FramePhase.rasterFinishWallTime,
        ),
        'rasterDurationUs': raster.rasterDuration.inMicroseconds,
        'scope': 'Expected route/widget state witnessed in a real framework frame and exactly matched engine raster completion; compositor pixels still require inspection.',
      };
    }
    return null;
  }
}

/// Local to a screenshot, never active during the measured performance phases.
/// One real engine frame is explicitly requested so static/reduced-motion
/// states cannot deadlock waiting for animation. No clock/frame is fabricated.
class UiPresentationFence {
  UiPresentationFence(
    this.binding, {
    required this.isExpected,
    this.screenshotSnapshot,
    int Function()? frameNumberForTests,
  }) : _frameNumber =
           frameNumberForTests ??
           (() => binding.platformDispatcher.frameData.frameNumber);

  final SchedulerBinding binding;
  final bool Function() isExpected;
  final Map<String, Object> Function()? screenshotSnapshot;
  final Map<int, Map<String, Object>> _snapshots = {};
  final int Function() _frameNumber;
  final ledger = UiRasterEvidenceLedger();
  var _active = false;
  var _generation = 0;
  var frameworkWitnessCount = 0;
  void Function(List<FrameTiming>)? _timings;

  void start() {
    if (_active) throw StateError('Screenshot fence already active');
    _active = true;
    final generation = ++_generation;
    ledger.reset();
    _snapshots.clear();
    frameworkWitnessCount = 0;
    _timings = (frames) {
      if (_active && generation == _generation) ledger.rasterFrames(frames);
    };
    binding.addTimingsCallback(_timings!);
    void witness(Duration _) {
      if (!_active || generation != _generation) return;
      // Pinned engine hooks update FrameData after beginFrame and before
      // drawFrame; FrameTiming.frameNumber is the same recorder identity.
      final frameNumber = _frameNumber();
      ledger.frameworkFrame(
        number: frameNumber,
        expected: isExpected(),
        systemTimestampUs: binding.currentSystemFrameTimeStamp.inMicroseconds,
      );
      if (screenshotSnapshot != null && frameNumber >= 0) {
        _snapshots[frameNumber] = screenshotSnapshot!();
        while (_snapshots.length > 64) {
          _snapshots.remove(_snapshots.keys.first);
        }
      }
      frameworkWitnessCount++;
      binding.addPostFrameCallback(witness);
    }

    binding.addPostFrameCallback(witness);
    binding.scheduleFrame(); // Exactly one screenshot-only real frame request.
  }

  Future<Map<String, Object>> waitForRaster({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final watch = Stopwatch()..start();
    while (_active && watch.elapsed < timeout) {
      final result = ledger.evidence();
      if (result != null && isExpected()) {
        return {
          ...result,
          'matchedFrameworkSnapshot':
              ?_snapshots[result['matchedEngineFrameNumber']],
          'screenshotOnlyEngineFrameRequests': 1,
          'frameworkWitnessCount': frameworkWitnessCount,
          'fenceWaitUs': watch.elapsedMicroseconds,
        };
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException(
      'Expected screenshot state had no matching real raster completion '
      '(active=$_active, frameworkWitnesses=$frameworkWitnessCount).',
      timeout,
    );
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _generation++;
    binding.removeTimingsCallback(_timings!);
    _timings = null;
  }
}
