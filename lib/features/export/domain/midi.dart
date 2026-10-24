import 'dart:typed_data';

import '../../composition/domain/score.dart';

const midiPrograms = [0, 12, 10]; // GM piano, marimba, music box; channels 1–3.
Uint8List encodeMidi(ScoreSnapshot score) {
  final events = <(int, int, List<int>)>[];
  final tempo = (60000000 / score.tempo).round();
  events.add((
    0,
    0,
    [0xff, 0x51, 3, (tempo >> 16) & 255, (tempo >> 8) & 255, tempo & 255],
  ));
  for (var c = 0; c < 3; c++) {
    events.add((0, 1, [0xc0 + c, midiPrograms[c]]));
  }
  for (final n in score.notes) {
    events.add((n.startBin * 40, 3, [0x90 + n.instrument.index, n.pitch, 100]));
    events.add((n.endBin * 40, 2, [0x80 + n.instrument.index, n.pitch, 0]));
  }
  events.add((3840, 4, [0xff, 0x2f, 0]));
  events.sort((a, b) {
    final tick = a.$1.compareTo(b.$1);
    return tick != 0 ? tick : a.$2.compareTo(b.$2);
  });
  List<int> vlq(int n) {
    final b = [n & 127];
    while ((n >>= 7) > 0) {
      b.insert(0, (n & 127) | 128);
    }
    return b;
  }

  final track = <int>[];
  var tick = 0;
  for (final event in events) {
    track.addAll(vlq(event.$1 - tick));
    track.addAll(event.$3);
    tick = event.$1;
  }
  final header = ByteData(22);
  for (var i = 0; i < 4; i++) {
    header.setUint8(i, 'MThd'.codeUnitAt(i));
    header.setUint8(i + 14, 'MTrk'.codeUnitAt(i));
  }
  header.setUint32(4, 6);
  header.setUint16(8, 0);
  header.setUint16(10, 1);
  header.setUint16(12, 480);
  header.setUint32(18, track.length);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...track]);
}
