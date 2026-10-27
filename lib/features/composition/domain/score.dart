import 'dart:math' as math;

import '../../../creative_document/document.dart';
import 'accompaniment_score.dart';

class ScoreNote {
  const ScoreNote(
    this.instrument,
    this.pitch,
    this.startBin,
    this.endBin, {
    this.velocity = 100,
    this.gain = 1,
    this.percussion = false,
    this.midiChannelOverride,
  });
  final int velocity;
  final double gain;
  final bool percussion;
  // Independent accompaniment parts must not share a MIDI note-off namespace
  // with held drawing notes of the same instrument and pitch.
  final int? midiChannelOverride;
  final Instrument instrument;
  final int pitch, startBin, endBin;
  double get startBeat => startBin / 12;
  double get durationBeat => (endBin - startBin) / 12;
  List<int> get fixture => [instrument.index, pitch, startBin, endBin];
}

class ScoreSnapshot {
  ScoreSnapshot({
    required this.projectId,
    required this.revision,
    required this.tempo,
    required Iterable<ScoreNote> notes,
  }) : notes = List.unmodifiable(notes);
  final String projectId;
  final int revision, tempo;
  final List<ScoreNote> notes;
  double get loopSeconds => 480 / tempo;
}

class ScoreComplexityException implements Exception {
  @override
  String toString() =>
      'This drawing has too many overlapping notes. Erase a few marks and try again (32 voices / 4096 notes).';
}

ScoreSnapshot compileScore(ProjectDocument document) {
  final intervals = document.scale.intervals;
  final ceiling = [
    for (var p = 48; p <= 84; p++)
      if (intervals.contains((p - 48 - document.root.index) % 12)) p,
  ].last;
  final ladder = [
    for (var p = 48; p <= 84; p++)
      if (intervals.contains((p - 48) % 12))
        math.min(p + document.root.index, ceiling),
  ];
  final occupancy = <int, Set<int>>{};
  final velocities = <int, int>{};
  int pitchAt(double v) =>
      ((1 - v) * (ladder.length - 1)).round().clamp(0, ladder.length - 1);
  void occupy(
    Instrument instrument,
    int bin,
    double y0,
    double y1, [
    int velocity = 100,
  ]) {
    final low = math.min(pitchAt(y0), pitchAt(y1)),
        high = math.max(pitchAt(y0), pitchAt(y1));
    for (var pi = low; pi <= high; pi++) {
      final voice = instrument.index * 128 + ladder[pi];
      final key = voice * 96 + bin;
      velocities[key] = math.max(velocities[key] ?? 0, velocity);
      occupancy
          .putIfAbsent(instrument.index * 128 + ladder[pi], () => {})
          .add(bin);
    }
  }

  for (final stroke in document.strokes) {
    final velocity = document.expressionMode == ExpressionMode.expressive
        ? expressiveVelocity(stroke)
        : 100;
    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      occupy(
        stroke.instrument,
        (p.u * 96).floor().clamp(0, 95),
        p.v,
        p.v,
        velocity,
      );
    }
    for (var i = 1; i < stroke.points.length; i++) {
      var a = stroke.points[i - 1], b = stroke.points[i];
      if (a.u > b.u) {
        final temp = a;
        a = b;
        b = temp;
      }
      final dx = b.u - a.u;
      if (dx < 1e-12) {
        occupy(
          stroke.instrument,
          (a.u * 96).floor().clamp(0, 95),
          a.v,
          b.v,
          velocity,
        );
        continue;
      }
      final first = (a.u * 96).floor().clamp(0, 95),
          last = ((b.u * 96 - 1e-10).ceil() - 1).clamp(first, 95);
      for (var bin = first; bin <= last; bin++) {
        final t0 = ((bin / 96 - a.u) / dx).clamp(0.0, 1.0),
            t1 = (((bin + 1) / 96 - a.u) / dx).clamp(0.0, 1.0);
        occupy(
          stroke.instrument,
          bin,
          a.v + (b.v - a.v) * t0,
          a.v + (b.v - a.v) * t1,
          velocity,
        );
      }
    }
  }
  final notes = <ScoreNote>[];
  for (final entry in occupancy.entries) {
    final bins = entry.value.toList()..sort();
    var start = bins.first, end = start + 1;
    var velocity = velocities[entry.key * 96 + start] ?? 100;
    void emit() => notes.add(
      ScoreNote(
        Instrument.values[entry.key ~/ 128],
        entry.key % 128,
        start,
        end,
        velocity: velocity,
      ),
    );
    for (final bin in bins.skip(1)) {
      final nextVelocity = velocities[entry.key * 96 + bin] ?? 100;
      if (bin == end && nextVelocity == velocity) {
        end++;
      } else {
        emit();
        start = bin;
        end = bin + 1;
        velocity = nextVelocity;
      }
    }
    emit();
  }
  notes.addAll(accompanimentNotes(document));
  notes.sort((a, b) {
    final time = a.startBin.compareTo(b.startBin);
    if (time != 0) return time;
    final instrument = a.instrument.index.compareTo(b.instrument.index);
    return instrument != 0 ? instrument : a.pitch.compareTo(b.pitch);
  });
  final voices = List.filled(96, 0);
  for (final note in notes) {
    for (var b = note.startBin; b < note.endBin; b++) {
      voices[b]++;
    }
  }
  if (notes.length > 4096 || voices.any((n) => n > 32)) {
    throw ScoreComplexityException();
  }
  return ScoreSnapshot(
    projectId: document.id,
    revision: document.revision,
    tempo: document.tempo,
    notes: notes,
  );
}

// Explicit P2 policy: mean normalized pen travel per millisecond maps 0..0.001
// to MIDI55..110. Stylus pressure, when recorded, instead supplies 0..1 dynamics.
// Missing/zero timing keeps100. Geometry mode never reads input metadata.
int expressiveVelocity(Stroke stroke) {
  final pressures = stroke.points
      .where(
        (p) =>
            p.pressure != null &&
            (p.kind == InputKind.stylus || p.kind == InputKind.invertedStylus),
      )
      .map((p) => p.pressure!)
      .toList();
  if (pressures.isNotEmpty) {
    return (55 + 55 * pressures.reduce((a, b) => a + b) / pressures.length)
        .round()
        .clamp(55, 110);
  }
  if (stroke.points.length < 2) return 100;
  var distance = 0.0;
  for (var i = 1; i < stroke.points.length; i++) {
    final a = stroke.points[i - 1], b = stroke.points[i];
    distance += math.sqrt(math.pow(a.u - b.u, 2) + math.pow(a.v - b.v, 2));
  }
  final duration = (stroke.points.last.ms - stroke.points.first.ms).abs();
  if (duration == 0) return 100;
  return (55 + 55 * (distance / duration / .001).clamp(0, 1)).round().clamp(
    55,
    110,
  );
}
