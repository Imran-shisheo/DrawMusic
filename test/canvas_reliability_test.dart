import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';

void main() {
  testWidgets(
    'live ink survives metadata refresh and a preceding commit refresh',
    (tester) async {
      var doc = ProjectDocument(id: 'gesture');
      final cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      final commits = <List<Stroke>>[];
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return Center(
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: DrawingCanvas(
                    document: doc,
                    instrument: Instrument.keys,
                    eraser: false,
                    cursor: cursor,
                    onCommit: (strokes) {
                      commits.add(strokes);
                    },
                    onLimit: () => fail('unexpected limit'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      final top = tester.getTopLeft(
        find.byKey(const ValueKey('drawing-canvas')),
      );
      final first = await tester.startGesture(top + const Offset(30, 40));
      await first.moveTo(top + const Offset(60, 80));
      refresh(() => doc = doc.copyWith(tempo: 130, background: 0xffeeeeee));
      await tester.pump();
      await first.moveTo(top + const Offset(90, 120));
      await first.up();
      expect(commits.single.single.points.length, 3);
      final prior = commits.single.single;
      final second = await tester.startGesture(top + const Offset(100, 100));
      // The parent acknowledges the preceding commit after a new pointer began.
      refresh(() => doc = doc.copyWith(strokes: commits.first));
      await tester.pump();
      await second.moveTo(top + const Offset(150, 180));
      await second.up();
      expect(commits.length, 2);
      expect(commits.last.length, 2);
      expect(commits.last.last.points.length, 2);
      expect(prior.points.length, 3);
      expect(identical(commits.last.first, prior), isTrue);
    },
  );

  testWidgets(
    'long stroke keeps exact samples, paints mutable preview and obeys point budget',
    (tester) async {
      final cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      final commits = <List<Stroke>>[];
      var limits = 0;
      final doc = ProjectDocument(
        id: 'budget',
        strokes: [
          Stroke(
            id: 'existing',
            instrument: Instrument.bell,
            points: List.generate(90000, (_) => InkPoint(.1, .1)),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: DrawingCanvas(
                document: doc,
                instrument: Instrument.keys,
                eraser: false,
                cursor: cursor,
                onCommit: commits.add,
                onLimit: () => limits++,
              ),
            ),
          ),
        ),
      );
      final top = tester.getTopLeft(
        find.byKey(const ValueKey('drawing-canvas')),
      );
      final gesture = await tester.startGesture(top + const Offset(30, 40));
      await tester.pump();
      final initialPainter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DrawingPainter>()
          .singleWhere((p) => p.active.isNotEmpty);
      final points = initialPainter.active;
      for (var i = 1; i < 10000; i++) {
        await gesture.moveTo(top + Offset(30 + (i % 200).toDouble(), 100));
      }
      await tester.pump();
      final current = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<DrawingPainter>()
          .singleWhere((p) => p.active.isNotEmpty);
      expect(identical(current.active, points), isTrue);
      expect(current.active.length, 10000);
      // The repaint notifier must remain connected even though list identity is
      // stable; CustomPainter relays this to its render object without rebuilding.
      var notified = 0;
      current.addListener(() => notified++);
      await gesture.moveTo(top + const Offset(250, 200));
      await gesture.up();
      expect(notified, greaterThan(0));
      expect(limits, 1);
      expect(commits.single.last.points.length, 10000);
      expect(commits.single.last.points.last.u, closeTo(229 / 300, 1e-12));
      expect(doc.pointCount, 90000);
      expect(
        ProjectDocument(id: 'full', strokes: commits.single).pointCount,
        100000,
      );
    },
  );
}
