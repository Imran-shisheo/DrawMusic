import '../../../creative_document/document.dart';
import 'score.dart';

// Original patterns in the same 96-bin/eight-beat score as ink. No timers,
// separate player or preview-only audio can drift away from the native clock.
List<ScoreNote> accompanimentNotes(ProjectDocument d) {
  final mix = d.mix;
  final result = <ScoreNote>[];
  void melodic(
    AccompanimentLayer layer,
    Instrument instrument,
    int pitch,
    int start,
    int end,
  ) {
    final m = mix[layer];
    if (m.audible) {
      result.add(
        ScoreNote(
          instrument,
          pitch,
          start,
          end,
          gain: m.level,
          velocity: 100,
          midiChannelOverride: layer == AccompanimentLayer.bass ? 14 : 15,
        ),
      );
    }
  }

  for (var b = 0; b < 96; b += 24) {
    melodic(
      AccompanimentLayer.bass,
      Instrument.bass,
      36 + d.root.index,
      b,
      b + 18,
    );
  }
  final degrees = d.scale.intervals;
  for (var b = 0; b < 96; b += 6) {
    melodic(
      AccompanimentLayer.arpeggio,
      Instrument.pluck,
      60 + d.root.index + degrees[(b ~/ 6) % degrees.length],
      b,
      b + 4,
    );
  }
  const patterns = {
    AccompanimentLayer.kick: (36, [0, 24, 48, 72]),
    AccompanimentLayer.snare: (38, [12, 36, 60, 84]),
    AccompanimentLayer.clap: (39, [36, 84]),
    AccompanimentLayer.hiHat: (
      42,
      [0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72, 78, 84, 90],
    ),
  };
  for (final entry in patterns.entries) {
    // An explicitly enabled individual control overrides the kit voice,
    // including its mute. Otherwise kit supplies that voice exactly once.
    final individual = mix[entry.key];
    final effective = individual.enabled
        ? individual
        : mix[AccompanimentLayer.drumKit];
    if (!effective.audible) continue;
    for (final bin in entry.value.$2) {
      result.add(
        ScoreNote(
          Instrument.chip,
          entry.value.$1,
          bin,
          bin + 1,
          gain: effective.level,
          velocity: 100,
          percussion: true,
        ),
      );
    }
  }
  return result;
}
