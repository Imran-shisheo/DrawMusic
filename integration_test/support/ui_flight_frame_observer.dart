import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Passive diagnostic observation. Never requests frames, changes animation
/// clocks or updates app state. Samples are framework state, not compositor FPS.
class UiFlightFrameObserver {
  UiFlightFrameObserver(this.binding, this.snapshot);

  final WidgetsBinding binding;
  final Map<String, Object?> Function() snapshot;
  final _clock = Stopwatch();
  final _first = <Map<String, Object?>>[];
  final _tail = <Map<String, Object?>>[];
  var _active = false;
  var _started = false;
  var _frames = 0;
  var _changes = 0;
  String? _previous;

  void start() {
    if (_started) throw StateError('One flight observation per instance');
    _started = true;
    _active = true;
    _clock.start();
    binding.addPostFrameCallback(_sample);
  }

  void _sample(Duration timestamp) {
    if (!_active) return;
    _frames++;
    Map<String, Object?> state;
    try {
      state = snapshot();
    } catch (error) {
      state = {'snapshotErrorType': error.runtimeType.toString()};
    }
    final signature = jsonEncode(state);
    if (signature != _previous) {
      _previous = signature;
      _changes++;
      final sample = <String, Object?>{
        'observationFrame': _frames,
        'engineFrameNumber': binding.platformDispatcher.frameData.frameNumber,
        'postFrameTimestampUs': timestamp.inMicroseconds,
        'systemFrameTimestampUs':
            binding.currentSystemFrameTimeStamp.inMicroseconds,
        'wallElapsedUs': _clock.elapsedMicroseconds,
        ...state,
      };
      if (_first.length < 64) {
        _first.add(sample);
      } else {
        _tail.add(sample);
        if (_tail.length > 16) _tail.removeAt(0);
      }
    }
    // A callback waits for a naturally scheduled frame; it does not schedule one.
    if (_active) binding.addPostFrameCallback(_sample);
  }

  Map<String, Object?> stop() {
    _active = false;
    _clock.stop();
    final samples = [..._first, ..._tail];
    return {
      'diagnosticOnly': true,
      'acceptanceEligible': false,
      'naturalFramesObserved': _frames,
      'stateChangesObserved': _changes,
      'stateChangesDroppedForBound': _changes - samples.length,
      'actualElapsedUs': _clock.elapsedMicroseconds,
      'scope': 'State changes observed after actual framework frames; no manual frame requests, animation-clock changes or presentation/smoothness acceptance.',
      'samples': samples,
    };
  }
}
