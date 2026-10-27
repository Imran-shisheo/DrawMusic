import 'dart:typed_data';

import '../../../creative_document/document.dart';
import '../../composition/domain/score.dart';

const midiPrograms = [0, 12, 10, 89, 45, 73, 48, 14, 32, 80, 38, 24, 65];
// Channel 10 (zero-based 9) is reserved for percussion, never melodic voices.
int midiChannel(Instrument instrument) =>
    instrument.index < 9 ? instrument.index : instrument.index + 1;
Uint8List encodeMidi(ScoreSnapshot score) {
  final events = <(int, int, List<int>)>[];
  final tempo = (60000000 / score.tempo).round();
  events.add((
    0,
    0,
    [0xff, 0x51, 3, (tempo >> 16) & 255, (tempo >> 8) & 255, tempo & 255],
  ));
  for (final instrument in Instrument.values) {
    events.add((
      0,
      1,
      [0xc0 + midiChannel(instrument), midiPrograms[instrument.index]],
    ));
  }
  // Two free melodic channels isolate bass/arpeggio note lifetimes from ink.
  // They use the same GM substitutions as their PCM instrument definitions.
  for (final (channel, program) in [(14, 32), (15, 45)]) {
    if (score.notes.any(
      (n) =>
          !n.percussion &&
          n.midiChannelOverride == channel &&
          n.gain > 0 &&
          n.velocity > 0,
    )) {
      events.add((0, 1, [0xc0 + channel, program]));
    }
  }
  for (final n in score.notes) {
    if (n.gain <= 0 || n.velocity <= 0) continue;
    final channel = n.percussion
        ? 9
        : n.midiChannelOverride ?? midiChannel(n.instrument);
    if (channel < 0 ||
        channel > 15 ||
        (!n.percussion && channel == 9) ||
        !n.gain.isFinite) {
      throw const FormatException('Invalid MIDI part');
    }
    events.add((
      n.startBin * 40,
      3,
      [0x90 + channel, n.pitch, (n.velocity * n.gain).round().clamp(1, 127)],
    ));
    events.add((n.endBin * 40, 2, [0x80 + channel, n.pitch, 0]));
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
