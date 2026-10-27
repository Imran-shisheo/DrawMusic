import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/editor_controls.dart';
import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

ProjectDocument _document() => ProjectDocument(
  id: 'redesigned',
  title: 'Quiet afternoon',
  strokes: [
    Stroke(
      id: 'old',
      instrument: Instrument.keys,
      points: [InkPoint(.1, .5), InkPoint(.9, .5)],
    ),
  ],
);
ProjectDocument _current(WidgetTester tester) =>
    tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;
Future<void> _mount(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TestAudio? audio,
  String language = 'en',
  ProjectDocument? document,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialDocumentProvider.overrideWithValue(document ?? _document()),
        repositoryProvider.overrideWith((ref) async => MemoryRepository()),
        audioEngineProvider.overrideWithValue(audio ?? TestAudio()),
        preferencesStoreProvider.overrideWith(
          (ref) async =>
              MemoryPreferencesStore(const UserPreferences(reduceMotion: true)),
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(brightness: brightness),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const EditorWorkspace(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(640, 320),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets(
          'canvas-first editor $size text$scale $brightness remains reachable and chooser preserves state',
          (tester) async {
            await _mount(
              tester,
              size: size,
              scale: scale,
              brightness: brightness,
            );
            final semantics = tester.ensureSemantics();
            try {
              expect(tester.takeException(), isNull);
              final finder = find.byKey(const ValueKey('drawing-canvas'));
              final state = tester.state<DrawingCanvasState>(
                find.byType(DrawingCanvas),
              );
              final original = _current(tester).encode();
              final rect = tester.getRect(finder);
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.width, greaterThanOrEqualTo(48));
              expect(rect.top, greaterThanOrEqualTo(24));
              expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
              await chooseEditorVoice(tester, Instrument.saxophone);
              expect(
                identical(
                  tester.state<DrawingCanvasState>(find.byType(DrawingCanvas)),
                  state,
                ),
                isTrue,
              );
              expect(_current(tester).encode(), original);
              expect(
                tester
                    .widget<DrawingCanvas>(find.byType(DrawingCanvas))
                    .instrument,
                Instrument.saxophone,
              );
              await openEditorMusic(tester);
              expect(find.byType(DropdownButton<RootKey>), findsOneWidget);
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              expect(_current(tester).encode(), original);
              expect(
                identical(
                  tester.state<DrawingCanvasState>(find.byType(DrawingCanvas)),
                  state,
                ),
                isTrue,
              );
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets(
    'voice selection safely finishes active ink and resize retains canvas gesture identity',
    (tester) async {
      await _mount(tester, size: const Size(411, 911));
      final state = tester.state<DrawingCanvasState>(
        find.byType(DrawingCanvas),
      );
      Rect rect() =>
          tester.getRect(find.byKey(const ValueKey('drawing-canvas')));
      Offset at(double u, double v) =>
          rect().topLeft + Offset(u * rect().width, v * rect().height);
      final pen = await tester.startGesture(at(.2, .4), pointer: 7);
      await pen.moveTo(at(.4, .5));
      await chooseEditorVoice(tester, Instrument.guitar);
      await pen.up();
      await tester.pumpAndSettle();
      expect(_current(tester).strokes.last.instrument, Instrument.keys);
      expect(_current(tester).strokes.last.points.length, 2);
      final next = await tester.startGesture(at(.3, .3), pointer: 8);
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.state<DrawingCanvasState>(find.byType(DrawingCanvas)),
          state,
        ),
        isTrue,
      );
      expect(state.hasActiveGesture, isTrue);
      await next.moveTo(at(.7, .6));
      await next.up();
      await tester.pumpAndSettle();
      expect(_current(tester).strokes.last.instrument, Instrument.guitar);
      expect(_current(tester).strokes.last.points.length, 2);
      expect(_current(tester).strokes.last.points.first.u, closeTo(.3, 1e-10));
      expect(_current(tester).strokes.last.points.last.u, closeTo(.7, 1e-10));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(_current(tester).strokes.length, 2);
      expect(_current(tester).strokes.last.instrument, Instrument.keys);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(_current(tester).strokes.last.instrument, Instrument.guitar);
      expect(_current(tester).strokes.last.points.length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'tempo-only music Apply preserves unknown IDs until explicit replacement',
    (tester) async {
      final unknown = ProjectDocument(
        id: 'unknown-ui',
        sourceRootId: 'future-root',
        sourceScaleId: 'future-scale',
        strokes: _document().strokes,
      );
      await _mount(tester, size: const Size(411, 911), document: unknown);
      await openEditorMusic(tester);
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final tempo = _current(tester).tempo;
      expect(tempo, isNot(120));
      expect(_current(tester).rootId, 'future-root');
      expect(_current(tester).scaleId, 'future-scale');
      await openEditorMusic(tester);
      await tester.tap(find.byType(DropdownButton<RootKey>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<MusicalScale>));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dorian').last);
      await tester.tap(find.text('Dorian').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(_current(tester).rootId, 'd');
      expect(_current(tester).scaleId, 'dorian');
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(_current(tester).tempo, tempo);
      expect(_current(tester).rootId, 'future-root');
      expect(_current(tester).scaleId, 'future-scale');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'playback preparation and cursor do not move canvas or replace document',
    (tester) async {
      final audio = TestAudio();
      await _mount(tester, size: const Size(411, 911), audio: audio);
      final doc = _current(tester);
      final rect = tester.getRect(find.byKey(const ValueKey('drawing-canvas')));
      await tester.tap(find.byTooltip('Play'));
      for (var i = 0; i < 200 && !audio.playing; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(audio.playing, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getRect(find.byKey(const ValueKey('drawing-canvas'))),
        rect,
      );
      expect(identical(_current(tester), doc), isTrue);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(audio.playing, isFalse);
      expect(
        tester.getRect(find.byKey(const ValueKey('drawing-canvas'))),
        rect,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
