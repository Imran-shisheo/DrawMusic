import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/editor/domain/simplification.dart';

List<List<int>> score(ProjectDocument document) => [
  for (final note in compileScore(document).notes) note.fixture,
];

void main() {
  test('dense curves simplify within reference tolerance with exact score and reverse invariance', () {
    final points = List.generate(20000, (i) {
      final u = .05 + .9 * i / 19999;
      return InkPoint(u, .5 + .25 * math.sin(u * math.pi * 2), i);
    });
    final stroke = Stroke(
      id: 'curve',
      instrument: Instrument.keys,
      points: points,
    );
    final document = ProjectDocument(id: 'dense-curve', strokes: [stroke]);
    final simplified = simplifyGeometry(document);
    expect(simplified.changed, isTrue);
    expect(simplified.after, lessThan(1000));
    final result = document.copyWith(strokes: simplified.strokes);
    expect(score(result), score(document));
    final reverse = simplifyGeometry(
      document.copyWith(strokes: [stroke.copyWith(points: points.reversed)]),
    );
    expect(
      reverse.strokes.single.points.map((p) => p.toJson()).toList(),
      simplified.strokes.single.points.reversed.map((p) => p.toJson()).toList(),
    );
    // Evaluate distance to the replacement in the declared fixed document
    // coordinates. This bound says nothing about physical-device FPS or RSS.
    for (final p in points) {
      var distance = double.infinity;
      final line = simplified.strokes.single.points;
      for (var i = 1; i < line.length; i++) {
        final a = line[i - 1], b = line[i];
        if (p.u < a.u || p.u > b.u) continue;
        final dx = (b.u - a.u) * 800, dy = (b.v - a.v) * 1000;
        final px = (p.u - a.u) * 800, py = (p.v - a.v) * 1000;
        final t = ((px * dx + py * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
        distance = math.min(
          distance,
          math.sqrt(math.pow(px - t * dx, 2) + math.pow(py - t * dy, 2)),
        );
      }
      expect(distance, lessThanOrEqualTo(.750001));
    }
    expect(score(ProjectDocument.decode(result.encode())), score(document));
  });

  test('dots, corners, vertical chords and erased gaps remain meaningful', () {
    final dot = Stroke(
      id: 'dot',
      instrument: Instrument.bell,
      points: [InkPoint(.2, .7)],
    );
    final vertical = Stroke(
      id: 'vertical',
      instrument: Instrument.keys,
      points: List.generate(10000, (i) => InkPoint(.5, .2 + .6 * i / 9999)),
    );
    final corner = Stroke(
      id: 'corner',
      instrument: Instrument.mallet,
      points: [
        for (var i = 0; i < 5000; i++)
          InkPoint(.05 + .3 * i / 4999, .2 + .5 * i / 4999),
        for (var i = 0; i < 5000; i++)
          InkPoint(.35 + .3 * i / 4999, .7 - .5 * i / 4999),
      ],
    );
    final doc = ProjectDocument(id: 'shapes', strokes: [dot, vertical, corner]);
    final result = simplifyGeometry(doc);
    expect(result.changed, isTrue);
    expect(identical(result.strokes.first, dot), isTrue);
    expect(result.strokes[1].points.length, 2);
    expect(
      result.strokes[2].points.any((p) => p.u == .35 && p.v == .7),
      isTrue,
    );
    expect(score(doc.copyWith(strokes: result.strokes)), score(doc));
    final erased = eraseAt(result.strokes, InkPoint(.5, .5), .08);
    final erasedOriginal = eraseAt(doc.strokes, InkPoint(.5, .5), .08);
    expect(
      score(doc.copyWith(strokes: erased)),
      score(doc.copyWith(strokes: erasedOriginal)),
    );
    final history = DocumentHistory(doc);
    history.commit(doc.copyWith(strokes: result.strokes));
    history.undo();
    expect(identical(history.document.strokes[1], vertical), isTrue);
    history.redo();
    expect(history.document.pointCount, result.after);
  });

  test('work exhaustion and unsafe score preserve original strokes; pixel cells stay exact', () {
    final curve = Stroke(
      id: 'bounded',
      instrument: Instrument.keys,
      points: List.generate(2000, (i) => InkPoint(i / 1999, .5)),
    );
    final doc = ProjectDocument(id: 'bounded', strokes: [curve]);
    final exhausted = simplifyGeometry(doc, maxDistanceChecks: 1);
    expect(exhausted.changed, isFalse);
    expect(identical(exhausted.strokes, doc.strokes), isTrue);
    final pixel = simplifyGeometry(doc.copyWith(style: DrawingStyle.pixel));
    expect(pixel.strokes.single.displayPixels, curve.displayPixels);
    final unsafe = ProjectDocument(
      id: 'unsafe',
      strokes: [
        for (final instrument in Instrument.values.take(3))
          Stroke(
            id: instrument.name,
            instrument: instrument,
            points: List.generate(500, (i) => InkPoint(.5, i / 499)),
          ),
      ],
    );
    expect(
      () => compileScore(unsafe),
      throwsA(isA<ScoreComplexityException>()),
    );
    // Deduplication cannot repair genuine >32-voice scenes. The caller still
    // receives an explicit complexity error; no note, instrument or stroke drops.
    final preserved = simplifyGeometry(unsafe);
    expect(preserved.strokes.length, unsafe.strokes.length);
    expect(
      () => compileScore(unsafe.copyWith(strokes: preserved.strokes)),
      throwsA(isA<ScoreComplexityException>()),
    );
  });

  test(
    'history charges shared geometry once and bounds both command directions',
    () {
      final stroke = Stroke(
        id: 'shared',
        instrument: Instrument.keys,
        points: List.generate(100000, (i) => InkPoint(i / 99999, .5)),
      );
      final history = DocumentHistory(
        ProjectDocument(id: 'shared', strokes: [stroke]),
      );
      for (var i = 0; i < 110; i++) {
        history.commit(history.document.copyWith(title: 'Edit $i'));
      }
      expect(history.undoCount, 100);
      expect(history.memory.currentDocumentBytes, greaterThan(7000000));
      expect(history.memory.retainedBytes, lessThan(200000));
      for (var i = 0; i < 40; i++) {
        history.undo();
      }
      expect(history.undoCount + history.redoCount, 100);
      expect(history.memory.retainedBytes, lessThanOrEqualTo(20 * 1024 * 1024));
      expect(identical(history.document.strokes.single, stroke), isTrue);
    },
  );

  test(
    'automatic simplification declines when its Undo snapshot cannot fit',
    () {
      final source = ProjectDocument(
        id: 'many-dense-strokes',
        strokes: [
          for (var n = 0; n < 200; n++)
            Stroke(
              id: 'dense-$n',
              instrument: Instrument.keys,
              points: List.generate(
                500,
                (i) => InkPoint(.1 + .01 * i / 499, .5),
              ),
            ),
        ],
      );
      final small = source.copyWith(
        strokes: [
          for (final stroke in source.strokes)
            stroke.copyWith(points: [stroke.points.first, stroke.points.last]),
        ],
      );
      expect(
        additionalHistoryBytes(source, small),
        greaterThan(historyMemoryBudgetBytes),
      );
      final attempted = simplifyGeometry(source);
      expect(attempted.changed, isFalse);
      expect(identical(attempted.strokes, source.strokes), isTrue);
      expect(score(source.copyWith(strokes: attempted.strokes)), score(source));
    },
  );

  test('exclusive geometry and reserved lazy caches evict history without modifying current', () {
    final history = DocumentHistory(ProjectDocument(id: 'memory'));
    for (var n = 0; n < 5; n++) {
      final stroke = Stroke(
        id: 'revision-$n',
        instrument: Instrument.keys,
        points: List.generate(100000, (i) => InkPoint(i / 99999, .1 + n * .1)),
      );
      history.commit(history.document.copyWith(strokes: [stroke]));
    }
    expect(history.undoCount, lessThan(5));
    expect(history.memory.retainedBytes, lessThanOrEqualTo(20 * 1024 * 1024));
    final current = history.document;
    // Materializing lazy caches was reserved before the allocation.
    final accounted = history.memory.retainedBytes;
    for (final stroke in current.strokes) {
      expect(stroke.displayPixels.length, lessThanOrEqualTo(2000));
    }
    expect(history.memory.retainedBytes, accounted);
    expect(identical(history.document, current), isTrue);
    history.undo();
    history.redo();
    expect(history.document.strokes.single.id, 'revision-4');
    expect(history.memory.retainedBytes, lessThanOrEqualTo(20 * 1024 * 1024));
  });
}
