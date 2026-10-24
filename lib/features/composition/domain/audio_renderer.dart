import 'dart:math' as math;
import 'dart:typed_data';

import '../../../creative_document/document.dart';
import 'score.dart';

// Original additive voices, version 1. No samples or reference-app media.
const sampleRate = 44100;
const releaseSeconds = .18;
const exportTailSeconds = 1.25;
Int16List renderPcm(ScoreSnapshot score, {bool loop = false}) {
  final loopFrames = (score.loopSeconds * sampleRate).round();
  final frames = loop
      ? loopFrames
      : loopFrames + (exportTailSeconds * sampleRate).round();
  final mix = Float64List(frames);
  for (final note in score.notes) {
    final start = (note.startBeat * 60 / score.tempo * sampleRate).round();
    final sustain = (note.durationBeat * 60 / score.tempo * sampleRate).round();
    final length = sustain + (releaseSeconds * sampleRate).round();
    final frequency = 440 * math.pow(2, (note.pitch - 69) / 12);
    for (var i = 0; i < length; i++) {
      final t = i / sampleRate;
      final phase = 2 * math.pi * frequency * t;
      final attack = math.min(1.0, i / (sampleRate * .008));
      final release = i < sustain
          ? 1.0
          : math.max(0.0, 1 - (i - sustain) / (sampleRate * releaseSeconds));
      final voice = switch (note.instrument) {
        Instrument.keys =>
          (math.sin(phase) +
                  .22 * math.sin(2 * phase) +
                  .08 * math.sin(3 * phase)) *
              math.exp(-1.5 * t),
        Instrument.mallet =>
          (math.sin(phase) + .3 * math.sin(4 * phase)) * math.exp(-5 * t),
        Instrument.bell =>
          (math.sin(phase) +
                  .35 * math.sin(2.76 * phase) +
                  .15 * math.sin(5.4 * phase)) *
              math.exp(-3 * t),
      };
      final index = loop ? (start + i) % loopFrames : start + i;
      if (index < frames) mix[index] += voice * attack * release * .13;
    }
  }
  return Int16List.fromList([
    for (final value in mix) ((value / (1 + value.abs())) * 30000).round(),
  ]);
}

Uint8List encodeWav(Int16List pcm) {
  final bytes = ByteData(44 + pcm.length * 2);
  void text(int at, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(at + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + pcm.length * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, pcm.length * 2, Endian.little);
  for (var i = 0; i < pcm.length; i++) {
    bytes.setInt16(44 + i * 2, pcm[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
