import 'support/editor_controls.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  testWidgets(
    'tool switches with a pointer down preserve ink, instrument and erasure',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('drawing-canvas'));
      final rect = tester.getRect(canvas);
      Offset at(double u, double v) =>
          rect.topLeft + Offset(rect.width * u, rect.height * v);
      ProjectDocument doc() =>
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;
      final first = await tester.startGesture(at(.2, .5), pointer: 7);
      await first.moveTo(at(.3, .4));
      await chooseEditorVoice(tester, Instrument.mallet);
      await tester.pumpAndSettle();
      await first.up();
      await tester.pumpAndSettle();
      expect(doc().strokes.length, 1);
      expect(doc().strokes.single.instrument, Instrument.keys);
      final firstPoints = doc().strokes.single.points
          .map((p) => p.toJson())
          .toList();
      final second = await tester.startGesture(at(.6, .7), pointer: 8);
      await second.moveTo(at(.7, .6));
      await tester.tap(find.text('Erase'));
      await tester.pumpAndSettle();
      await second.up();
      await tester.pumpAndSettle();
      expect(doc().strokes.length, 2);
      expect(doc().strokes.last.instrument, Instrument.mallet);
      expect(
        doc().strokes.first.points.map((p) => p.toJson()).toList(),
        firstPoints,
      );
      final erase = await tester.startGesture(at(.25, .45), pointer: 9);
      await tester.pump();
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
      await erase.up();
      await tester.pumpAndSettle();
      expect(
        doc().strokes.where((s) => s.instrument == Instrument.keys).length,
        2,
      );
      expect(
        doc().strokes.where((s) => s.instrument == Instrument.mallet).length,
        1,
      );
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(doc().strokes.length, 2);
      expect(
        doc().strokes.first.points.map((p) => p.toJson()).toList(),
        firstPoints,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
