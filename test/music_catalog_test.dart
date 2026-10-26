import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/export/domain/midi.dart';

ProjectDocument original() => ProjectDocument.decode(
  File('test/fixtures/project_v1_music.json').readAsStringSync(),
);
ProjectDocument voice(Instrument instrument) => original().copyWith(
  strokes: [original().strokes.single.copyWith(instrument: instrument)],
);
void main() {
  test('named families carry their declared chromatic intervals', () {
    const expected = {
      'major': [0, 2, 4, 7, 9],
      'minor': [0, 3, 5, 7, 10],
      'diatonicMajor': [0, 2, 4, 5, 7, 9, 11],
      'diatonicMinor': [0, 2, 3, 5, 7, 8, 10],
      'harmonicMinor': [0, 2, 3, 5, 7, 8, 11],
      'dorian': [0, 2, 3, 5, 7, 9, 10],
      'phrygian': [0, 1, 3, 5, 7, 8, 10],
      'lydian': [0, 2, 4, 6, 7, 9, 11],
      'mixolydian': [0, 2, 4, 5, 7, 9, 10],
      'blues': [0, 3, 5, 6, 7, 10],
      'chromatic': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    };
    for (final scale in MusicalScale.values) {
      expect(scale.intervals, expected[scale.name], reason: scale.label);
    }
  });
  test(
    'actual v1 source fixture keeps geometry, schema and exact PCM hashes',
    () {
      final source = original();
      final hashes = jsonDecode(
        File('test/fixtures/project_v1_pcm_hashes.json').readAsStringSync(),
      ) as Map;
      expect(source.formatVersion, 1);
      expect(source.soundVersion, 1);
      expect(source.toJson()['scale'], 'major');
      expect(source.toJson().containsKey('root'), isFalse);
      expect(compileScore(source).notes.single.fixture, [0, 67, 24, 72]);
      for (final instrument in Instrument.values.take(3)) {
        final doc = voice(instrument);
        expect(
          sha256.convert(encodeWav(renderPcm(compileScore(doc)))).toString(),
          hashes[instrument.name],
        );
      }
    },
  );
  test(
    '13 original stable roles produce deterministic distinct audible PCM',
    () {
      expect(Instrument.values.length, 13);
      expect(
        Instrument.values.map((i) => i.definition.role).toSet().length,
        13,
      );
      expect(
        Instrument.values.map((i) => i.definition.iconId).toSet().length,
        13,
      );
      expect(
        Instrument.values.map((i) => i.definition.color).toSet().length,
        13,
      );
      final hashes = <String>{};
      for (final instrument in Instrument.values) {
        final doc = voice(instrument);
        final score = compileScore(doc);
        final pcm = renderPcm(score);
        expect(pcm.length, 231525);
        final energy = pcm.skip(44100).fold<double>(0, (sum, p) => sum + p * p);
        expect(
          math.sqrt(energy / (pcm.length - 44100)),
          greaterThan(60),
          reason: instrument.name,
        );
        expect(pcm.every((p) => p.abs() < 32767), isTrue);
        hashes.add(sha256.convert(encodeWav(pcm)).toString());
        expect(
          ProjectDocument.decode(doc.encode()).strokes.single.instrument,
          instrument,
        );
        expect(
          compileScore(ProjectDocument.decode(doc.encode()))
              .notes
              .single
              .fixture,
          score.notes.single.fixture,
        );
      }
      expect(hashes.length, 13);
      final sax = compileScore(voice(Instrument.saxophone));
      expect(renderPcm(sax), orderedEquals(renderPcm(sax)));
    },
  );
  test('all roots and scale families constrain pitches, preserve geometry and determinism', () {
    expect(RootKey.values.length, 12);
    expect(MusicalScale.values.length, 11);
    final vertical = original().strokes.single.copyWith(
      points: [InkPoint(.4, .1), InkPoint(.4, .9)],
    );
    for (final root in RootKey.values) {
      for (final scale in MusicalScale.values) {
        final doc = original().copyWith(
          root: root,
          scale: scale,
          strokes: [vertical],
        );
        final score = compileScore(doc);
        final reopened = ProjectDocument.decode(doc.encode());
        expect(reopened.root, root);
        expect(reopened.scale, scale);
        expect(
          score.notes.map((n) => n.fixture).toList(),
          compileScore(reopened).notes.map((n) => n.fixture).toList(),
        );
        expect(
          score.notes.every(
            (n) =>
                n.pitch >= 48 &&
                n.pitch <= 84 &&
                scale.intervals.contains((n.pitch - 48 - root.index) % 12),
          ),
          isTrue,
        );
        expect(
          score.notes.every((n) => n.startBin == 38 && n.endBin == 39),
          isTrue,
        );
        expect(
          reopened.strokes.single.points.map((p) => p.toJson()),
          vertical.points.map((p) => p.toJson()),
        );
      }
    }
    expect(original().copyWith(root: RootKey.d).formatVersion, 2);
    expect(original().copyWith(root: RootKey.d).soundVersion, 2);
    expect(
      compileScore(original().copyWith(root: RootKey.cSharp))
          .notes
          .single
          .pitch,
      compileScore(original()).notes.single.pitch + 1,
    );
  });
  test('MIDI assigns all 13 melodic voices without percussion-channel collision', () {
    final doc = original().copyWith(
      strokes: [
        for (final i in Instrument.values)
          original().strokes.single.copyWith(id: i.name, instrument: i),
      ],
    );
    final score = compileScore(doc);
    final midi = encodeMidi(score);
    expect(midiChannel(Instrument.keys), 0);
    expect(midiChannel(Instrument.bell), 2);
    expect(Instrument.values.map(midiChannel).toSet().length, 13);
    expect(Instrument.values.map(midiChannel).contains(9), isFalse);
    // Independently walk the SMF track; do not infer notes from byte searches.
    final data = ByteData.sublistView(midi);
    expect(data.getUint32(18), midi.length - 22);
    var at = 22, tick = 0;
    final programs = <int, int>{};
    final on = <String>{};
    final off = <String>{};
    while (at < midi.length) {
      var delta = 0;
      int byte;
      do {
        byte = midi[at++];
        delta = (delta << 7) | (byte & 127);
      } while (byte & 128 != 0);
      tick += delta;
      final status = midi[at++];
      if (status == 255) {
        final type = midi[at++];
        final length = midi[at++];
        at += length;
        if (type == 47) break;
      } else if (status & 240 == 192) {
        programs[status & 15] = midi[at++];
      } else {
        final pitch = midi[at++], velocity = midi[at++];
        final key = '${status & 15}:$pitch';
        if (status & 240 == 144 && velocity > 0) {
          on.add(key);
        } else {
          off.add(key);
        }
      }
    }
    expect(tick, 3840);
    expect(on, off);
    expect(on.length, 13);
    for (final instrument in Instrument.values) {
      expect(
        programs[midiChannel(instrument)],
        instrument.definition.midiProgram,
      );
    }
  });
}
