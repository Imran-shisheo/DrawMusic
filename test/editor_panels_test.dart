import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/creative_panel.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'creative_editor_test.dart'
    show current, mountEditor, tapReachable, waitFor;
import 'support/editor_controls.dart';

void main() {
  testWidgets(
    'direct graphite paper control owns one sheet and Cancel retains live canvas',
    (tester) async {
      await mountEditor(tester, size: const Size(411, 850));
      final original = current(tester).encode();
      final canvas = tester.state<DrawingCanvasState>(
        find.byType(DrawingCanvas),
      );
      final paper = find.byKey(const ValueKey('editor-background'));
      await tester.ensureVisible(paper);
      await tester.pumpAndSettle();
      await tester.tap(paper);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(current(tester).encode(), original);
      expect(
        identical(
          tester.state<DrawingCanvasState>(find.byType(DrawingCanvas)),
          canvas,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'immersive score and clear panels preserve exact drawing, Back and one Undo ($brightness)',
      (tester) async {
        final document = ProjectDocument(
          id: 'immersive-panels',
          strokes: [
            Stroke(
              id: 'paint',
              instrument: Instrument.flute,
              points: [InkPoint(.2, .8, 0), InkPoint(.8, .2, 800)],
            ),
          ],
        );
        await mountEditor(
          tester,
          document: document,
          size: const Size(411, 850),
          brightness: brightness,
        );
        final strings = AppLocalizations.of(
          tester.element(find.byType(EditorWorkspace)),
        )!;
        final original = current(tester).encode();
        final canvas = tester.state<DrawingCanvasState>(
          find.byType(DrawingCanvas),
        );
        final compiled = compileScore(document);
        expect(compiled.notes, isNotEmpty);
        expect(find.text(strings.editorToolsShort), findsOneWidget);
        await openEditorTool(tester, 'score');
        await waitFor(
          tester,
          () => find.text(strings.yourLoopInNotes).evaluate().isNotEmpty,
        );
        final description = find.textContaining(
          strings.scoreSummary(
            document.root.label,
            compiled.notes.length.toString(),
            document.tempo.toString(),
            scaleName(
              tester.element(find.byType(EditorWorkspace)),
              document.scale,
            ),
          ),
        );
        expect(description, findsOneWidget);
        expect(current(tester).encode(), original);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(current(tester).encode(), original);
        await openEditorTool(tester, 'clear');
        expect(find.text(strings.youCanRestoreItWithUndo), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(current(tester).encode(), original);
        await openEditorTool(tester, 'clear');
        await tapReachable(tester, find.text(strings.clear));
        expect(current(tester).strokes, isEmpty);
        expect(
          identical(
            tester.state<DrawingCanvasState>(find.byType(DrawingCanvas)),
            canvas,
          ),
          isTrue,
        );
        await tapReachable(tester, find.byTooltip(strings.undo));
        // History deliberately refreshes updatedAt; every authored field and point
        // returns exactly, and one Redo reapplies only this clear operation.
        expect(current(tester).strokes, document.strokes);
        expect(
          compileScore(current(tester)).notes
              .map(
                (note) => [
                  ...note.fixture,
                  note.velocity,
                  note.gain,
                  note.percussion,
                  note.midiChannelOverride,
                ],
              )
              .toList(),
          compiled.notes
              .map(
                (note) => [
                  ...note.fixture,
                  note.velocity,
                  note.gain,
                  note.percussion,
                  note.midiChannelOverride,
                ],
              )
              .toList(),
        );
        await tapReachable(tester, find.byTooltip(strings.redo));
        expect(current(tester).strokes, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'compact Hindi200% immersive panels preserve nested Cancel and clear cancellation without edits',
    (tester) async {
      await mountEditor(
        tester,
        locale: 'hi',
        size: const Size(320, 640),
        scale: 2,
        brightness: Brightness.dark,
      );
      final strings = AppLocalizations.of(
        tester.element(find.byType(EditorWorkspace)),
      )!;
      final original = current(tester).encode();
      await openEditorMusic(tester);
      await tapReachable(tester, find.text(strings.accompaniment));
      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is CreativePanel &&
                widget.title == strings.accompaniment,
          ),
          matching: find.byType(SwitchListTile),
        ),
        findsNWidgets(AccompanimentLayer.values.length),
      );
      await tapReachable(tester, find.text(strings.cancel).last);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(current(tester).encode(), original);
      await openEditorTool(tester, 'clear');
      await tapReachable(tester, find.text(strings.keepDrawing));
      expect(current(tester).encode(), original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
