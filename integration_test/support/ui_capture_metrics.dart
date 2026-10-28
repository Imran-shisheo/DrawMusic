import 'dart:ui';

/// Real engine FrameTiming samples. Budget misses are not presentation-drop
/// counts; idle gaps are never mislabeled as dropped frames.
Map<String, Object> summarizeUiFrames(
  List<FrameTiming> frames,
  double refreshHz,
) {
  if (frames.isEmpty || !refreshHz.isFinite || refreshHz <= 0) {
    throw StateError('No real frame samples or valid display refresh rate');
  }
  final budgetUs = 1000000 / refreshHz;
  Map<String, Object> statistics(List<int> samples) {
    samples.sort();
    int percentile(double p) => samples[((samples.length - 1) * p).round()];
    return {
      'count': samples.length,
      'p50Us': percentile(.5),
      'p90Us': percentile(.9),
      'p95Us': percentile(.95),
      'p99Us': percentile(.99),
      'maxUs': samples.last,
      'overBudgetFrames': samples.where((value) => value > budgetUs).length,
    };
  }

  return {
    'scope': 'Profile-mode Flutter engine timings on an owned cloud emulator; not physical-device acceptance',
    'refreshHz': refreshHz,
    'frameBudgetUs': budgetUs,
    'uiBuild': statistics([
      for (final frame in frames) frame.buildDuration.inMicroseconds,
    ]),
    'raster': statistics([
      for (final frame in frames) frame.rasterDuration.inMicroseconds,
    ]),
    'totalSpan': statistics([
      for (final frame in frames) frame.totalSpan.inMicroseconds,
    ]),
    'eitherUiOrRasterOverBudgetFrames': frames
        .where(
          (frame) =>
              frame.buildDuration.inMicroseconds > budgetUs ||
              frame.rasterDuration.inMicroseconds > budgetUs,
        )
        .length,
    'presentationDroppedFrames': 'Not inferred from idle vsync gaps. See separate raw Android graphics evidence; Flutter timings alone do not measure actual display presentation drops.',
    'rawFrames': [
      for (final frame in frames)
        {
          'frameNumber': frame.frameNumber,
          'vsyncUs': frame.timestampInMicroseconds(FramePhase.vsyncStart),
          'rasterFinishWallUs': frame.timestampInMicroseconds(
            FramePhase.rasterFinishWallTime,
          ),
          'buildUs': frame.buildDuration.inMicroseconds,
          'rasterUs': frame.rasterDuration.inMicroseconds,
          'totalUs': frame.totalSpan.inMicroseconds,
        },
    ],
  };
}
