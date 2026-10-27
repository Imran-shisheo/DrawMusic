import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/export/domain/midi.dart';

class _MidiEvent {
  const _MidiEvent(this.tick, this.status, this.data);
  final int tick, status;
  final List<int> data;
  int get channel => status & 15;
  int get kind => status & 0xf0;
}

/// Standard SMF0 parser with variable-length delta times, metadata and running
/// status. Does not use the encoder's event builder/channel helper/program list.
List<_MidiEvent> _readMidi(Uint8List bytes) {
  final header = ByteData.sublistView(bytes);
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'MThd');
  expect(header.getUint32(4), 6);
  expect(header.getUint16(8), 0);
  expect(header.getUint16(10), 1);
  expect(header.getUint16(12), 480);
  expect(String.fromCharCodes(bytes.sublist(14, 18)), 'MTrk');
  expect(header.getUint32(18), bytes.length - 22);
  var at = 22, tick = 0, running = 0;
  final events = <_MidiEvent>[];
  int vlq() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      final b = bytes[at++];
      value = (value << 7) | (b & 127);
      if (b < 128) return value;
    }
    throw const FormatException('Invalid MIDI delta');
  }

  while (at < bytes.length) {
    tick += vlq();
    var status = bytes[at++];
    if (status < 128) {
      at--;
      status = running;
    } else if (status < 0xf0) {
      running = status;
    }
    if (status == 0xff) {
      final type = bytes[at++], size = vlq();
      final payload = bytes.sublist(at, at + size);
      at += size;
      events.add(_MidiEvent(tick, 0xff, [type, ...payload]));
      if (type == 0x2f) {
        expect(size, 0);
        expect(at, bytes.length);
        break;
      }
    } else {
      expect(status, inInclusiveRange(0x80, 0xef));
      final count = (status & 0xe0) == 0xc0 ? 1 : 2;
      final data = bytes.sublist(at, at + count);
      at += count;
      expect(data.every((n) => n >= 0 && n < 128), isTrue);
      events.add(_MidiEvent(tick, status, data));
    }
  }
  return events;
}

void main() {
  test('independent MIDI parser verifies all13 voices, percussion, tempo, layer levels and exact event timing', () {
    var mix = const AccompanimentMix();
    mix = mix.withLayer(
      AccompanimentLayer.bass,
      const LayerMix(enabled: true, level: .6),
    );
    mix = mix.withLayer(
      AccompanimentLayer.arpeggio,
      const LayerMix(enabled: true, level: .7),
    );
    mix = mix.withLayer(
      AccompanimentLayer.drumKit,
      const LayerMix(enabled: true, level: .4),
    );
    // A distinct override must replace the kit kick, never duplicate it.
    mix = mix.withLayer(
      AccompanimentLayer.kick,
      const LayerMix(enabled: true, level: .8),
    );
    final doc = ProjectDocument(
      id: 'all-midi',
      tempo: 137,
      mix: mix,
      strokes: [
        for (final instrument in Instrument.values)
          Stroke(
            id: instrument.name,
            instrument: instrument,
            points: [InkPoint(0, 2 / 3), InkPoint(1, 2 / 3)],
          ),
      ],
    );
    final events = _readMidi(encodeMidi(compileScore(doc)));
    final tempo = events.singleWhere(
      (e) => e.status == 0xff && e.data.first == 0x51,
    );
    expect(
      (tempo.data[1] << 16) | (tempo.data[2] << 8) | tempo.data[3],
      437956,
    );
    expect(tempo.tick, 0);
    final programs = {
      for (final e in events.where((e) => e.kind == 0xc0))
        e.channel: e.data.single,
    };
    expect(programs, {
      0: 0,
      1: 12,
      2: 10,
      3: 89,
      4: 45,
      5: 73,
      6: 48,
      7: 14,
      8: 32,
      10: 80,
      11: 38,
      12: 24,
      13: 65,
      14: 32,
      15: 45,
    });
    expect(programs.containsKey(9), isFalse);
    final ons = events.where((e) => e.kind == 0x90).toList();
    final offs = events.where((e) => e.kind == 0x80).toList();
    expect(ons.length, 59);
    expect(offs.length, ons.length);
    for (final channel in [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13]) {
      final on = ons.singleWhere((e) => e.channel == channel);
      final off = offs.singleWhere((e) => e.channel == channel);
      expect(on.tick, 0);
      expect(on.data, [60, 100]);
      expect(off.tick, 3840);
      expect(off.data, [60, 0]);
    }
    final bass = ons.where((e) => e.channel == 14).toList();
    expect(bass.map((e) => e.tick), [0, 960, 1920, 2880]);
    expect(bass.every((e) => e.data[0] == 36 && e.data[1] == 60), isTrue);
    final arp = ons.where((e) => e.channel == 15).toList();
    expect(arp.map((e) => e.tick), [for (var b = 0; b < 16; b++) b * 240]);
    expect(arp.take(5).map((e) => e.data[0]), [60, 62, 64, 67, 69]);
    expect(arp.every((e) => e.data[1] == 70), isTrue);
    final drums = ons.where((e) => e.channel == 9).toList();
    expect(drums.length, 26);
    for (final (pitch, ticks, level) in [
      (36, [0, 960, 1920, 2880], 80),
      (38, [480, 1440, 2400, 3360], 40),
      (39, [1440, 3360], 40),
      (42, [for (var b = 0; b < 16; b++) b * 240], 40),
    ]) {
      final voice = drums.where((e) => e.data[0] == pitch).toList();
      expect(voice.map((e) => e.tick), ticks);
      expect(voice.every((e) => e.data[1] == level), isTrue);
    }
    // Simulate standard MIDI note lifetime ownership: the arpeggio's early
    // note-off cannot terminate the held drawn pluck (same pitch, other lane).
    expect(
      offs.any((e) => e.channel == 15 && e.data[0] == 60 && e.tick == 160),
      isTrue,
    );
    expect(
      offs.singleWhere((e) => e.channel == 4 && e.data[0] == 60).tick,
      3840,
    );
    expect(events.last.status, 0xff);
    expect(events.last.data, [0x2f]);
    expect(events.last.tick, 3840);
  });
  test(
    'zero gain/velocity and muted kit overrides produce no audible MIDI events',
    () {
      final direct = ScoreSnapshot(
        projectId: 'inaudible',
        revision: 0,
        tempo: 120,
        notes: const [
          ScoreNote(Instrument.keys, 60, 0, 12, gain: 0),
          ScoreNote(Instrument.keys, 62, 0, 12, velocity: 0),
        ],
      );
      expect(
        _readMidi(encodeMidi(direct))
            .where((e) => e.kind == 0x90 || e.kind == 0x80),
        isEmpty,
      );
      final mix = const AccompanimentMix()
          .withLayer(AccompanimentLayer.drumKit, const LayerMix(enabled: true))
          .withLayer(
            AccompanimentLayer.kick,
            const LayerMix(enabled: true, muted: true),
          );
      final events = _readMidi(
        encodeMidi(compileScore(ProjectDocument(id: 'muted-kit', mix: mix))),
      );
      expect(
        events.where(
          (e) => e.kind == 0x90 && e.channel == 9 && e.data[0] == 36,
        ),
        isEmpty,
      );
      expect(events.where((e) => e.kind == 0x90 && e.channel == 9).length, 22);
      expect(
        events.where((e) => e.kind == 0x90).every((e) => e.channel == 9),
        isTrue,
      );
    },
  );
}
