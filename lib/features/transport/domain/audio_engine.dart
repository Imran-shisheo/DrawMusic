import 'dart:typed_data';

enum UpdateBoundary { beat, loop }

class TransportStatus {
  const TransportStatus({
    required this.playing,
    required this.revision,
    required this.targetRevision,
    required this.fraction,
    required this.tempo,
  });
  final bool playing;
  final int revision, targetRevision, tempo;
  final double fraction;
}

abstract interface class AudioEngine {
  Future<void> prepare(Int16List pcm, {int revision = 0, int tempo = 120});
  Future<void> queue(
    Int16List pcm, {
    required int revision,
    required int tempo,
    required UpdateBoundary boundary,
  });
  Future<TransportStatus> status();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<double> positionSeconds();
  Future<bool> isPlaying();
  Future<void> setVolume(double value);
}
