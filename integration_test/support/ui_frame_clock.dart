import 'package:flutter/scheduler.dart';

/// Passive observation of real framework frames. Registering a post-frame
/// callback never requests a frame or changes animation/scheduler clocks.
class UiFrameClockObserver {
  UiFrameClockObserver(this.binding);

  final SchedulerBinding binding;
  final Stopwatch _elapsed = Stopwatch();
  int _generation = 0;
  bool _active = false;
  int observedPostFrames = 0;
  Map<String, int>? latest;

  void start() {
    if (_active) return;
    _active = true;
    final generation = ++_generation;
    latest = null;
    observedPostFrames = 0;
    _elapsed
      ..reset()
      ..start();
    void observe(Duration _) {
      if (!_active || generation != _generation) return;
      // currentFrameTimeStamp is only valid during an actual frame. Pollers
      // read this nullable cache later, never the scheduler getter at idle.
      latest = {
        'currentFrameTimeStampUs': binding.currentFrameTimeStamp.inMicroseconds,
        'currentSystemFrameTimeStampUs':
            binding.currentSystemFrameTimeStamp.inMicroseconds,
        'postFrameObserverElapsedUs': _elapsed.elapsedMicroseconds,
        'postFrameDateTimeWallUs': DateTime.now().microsecondsSinceEpoch,
      };
      observedPostFrames++;
      binding.addPostFrameCallback(observe);
    }

    binding.addPostFrameCallback(observe);
  }

  void stop() {
    _active = false;
    _generation++;
    _elapsed.stop();
    // At most one already-queued callback remains. Its generation guard makes
    // it a no-op; no persistent callback or synthetic frame remains running.
  }
}
