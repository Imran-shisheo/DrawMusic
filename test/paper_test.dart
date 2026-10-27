import 'support/editor_controls.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/design_system/paper_panel.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  test(
    'paper alpha round-trips exactly while score and PCM stay unchanged',
    () async {
      expect(opaquePaperColor(0x00112233), 0xffffffff);
      expect(opaquePaperColor(0xff112233), 0xff112233);
      expect(opaquePaperColor(0x80112233), 0xff889099);
      expect(opaquePaperColor(0x80000000), 0xff7f7f7f);
      expect(
        () => ProjectDocument(id: 'bad', background: -1),
        throwsFormatException,
      );
      expect(
        () => ProjectDocument(id: 'bad', background: 0x100000000),
        throwsFormatException,
      );
      final root = await Directory.systemTemp.createTemp('paper-test');
      addTearDown(() => root.delete(recursive: true));
      final document = ProjectDocument(
        id: 'paper',
        strokes: [
          Stroke(
            id: 'line',
            instrument: Instrument.keys,
            points: [InkPoint(.2, .5), InkPoint(.8, .5)],
          ),
        ],
      );
      final score = compileScore(document),
          pcm = renderPcm(compileScore(document));
      final changed = document.copyWith(background: 0x80f3eef9);
      await FileProjectRepository(root).save(changed);
      final reopened = await FileProjectRepository(root).load(document.id);
      expect(reopened.background, 0x80f3eef9);
      expect(
        reopened.strokes.single.toJson(),
        document.strokes.single.toJson(),
      );
      expect(
        compileScore(reopened).notes.map((n) => n.fixture),
        score.notes.map((n) => n.fixture),
      );
      expect(renderPcm(compileScore(reopened)), pcm);
    },
  );
  testWidgets('paper actions remain reachable at 320 dp and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPaperPanel(context, 0xfff7f5eb);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Apply').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byType(Slider));
    await tester.ensureVisible(find.byType(Slider));
    await tester.drag(find.byType(Slider), const Offset(-600, 0));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result, 0x00f7f5eb);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'paper panel previews transactionally, supports undo and preserves playing audio',
    (tester) async {
      final repo = MemoryRepository(), audio = TestAudio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repo),
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
        const Offset(70, 40),
      );
      await tester.pumpAndSettle();
      ProjectDocument doc() =>
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;
      final original = doc();
      await tester.tap(find.byTooltip('Play'));
      for (var i = 0; i < 100 && !audio.playing; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(audio.playing, isTrue);
      await tester.pumpAndSettle();
      final queues = audio.queued.length, prepares = audio.prepares;
      await openEditorTool(tester, 'paper');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Opacity 0%'), findsOneWidget);
      expect(
        doc().effectiveBackground.toJson(),
        original.effectiveBackground.toJson(),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        doc().effectiveBackground.toJson(),
        original.effectiveBackground.toJson(),
      );
      await openEditorTool(tester, 'paper');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Lilac paper'));
      await tester.tap(find.byTooltip('Lilac paper'));
      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(-600, 0));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(doc().effectiveBackground.colors.first, 0xfff3eef9);
      expect(doc().effectiveBackground.opacity, 0);
      expect(audio.playing, isTrue);
      expect(audio.prepares, prepares);
      expect(audio.queued.length, queues);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(
        doc().effectiveBackground.toJson(),
        original.effectiveBackground.toJson(),
      );
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(doc().effectiveBackground.colors.first, 0xfff3eef9);
      expect(doc().effectiveBackground.opacity, 0);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(
        repo.documents[original.id]!.effectiveBackground.colors.first,
        0xfff3eef9,
      );
      expect(repo.documents[original.id]!.effectiveBackground.opacity, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
