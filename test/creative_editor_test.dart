import 'support/editor_controls.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/transport/domain/audio_engine.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

ProjectDocument drawing() => ProjectDocument(
  id: 'creative-ui',
  strokes: [
    Stroke(
      id: 'old',
      instrument: Instrument.keys,
      points: [InkPoint(.1, .5), InkPoint(.8, .5)],
    ),
  ],
);
ProjectDocument current(WidgetTester tester) =>
    tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document;
Future<void> mountEditor(
  WidgetTester tester, {
  ProjectDocument? document,
  MemoryRepository? repository,
  TestAudio? audio,
  String locale = 'en',
  Size size = const Size(800, 600),
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialDocumentProvider.overrideWithValue(document ?? drawing()),
        repositoryProvider.overrideWith(
          (ref) async => repository ?? MemoryRepository(),
        ),
        audioEngineProvider.overrideWithValue(audio ?? TestAudio()),
        preferencesStoreProvider.overrideWith(
          (ref) async => MemoryPreferencesStore(
            UserPreferences(languageCode: locale, reduceMotion: true),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(brightness: brightness),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EditorWorkspace(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapReachable(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
}

void main() {
  testWidgets(
    'expanded voice, root and scale choices preserve old ink and are undoable',
    (tester) async {
      final repository = MemoryRepository();
      await mountEditor(tester, repository: repository);
      final original = current(tester).strokes.single;
      await chooseEditorVoice(tester, Instrument.warmSynth);
      expect(
        tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).instrument,
        Instrument.warmSynth,
      );
      final rect = tester.getRect(find.byKey(const ValueKey('drawing-canvas')));
      final pen = await tester.startGesture(
        rect.topLeft + Offset(rect.width * .2, rect.height * .3),
      );
      await pen.moveTo(
        rect.topLeft + Offset(rect.width * .7, rect.height * .4),
      );
      await pen.up();
      await tester.pumpAndSettle();
      expect(current(tester).strokes.length, 2);
      expect(identical(current(tester).strokes.first, original), isTrue);
      expect(current(tester).strokes.last.instrument, Instrument.warmSynth);
      final geometry = current(tester).strokes;
      await openEditorMusic(tester);
      await tapReachable(tester, find.byType(DropdownButton<RootKey>));
      await tester.tap(find.text('D').last);
      await tester.pumpAndSettle();
      expect(
        current(tester).root,
        RootKey.c,
        reason: 'music preview is transactional until Apply',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(current(tester).root, RootKey.d);
      expect(current(tester).strokes, geometry);
      await openEditorMusic(tester);
      await tapReachable(tester, find.byType(DropdownButton<MusicalScale>));
      await tester.ensureVisible(find.text('Harmonic minor').last);
      await tester.tap(find.text('Harmonic minor').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(current(tester).scale, MusicalScale.harmonicMinor);
      expect(current(tester).strokes, geometry);
      await tapReachable(tester, find.byTooltip('Undo'));
      expect(current(tester).scale, MusicalScale.major);
      expect(current(tester).root, RootKey.d);
      await tapReachable(tester, find.byTooltip('Undo'));
      expect(current(tester).root, RootKey.c);
      expect(current(tester).strokes, geometry);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(
        repository.documents['creative-ui']!.strokes.last.instrument,
        Instrument.warmSynth,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty drawing accompaniment supports Cancel, levels, mute and live loop-boundary changes',
    (tester) async {
      final audio = TestAudio();
      final repository = MemoryRepository();
      await mountEditor(
        tester,
        document: ProjectDocument(id: 'creative-ui'),
        audio: audio,
        repository: repository,
      );
      IconButton play() => tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('Play'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(play().onPressed, isNull);
      await openEditorTool(tester, 'mix');
      await tapReachable(
        tester,
        find.widgetWithText(SwitchListTile, 'Earth bass'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(current(tester).mix.isConfigured, isFalse);
      await openEditorTool(tester, 'mix');
      await tapReachable(
        tester,
        find.widgetWithText(SwitchListTile, 'Earth bass'),
      );
      await tester.drag(find.byType(Slider).first, const Offset(-60, 0));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(current(tester).mix[AccompanimentLayer.bass].enabled, isTrue);
      expect(current(tester).mix[AccompanimentLayer.bass].level, lessThan(.5));
      expect(play().onPressed, isNotNull);
      await tester.ensureVisible(find.byTooltip('Play'));
      await tester.tap(find.byTooltip('Play'));
      await waitFor(tester, () => audio.playing);
      expect(audio.plays, 1);
      await openEditorTool(tester, 'mix');
      await tester.ensureVisible(find.byTooltip('Mute layer'));
      await tester.tap(find.byTooltip('Mute layer'));
      await tester.pump();
      expect(current(tester).mix[AccompanimentLayer.bass].muted, isFalse);
      expect(audio.queued, isEmpty);
      await tester.tap(find.text('Apply'));
      await tester.pump(const Duration(milliseconds: 500));
      await waitFor(tester, () => audio.queued.isNotEmpty);
      expect(current(tester).mix[AccompanimentLayer.bass].muted, isTrue);
      expect(audio.queued.last.boundary, UpdateBoundary.loop);
      await tester.ensureVisible(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(audio.playing, isFalse);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      expect(
        repository.documents['creative-ui']!.mix[AccompanimentLayer.bass].muted,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'explicit expressive choice saves, undoes and leaves drawing geometry intact',
    (tester) async {
      final repository = MemoryRepository();
      await mountEditor(tester, repository: repository);
      final geometry = current(tester).strokes;
      expect(current(tester).expressionMode, ExpressionMode.geometry);
      await openEditorMusic(tester);
      await tapReachable(tester, find.text('Expressive dynamics'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(current(tester).expressionMode, ExpressionMode.expressive);
      expect(current(tester).soundVersion, 2);
      await tester.tap(find.byTooltip('Save drawing'));
      await tester.pumpAndSettle();
      final restored = ProjectDocument.decode(
        repository.documents['creative-ui']!.encode(),
      );
      expect(restored.expressionMode, ExpressionMode.expressive);
      await tapReachable(tester, find.byTooltip('Undo'));
      expect(current(tester).expressionMode, ExpressionMode.geometry);
      expect(current(tester).strokes, geometry);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final language in ['fr', 'hi', 'ja']) {
    testWidgets(
      'compact $language 200% creative controls and accompaniment stay reachable',
      (tester) async {
        await mountEditor(
          tester,
          locale: language,
          size: const Size(320, 640),
          scale: 2,
        );
        final strings = AppLocalizations.of(
          tester.element(find.byType(EditorWorkspace)),
        )!;
        expect(tester.takeException(), isNull);
        final canvas = tester.getRect(
          find.byKey(const ValueKey('drawing-canvas')),
        );
        expect(canvas.height, greaterThan(48));
        await openEditorTool(tester, 'mix');
        await tester.tap(find.text(strings.cancel));
        await tester.pumpAndSettle();
        await openEditorMusic(tester);
        await tapReachable(tester, find.text(strings.expressiveMode));
        await tester.tap(find.text(strings.apply));
        await tester.pumpAndSettle();
        expect(current(tester).expressionMode, ExpressionMode.expressive);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'tablet workspace keeps controls beside canvas and persistent dark settings apply',
    (tester) async {
      await mountEditor(tester, size: const Size(1280, 800));
      final canvas = tester.getRect(
        find.byKey(const ValueKey('drawing-canvas')),
      );
      final tools = tester.getRect(
        find.byKey(const ValueKey('editor-tools-scroll')),
      );
      expect(canvas.left, greaterThan(tools.right));
      expect(canvas.height, greaterThan(500));
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      try {
        final preferences = MemoryPreferencesStore(
          const UserPreferences(darkTheme: false),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesStoreProvider.overrideWith((ref) async => preferences),
              repositoryProvider.overrideWith(
                (ref) async => MemoryRepository(),
              ),
              audioEngineProvider.overrideWithValue(TestAudio()),
            ],
            child: const ScribbleSongApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tapReachable(
          tester,
          find.widgetWithText(SwitchListTile, 'Dark theme'),
        );
        expect(preferences.preferences.darkTheme, isTrue);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
        expect(
          Theme.of(tester.element(find.text('Dark theme'))).brightness,
          Brightness.dark,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
