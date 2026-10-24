import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/composition/domain/score.dart';

void main() {
  test('eraser splits a sparse line into a genuine audible gap; undo restores score', () {
    final doc = ProjectDocument(
      id: 'erase',
      strokes: [
        Stroke(
          id: 'line',
          instrument: Instrument.keys,
          points: [InkPoint(.1, .5), InkPoint(.9, .5)],
        ),
      ],
    );
    final history = DocumentHistory(doc);
    final erased = eraseAt(doc.strokes, InkPoint(.5, .5), .08);
    expect(erased.length, 2);
    expect(erased.first.points.last.u, closeTo(.4, 1e-8));
    expect(erased.last.points.first.u, closeTo(.6, 1e-8));
    history.commit(doc.copyWith(strokes: erased));
    expect(compileScore(history.document).notes.length, 2);
    history.undo();
    expect(history.document.strokes.single.id, 'line');
    expect(compileScore(history.document).notes.length, 1);
    history.redo();
    expect(history.document.strokes.length, 2);
    history.undo();
    history.commit(history.document.copyWith(tempo: 130));
    expect(history.canRedo, isFalse);
  });
  test('empty erasing is a no-op and dots can be removed', () {
    final strokes = [
      Stroke(
        id: 'dot',
        instrument: Instrument.bell,
        points: [InkPoint(.3, .2)],
      ),
    ];
    expect(identical(eraseAt(strokes, InkPoint(.8, .8), .02), strokes), isTrue);
    expect(eraseAt(strokes, InkPoint(.3, .2), .02), isEmpty);
  });
  test('clear is reversible; history is bounded; documents reject nonfinite points', () {
    final doc = ProjectDocument(id: 'bounds');
    final history = DocumentHistory(doc);
    for (var i = 0; i < 120; i++) {
      history.commit(history.document.copyWith(title: 'Revision $i'));
    }
    for (var i = 0; i < 100; i++) {
      history.undo();
    }
    expect(history.canUndo, isFalse);
    expect(() => InkPoint(double.nan, .3), throwsFormatException);
    expect(
      () => doc.strokes.add(
        Stroke(id: 'x', instrument: Instrument.keys, points: [InkPoint(0, 0)]),
      ),
      throwsUnsupportedError,
    );
  });
}
