import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';

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
    int Function()? frameNumberForTests,
  }) : _frameNumber =
           frameNumberForTests ??
           (() => binding.platformDispatcher.frameData.frameNumber);

  final SchedulerBinding binding;
  final bool Function() isExpected;
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
    frameworkWitnessCount = 0;
    _timings = (frames) {
      if (_active && generation == _generation) ledger.rasterFrames(frames);
    };
    binding.addTimingsCallback(_timings!);
    void witness(Duration _) {
      if (!_active || generation != _generation) return;
      // Pinned engine hooks update FrameData after beginFrame and before
      // drawFrame; FrameTiming.frameNumber is the same recorder identity.
      ledger.frameworkFrame(
        number: _frameNumber(),
        expected: isExpected(),
        systemTimestampUs: binding.currentSystemFrameTimeStamp.inMicroseconds,
      );
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
