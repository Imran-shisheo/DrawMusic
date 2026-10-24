import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';

ProjectDocument drawing(
  List<InkPoint> points, {
  Instrument instrument = Instrument.keys,
}) => ProjectDocument(
  id: 'fixture',
  strokes: [Stroke(id: 'line', instrument: instrument, points: points)],
);
List<List<int>> fixture(ProjectDocument d) =>
    compileScore(d).notes.map((n) => n.fixture).toList();
void main() {
  test('eight-beat mapping, duration, pitch, onset and dot', () {
    final line = drawing([InkPoint(.25, .5), InkPoint(.75, .5)]);
    expect(fixture(line), [
      [0, 67, 24, 72],
    ]);
    expect(compileScore(line).loopSeconds, 4);
    expect(compileScore(drawing([InkPoint(.5, .2)])).notes.single.startBin, 48);
    expect(
      compileScore(drawing([InkPoint(.25, .2), InkPoint(.5, .2)]))
          .notes
          .single
          .pitch,
      greaterThan(67),
    );
    expect(compileScore(drawing([InkPoint(1, 1)])).notes.single.fixture, [
      0,
      48,
      95,
      96,
    ]);
  });
  test('direction, drawing speed and collinear resampling invariance', () {
    final points = [InkPoint(.1, .2), InkPoint(.9, .8)];
    expect(
      fixture(drawing(points.reversed.toList())),
      fixture(drawing(points)),
    );
    final dense = [
      for (var i = 0; i <= 40; i++)
        InkPoint(.1 + .8 * i / 40, .2 + .6 * i / 40, i * 600),
    ];
    expect(fixture(drawing(dense)), fixture(drawing(points)));
  });
  test('vertical line is a short chord; circle preserves both branches', () {
    final vertical = compileScore(drawing([InkPoint(.5, 0), InkPoint(.5, 1)]));
    expect(vertical.notes.length, 16);
    expect(
      vertical.notes.every((n) => n.startBin == 48 && n.endBin == 49),
      isTrue,
    );
    final diamond = compileScore(
      drawing([
        InkPoint(.1, .5),
        InkPoint(.5, .1),
        InkPoint(.9, .5),
        InkPoint(.5, .9),
        InkPoint(.1, .5),
      ]),
    );
    expect(
      diamond.notes.where((n) => n.startBin <= 48 && n.endBin > 48).length,
      greaterThanOrEqualTo(2),
    );
  });
  test('same-instrument overlaps deduplicate and other instruments remain independent', () {
    final doc = drawing([InkPoint(.1, .5), InkPoint(.8, .5)]);
    expect(
      fixture(doc.copyWith(strokes: [...doc.strokes, ...doc.strokes])),
      fixture(doc),
    );
    expect(
      compileScore(
        doc.copyWith(
          strokes: [
            ...doc.strokes,
            Stroke(
              id: 'bell',
              instrument: Instrument.bell,
              points: doc.strokes.first.points,
            ),
          ],
        ),
      ).notes.length,
      2,
    );
  });
  test(
    'complex scene fails explicitly instead of silently dropping voices',
    () {
      final doc = ProjectDocument(
        id: 'complex',
        strokes: [
          for (final instrument in Instrument.values)
            Stroke(
              id: instrument.name,
              instrument: instrument,
              points: [InkPoint(.5, 0), InkPoint(.5, 1)],
            ),
        ],
      );
      expect(() => compileScore(doc), throwsA(isA<ScoreComplexityException>()));
    },
  );
}
