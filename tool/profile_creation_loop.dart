// Original synthetic geometry. Cloud CPU diagnostics, not phone FPS evidence.
import 'dart:io';

import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/composition/domain/score.dart';

void main() {
  final document = ProjectDocument(
    id: 'profile_100k',
    strokes: List.generate(
      100,
      (s) => Stroke(
        id: 'stroke_$s',
        instrument: Instrument.values[s % 3],
        points: List.generate(
          1000,
          (p) => InkPoint(p / 999, .1 + (s % 20) / 100, p),
        ),
      ),
    ),
  );
  void measure(String label, void Function() action) {
    action();
    final samples = <int>[];
    for (var i = 0; i < 7; i++) {
      final clock = Stopwatch()..start();
      action();
      samples.add(clock.elapsedMicroseconds);
    }
    samples.sort();
    stdout.writeln(
      '$label median_us=${samples[3]} points=${document.pointCount}',
    );
  }

  measure('history_12_titles', () {
    final history = DocumentHistory(document);
    for (var i = 0; i < 12; i++) {
      history.commit(history.document.copyWith(title: 'Name $i'));
    }
  });
  measure('erase_20_misses', () {
    for (var i = 0; i < 20; i++) {
      eraseAt(document.strokes, InkPoint(.5, .9), .01);
    }
  });
  measure('compile_score', () {
    compileScore(document);
  });
  measure('encode', () {
    document.encode();
  });
}
