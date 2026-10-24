import 'dart:io';

import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/export/domain/midi.dart';

void main(List<String> arguments) {
  final destination = arguments.isEmpty
      ? 'work/verification'
      : arguments.single;
  final document = ProjectDocument(
    id: 'independent-fixture',
    strokes: [
      Stroke(
        id: 'keys',
        instrument: Instrument.keys,
        points: [InkPoint(.1, .5), InkPoint(.6, .5)],
      ),
      Stroke(
        id: 'bell',
        instrument: Instrument.bell,
        points: [InkPoint(.7, .2), InkPoint(.9, .2)],
      ),
    ],
  );
  final score = compileScore(document);
  Directory(destination).createSync(recursive: true);
  File('$destination/original-loop.wav')
      .writeAsBytesSync(encodeWav(renderPcm(score)));
  File('$destination/original-loop.mid').writeAsBytesSync(encodeMidi(score));
  File('$destination/project.json').writeAsStringSync(document.encode());
  stdout.writeln(
    'Original fixture: ${score.notes.length} notes, ${score.loopSeconds} s loop + $exportTailSeconds s WAV tail.',
  );
}
