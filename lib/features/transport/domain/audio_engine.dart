import 'dart:typed_data';

abstract interface class AudioEngine {
  Future<void> prepare(Int16List pcm);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<double> positionSeconds();
  Future<bool> isPlaying();
  Future<void> setVolume(double value);
}
