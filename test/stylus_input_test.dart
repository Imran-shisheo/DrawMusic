import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';

void main() {
  test('legacy input stays byte-compatible and optional stylus metadata is versioned separately from sound', () {
    final legacy = InkPoint(.2, .3, 45);
    expect(jsonEncode(legacy.toJson()), '[0.2,0.3,45]');
    expect(InkPoint.fromJson(legacy.toJson()).toJson(), legacy.toJson());
    final p = InkPoint.input(
      .2,
      .3,
      ms: 45,
      pressure: .4,
      tilt: .2,
      kind: InputKind.stylus,
    );
    expect(p.toJson(), [.2, .3, 45, .4, .2, 2]);
    expect(InkPoint.fromJson(p.toJson()).toJson(), p.toJson());
    final stroke = Stroke(
      id: 'input',
      instrument: Instrument.keys,
      points: [p],
    );
    final document = ProjectDocument(id: 'stylus', strokes: [stroke]);
    expect(document.formatVersion, 2);
    expect(document.soundVersion, 1);
    expect(document.expressionMode, ExpressionMode.geometry);
    expect(compileScore(document).notes.single.velocity, 100);
    final reopened = ProjectDocument.decode(document.encode());
    expect(reopened.strokes.single.points.single.toJson(), p.toJson());
    final future = InkPoint.fromJson([.2, .3, 45, -1, -1, 99]);
    expect(future.kind, InputKind.unknown);
    expect(future.kindCode, 99);
    expect(future.toJson(), [.2, .3, 45, -1, -1, 99]);
  });

  test(
    'expressive mode requires an explicit persisted undoable versioned edit',
    () {
      final original = ProjectDocument(
        id: 'mode',
        strokes: [
          Stroke(
            id: 'line',
            instrument: Instrument.keys,
            points: [InkPoint(.1, .5, 0), InkPoint(.8, .5, 100)],
          ),
        ],
      );
      final history = DocumentHistory(original);
      expect(original.toJson().containsKey('expressionMode'), isFalse);
      expect(original.soundVersion, 1);
      history.commit(
        original.copyWith(expressionMode: ExpressionMode.expressive),
      );
      expect(history.document.soundVersion, 2);
      expect(history.document.formatVersion, 2);
      expect(
        ProjectDocument.decode(history.document.encode()).expressionMode,
        ExpressionMode.expressive,
      );
      history.undo();
      expect(history.document.expressionMode, ExpressionMode.geometry);
      expect(history.document.soundVersion, 1);
      expect(history.document.strokes, original.strokes);
      history.redo();
      expect(history.document.expressionMode, ExpressionMode.expressive);
    },
  );

  test('eraser interpolates pressure, tilt and timestamps without losing device metadata', () {
    final a = InkPoint.input(
      .1,
      .5,
      ms: 10,
      pressure: .2,
      tilt: .1,
      kind: InputKind.stylus,
    );
    final b = InkPoint.input(
      .9,
      .5,
      ms: 110,
      pressure: .8,
      tilt: .5,
      kind: InputKind.stylus,
    );
    final stroke = Stroke(
      id: 'pen',
      instrument: Instrument.keys,
      points: [a, b],
    );
    final clipped = eraseAt([stroke], InkPoint(.5, .5), .08);
    expect(clipped.length, 2);
    final left = clipped.first.points.last;
    expect(left.u, closeTo(.4, 1e-10));
    expect(left.pressure, closeTo(.425, 1e-10));
    expect(left.tilt, closeTo(.25, 1e-10));
    expect(left.ms, 48);
    expect(left.kind, InputKind.stylus);
    final restored = ProjectDocument.decode(
      ProjectDocument(id: 'clipped', strokes: clipped).encode(),
    );
    expect(restored.strokes.first.points.last.toJson(), left.toJson());
    expect(
      () => InkPoint.input(.1, .1, pressure: double.nan),
      throwsFormatException,
    );
    expect(() => InkPoint.input(.1, .1, pressure: 2), throwsFormatException);
    expect(() => InkPoint.input(.1, .1, tilt: math.pi), throwsFormatException);
    expect(
      () => InkPoint.fromJson([0, 0, 0, -2, -1, 2]),
      throwsFormatException,
    );
  });

  testWidgets(
    'native stylus pressure/tilt is captured while second pointers remain ignored',
    (tester) async {
      final cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      final commits = <List<Stroke>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: DrawingCanvas(
                document: ProjectDocument(id: 'pen-canvas'),
                instrument: Instrument.keys,
                eraser: false,
                cursor: cursor,
                onCommit: commits.add,
                onLimit: () => fail('unexpected point limit'),
              ),
            ),
          ),
        ),
      );
      final top = tester.getTopLeft(
        find.byKey(const ValueKey('drawing-canvas')),
      );
      await tester.sendEventToBinding(
        PointerDownEvent(
          pointer: 7,
          kind: PointerDeviceKind.stylus,
          position: top + const Offset(30, 40),
          pressure: .6,
          pressureMin: 0,
          pressureMax: 2,
          tilt: .3,
        ),
      );
      await tester.sendEventToBinding(
        PointerDownEvent(
          pointer: 8,
          kind: PointerDeviceKind.touch,
          position: top + const Offset(60, 80),
        ),
      );
      await tester.sendEventToBinding(
        PointerMoveEvent(
          pointer: 7,
          kind: PointerDeviceKind.stylus,
          position: top + const Offset(90, 120),
          pressure: 1.4,
          pressureMin: 0,
          pressureMax: 2,
          tilt: .4,
        ),
      );
      await tester.sendEventToBinding(
        PointerUpEvent(pointer: 8, position: top + const Offset(60, 80)),
      );
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 7,
          kind: PointerDeviceKind.stylus,
          position: top + const Offset(90, 120),
        ),
      );
      await tester.pump();
      expect(commits.length, 1);
      final points = commits.single.single.points;
      expect(points.length, 2);
      expect(points.first.pressure, closeTo(.3, 1e-10));
      expect(points.last.pressure, closeTo(.7, 1e-10));
      expect(points.first.tilt, .3);
      expect(points.last.kind, InputKind.stylus);
      expect(
        ProjectDocument(id: 'captured', strokes: commits.single).formatVersion,
        2,
      );
    },
  );
}
