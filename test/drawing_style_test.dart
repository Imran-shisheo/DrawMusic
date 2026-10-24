import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  test(
    'pixel geometry is bounded, connects sparse lines and is reversible',
    () {
      final points = [InkPoint(0, 0), InkPoint(1, 1), InkPoint(0, 1)];
      expect(
        displayPixelCells(points),
        displayPixelCells(points.reversed.toList()),
      );
      expect(displayPixelCells([InkPoint(1, 1)]), {1999});
      expect(displayPixelCells([InkPoint(0, .5), InkPoint(1, .5)]), {
        for (var i = 0; i < 40; i++) 1000 + i,
      });
      expect(displayPixelCells([InkPoint(.5, 0), InkPoint(.5, 1)]).length, 50);
      expect(
        displayPixelCells(
          List.generate(100000, (i) => InkPoint((i % 40) / 40, (i % 50) / 50)),
        ).length,
        lessThanOrEqualTo(2000),
      );
    },
  );
  test('styles survive file reopen/duplicate and do not alter geometry, score or PCM', () async {
    final root = await Directory.systemTemp.createTemp('style-test');
    addTearDown(() => root.delete(recursive: true));
    final doc = ProjectDocument(
      id: 'style',
      strokes: [
        Stroke(
          id: 'line',
          instrument: Instrument.keys,
          points: [InkPoint(.1, .5), InkPoint(.9, .5)],
        ),
      ],
    );
    final legacy = doc.toJson()..remove('style');
    // A missing field in schema 1 remains a smooth drawing.
    expect(
      ProjectDocument.decode(jsonEncode(legacy)).style,
      DrawingStyle.smooth,
    );
    final history = DocumentHistory(doc);
    history.commit(doc.copyWith(style: DrawingStyle.pixel));
    final repo = FileProjectRepository(root);
    await repo.save(history.document);
    final reopened = await FileProjectRepository(root).load(doc.id);
    final duplicate = await repo.duplicate(doc.id);
    expect(reopened.style, DrawingStyle.pixel);
    expect(duplicate.style, DrawingStyle.pixel);
    expect(reopened.strokes.single.toJson(), doc.strokes.single.toJson());
    expect(
      compileScore(reopened).notes.map((n) => n.fixture),
      compileScore(doc).notes.map((n) => n.fixture),
    );
    expect(renderPcm(compileScore(reopened)), renderPcm(compileScore(doc)));
    history.undo();
    expect(history.document.style, DrawingStyle.smooth);
    history.redo();
    expect(history.document.style, DrawingStyle.pixel);
  });
  testWidgets(
    'pixel painting changes the display without rewriting the drawing',
    (tester) async {
      final doc = ProjectDocument(
        id: 'paint',
        style: DrawingStyle.pixel,
        strokes: [
          Stroke(
            id: 'dot',
            instrument: Instrument.keys,
            points: [InkPoint(.5, .5)],
          ),
        ],
      );
      final recorder = ui.PictureRecorder();
      // Use the actual shipping painter, then inspect an interior pixel of its cell.
      final surface = Canvas(recorder);
      surface.drawColor(Colors.white, BlendMode.src);
      DrawingPainter(doc).paint(surface, const Size(400, 500));
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(400, 500));
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      expect(
        bytes!.buffer.asUint8List().sublist(
          (255 * 400 + 205) * 4,
          (255 * 400 + 205) * 4 + 4,
        ),
        [121, 97, 198, 255],
      );
      image!.dispose();
      picture.dispose();
      expect(doc.strokes.single.points.length, 1);
    },
  );
  testWidgets(
    'style selection is cancelable, named and undoable without audio changes',
    (tester) async {
      final audio = TestAudio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            audioEngineProvider.overrideWithValue(audio),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('drawing-canvas')),
        const Offset(80, 30),
      );
      await tester.pumpAndSettle();
      ProjectDocument doc() =>
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;
      final original = doc().strokes.single.toJson();
      await tester.tap(find.byTooltip('Drawing style'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(doc().style, DrawingStyle.smooth);
      await tester.tap(find.byTooltip('Drawing style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pixel'));
      await tester.pumpAndSettle();
      expect(doc().style, DrawingStyle.pixel);
      expect(doc().strokes.single.toJson(), original);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(doc().style, DrawingStyle.smooth);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(doc().style, DrawingStyle.pixel);
      expect(audio.prepares, 0);
      expect(audio.queued, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
