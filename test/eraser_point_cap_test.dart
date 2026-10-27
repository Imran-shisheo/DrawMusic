import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

ProjectDocument dense(int count, {bool zigzag = false}) => ProjectDocument(
  id: 'erase-cap-$count',
  strokes: [
    Stroke(
      id: 'target',
      instrument: Instrument.keys,
      points: [InkPoint(.1, .5), InkPoint(.9, .5)],
    ),
    Stroke(
      id: 'unrelated',
      instrument: Instrument.bell,
      points: List.generate(
        count - 2,
        (i) => zigzag
            ? InkPoint(i.isEven ? .05 : .15, i.isEven ? .05 : .15, i)
            : InkPoint(.1, .1, i),
      ),
    ),
  ],
);

List<List<int>> score(ProjectDocument doc) => [
  for (final n in compileScore(doc).notes) n.fixture,
];

Future<Rect> mountCanvas(
  WidgetTester tester,
  DocumentHistory history, {
  required VoidCallback onLimit,
  required VoidCallback onCommit,
  GlobalKey<DrawingCanvasState>? canvasKey,
}) async {
  final cursor = ValueNotifier<double?>(null);
  addTearDown(cursor.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          height: 400,
          child: StatefulBuilder(
            builder: (context, refresh) => DrawingCanvas(
              key: canvasKey,
              document: history.document,
              instrument: Instrument.keys,
              eraser: true,
              cursor: cursor,
              onLimit: onLimit,
              onCommit: (strokes) {
                onCommit();
                refresh(
                  () => history.commit(
                    history.document.copyWith(strokes: strokes),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  return tester.getRect(find.byKey(const ValueKey('drawing-canvas')));
}

class CountingRepository extends MemoryRepository {
  int saves = 0;
  @override
  Future<void> save(ProjectDocument doc) async {
    saves++;
    await super.save(doc);
  }
}

void main() {
  for (final count in [99999, 100000]) {
    test(
      'review reproduction: $count source points become ${count + 2} clipped endpoints',
      () {
        final document = dense(count);
        final erased = eraseAt(document.strokes, InkPoint(.5, .5), .03);
        expect(erased.fold<int>(0, (n, s) => n + s.points.length), count + 2);
        expect(identical(erased.last, document.strokes.last), isTrue);
        expect(() => document.copyWith(strokes: erased), throwsFormatException);
      },
    );

    for (final zigzag in [false, true]) {
      testWidgets(
        '$count cap rejects endpoint growth safely (zigzag=$zigzag), repeated/no-op and subsequent erasing remain usable',
        (tester) async {
          final original = dense(count, zigzag: zigzag);
          final history = DocumentHistory(original);
          final canvasKey = GlobalKey<DrawingCanvasState>();
          var limits = 0, commits = 0;
          final rect = await mountCanvas(
            tester,
            history,
            canvasKey: canvasKey,
            onLimit: () => limits++,
            onCommit: () => commits++,
          );
          Offset at(double u, double v) =>
              rect.topLeft + Offset(u * rect.width, v * rect.height);
          for (var i = 0; i < 2; i++) {
            await tester.tapAt(at(.5, .5));
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: 'over-cap eraser must reject before editor copyWith',
            );
            expect(identical(history.document, original), isTrue);
            expect(commits, 0);
            expect(limits, i + 1);
            expect(history.canUndo, isFalse);
            expect(canvasKey.currentState!.hasActiveGesture, isFalse);
          }
          // Empty erasing remains an actual no-op, not an extra rejection/history.
          await tester.tapAt(at(.98, .95));
          await tester.pump();
          expect(commits, 0);
          expect(limits, 2);
          expect(identical(history.document, original), isTrue);
          // A later larger erasure frees capacity and is one complete Undo edit.
          final eraser = await tester.startGesture(at(.08, .5));
          await eraser.moveTo(at(.92, .5));
          await eraser.up();
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(commits, 1);
          expect(history.document.pointCount, count - 2);
          expect(history.document.strokes.length, 1);
          expect(
            identical(history.document.strokes.single, original.strokes.last),
            isTrue,
          );
          expect(history.undoCount, 1);
          history.undo();
          expect(history.document.pointCount, count);
          expect(score(history.document), score(original));
          history.redo();
          expect(history.document.pointCount, count - 2);
          expect(
            score(history.document),
            score(original.copyWith(strokes: [original.strokes.last])),
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'over-cap temporary preview may finish as one valid larger erasure',
    (tester) async {
      final original = dense(100000, zigzag: true);
      final history = DocumentHistory(original);
      var commits = 0;
      final rect = await mountCanvas(
        tester,
        history,
        onLimit: () =>
            fail('final erasure fits, despite temporary endpoint growth'),
        onCommit: () => commits++,
      );
      Offset at(double u) =>
          rect.topLeft + Offset(u * rect.width, .5 * rect.height);
      final gesture = await tester.startGesture(at(.5));
      await tester.pump();
      expect(commits, 0);
      expect(identical(history.document, original), isTrue);
      expect(tester.takeException(), isNull);
      await gesture.moveTo(at(.08));
      await gesture.moveTo(at(.92));
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(commits, 1);
      expect(history.document.pointCount, 99998);
      expect(history.undoCount, 1);
      expect(
        identical(history.document.strokes.single, original.strokes.last),
        isTrue,
      );
      history.undo();
      expect(score(history.document), score(original));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'erasure that grows exactly to cap commits once and Undo/Redo restore score',
    (tester) async {
      final original = dense(99998);
      final history = DocumentHistory(original);
      var commits = 0;
      final rect = await mountCanvas(
        tester,
        history,
        onLimit: () => fail('exact capacity is legal'),
        onCommit: () => commits++,
      );
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(commits, 1);
      expect(history.document.pointCount, 100000);
      expect(history.document.strokes.length, 3);
      expect(
        identical(history.document.strokes.last, original.strokes.last),
        isTrue,
      );
      final clippedScore = score(history.document);
      expect(clippedScore.length, greaterThan(score(original).length));
      history.undo();
      expect(score(history.document), score(original));
      history.redo();
      expect(score(history.document), clippedScore);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('successful full-cap clipped drawing saves/reopens actual filesystem with exact unrelated geometry', () async {
    final root = await Directory.systemTemp.createTemp('drawmusic-erase-cap-');
    addTearDown(() => root.delete(recursive: true));
    final repository = FileProjectRepository(root);
    final original = dense(99998);
    final edited = original.copyWith(
      strokes: eraseAt(original.strokes, InkPoint(.5, .5), .03),
    );
    expect(edited.pointCount, 100000);
    await repository.save(edited);
    final reopened = await FileProjectRepository(root).load(original.id);
    expect(reopened.encode(), edited.encode());
    expect(
      reopened.strokes.last.points.map((p) => p.toJson()).toList(),
      original.strokes.last.points.map((p) => p.toJson()).toList(),
    );
    expect(score(reopened), score(edited));
  });

  testWidgets(
    'actual editor rejection preserves saved revision, explains limit and schedules no false autosave',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = dense(100000, zigzag: true);
      final repository = CountingRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialDocumentProvider.overrideWithValue(original),
            repositoryProvider.overrideWith((ref) async => repository),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const EditorWorkspace(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final saved = repository.saves;
      expect(saved, greaterThan(0));
      await tester.ensureVisible(find.text('Erase'));
      await tester.tap(find.text('Erase'));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getRect(find.byKey(const ValueKey('drawing-canvas'))).center,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(EditorWorkspace)))!
              .erasureLimitRejected,
        ),
        findsOneWidget,
      );
      expect(
        identical(
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document,
          original,
        ),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(
        repository.saves,
        saved,
        reason: 'rejected erase never publishes a revision or schedules a save',
      );
      expect(repository.documents[original.id]!.encode(), original.encode());
      await tester.pumpWidget(const SizedBox());
    },
  );
}
