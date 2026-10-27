import 'dart:math' as math;
import 'dart:typed_data';

import '../../../creative_document/document.dart';
import 'score.dart';

// Original synthesis voices. The first three preserve engine-v1 PCM exactly.
// No samples, recordings or reference-app media. See docs/MUSIC-CATALOG.md.
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
      // Band-limited harmonic sums avoid deliberate Nyquist folding. Each
      // original voice has its own excitation, spectrum and envelope.
      double harmonics(
        int count,
        double Function(int) amplitude, {
        double detune = 1,
      }) {
        var sum = 0.0;
        for (var harmonic = 1; harmonic <= count; harmonic++) {
          if (frequency * harmonic * detune >= sampleRate / 2) break;
          sum += amplitude(harmonic) * math.sin(phase * harmonic * detune);
        }
        return sum;
      }

      double saturate(double x) => 2 / (1 + math.exp(-2 * x)) - 1;
      final voice = note.percussion
          ? _percussion(note.pitch, t)
          : switch (note.instrument) {
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
              Instrument.warmSynth =>
                (harmonics(12, (h) => 1 / (h * h)) +
                        .32 * harmonics(9, (h) => 1 / (h * h), detune: 1.004)) *
                    (1 - math.exp(-24 * t)) *
                    .72,
              Instrument.pluck =>
                harmonics(
                      16,
                      (h) => math.sin(h * .61) * math.exp(-h * t * 2.6) / h,
                    ) *
                    math.exp(-2.8 * t),
              Instrument.flute =>
                (math.sin(phase + .025 * math.sin(2 * math.pi * 5 * t)) +
                        .09 * math.sin(2 * phase) +
                        .025 *
                            math.sin(phase * 7.13) *
                            math.sin(phase * 3.71)) *
                    (1 - math.exp(-34 * t)) *
                    .85,
              Instrument.strings =>
                (harmonics(14, (h) => (h.isOdd ? 1.0 : .55) / h) +
                        .35 * harmonics(12, (h) => 1 / h, detune: .997)) *
                    (1 - math.exp(-9 * t)) *
                    .49,
              Instrument.chime =>
                (math.sin(phase) * math.exp(-2 * t) +
                    .5 * math.sin(phase * 2.01) * math.exp(-5 * t) +
                    .3 * math.sin(phase * 3.9) * math.exp(-7 * t) +
                    .18 * math.sin(phase * 6.15) * math.exp(-12 * t)),
              Instrument.bass =>
                (math.sin(phase) +
                        .38 * math.sin(2 * phase) * math.exp(-6 * t) +
                        .12 * math.sin(3 * phase) * math.exp(-12 * t)) *
                    math.exp(-1.9 * t),
              Instrument.chip =>
                harmonics(15, (h) => h.isOdd ? 1 / h : 0) *
                    (t < .04 ? 1.0 : .58) *
                    .8,
              Instrument.electronicBass =>
                saturate(
                      2.2 *
                          (math.sin(
                                phase +
                                    1.6 *
                                        math.exp(-9 * t) *
                                        math.sin(2 * phase),
                              ) +
                              .15 * math.sin(3 * phase)),
                    ) *
                    math.exp(-1.2 * t) *
                    .7,
              Instrument.guitar =>
                harmonics(
                      18,
                      (h) =>
                          math.sin(h * .38) *
                          math.sin(h * 1.1) *
                          math.exp(-(1 + h * h * .13) * t) /
                          h,
                    ) *
                    1.4,
              Instrument.saxophone =>
                (harmonics(
                          12,
                          (h) =>
                              (h.isOdd ? 1.0 : .7) *
                              math.exp(-h * .12) /
                              math.sqrt(h),
                        ) +
                        .12 *
                            math.sin(
                              phase + .07 * math.sin(2 * math.pi * 5.2 * t),
                            )) *
                    (1 - math.exp(-28 * t)) *
                    .55,
            };
      final index = loop ? (start + i) % loopFrames : start + i;
      if (index < frames) {
        mix[index] +=
            voice * attack * release * .13 * (note.velocity / 100) * note.gain;
      }
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

// Deterministic original drum excitations: falling sine kick, noise/snare body,
// three delayed noise clap bursts and metallic six-partial closed hat.
double _percussion(int pitch, double t) {
  final noise =
      (math.sin((t * sampleRate + 1) * 12.9898 + pitch * 78.233) * 43758.5453);
  final white = (noise - noise.floor()) * 2 - 1;
  return switch (pitch) {
    36 =>
      math.sin(2 * math.pi * (48 * t + 3 * (1 - math.exp(-28 * t)))) *
          math.exp(-18 * t) *
          1.8,
    38 =>
      (white * .8 + math.sin(2 * math.pi * 180 * t) * .3) * math.exp(-24 * t),
    39 =>
      white *
          (math.exp(-70 * t) +
              (t > .012 ? math.exp(-70 * (t - .012)) : 0) +
              (t > .025 ? math.exp(-35 * (t - .025)) : 0)) *
          .6,
    _ =>
      (white * .3 +
              math.sin(2 * math.pi * 4100 * t) *
                  math.sin(2 * math.pi * 6203 * t)) *
          math.exp(-65 * t),
  };
}
