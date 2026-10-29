import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'creative_editor_test.dart' show current, mountEditor, waitFor;
import 'support/editor_controls.dart';

bool _fontsLoaded = false;
Future<void> _loadProductFonts() async {
  if (_fontsLoaded) return;
  for (final family in [
    'NunitoSans',
    'SpaceGrotesk',
    'NotoSansDevanagari',
    'NotoSansThai',
    'NotoSansArabic',
    'NotoSansCJK',
  ]) {
    final loader = FontLoader(family);
    for (final file
        in Directory('assets/fonts/$family').listSync().whereType<File>().where(
          (file) => file.path.endsWith('.ttf') || file.path.endsWith('.ttc'),
        )) {
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

void _expectWholeWordsAndVisible(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = tester.widget<Text>(finder).data!;
  for (final word
      in text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty)) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: paragraph.text.style),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
    )..layout();
    expect(
      paragraph.size.width + .01,
      greaterThanOrEqualTo(painter.width),
      reason:
          'The complete word "$word" must fit its actual product-font content box.',
    );
    painter.dispose();
  }
  final viewport = find
      .ancestor(of: finder, matching: find.byType(SingleChildScrollView))
      .first;
  final bounds = tester.getRect(viewport), label = tester.getRect(finder);
  expect(
    label.top,
    greaterThanOrEqualTo(bounds.top - .01),
    reason: 'No label line may be clipped above its control viewport.',
  );
  expect(
    label.bottom,
    lessThanOrEqualTo(bounds.bottom + .01),
    reason: 'No label line may be clipped below its control viewport.',
  );
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'actual bundled-font landscape rail keeps transport captions readable at ${scale}x',
      (tester) async {
        await tester.runAsync(_loadProductFonts);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPadding);
        await mountEditor(tester, size: const Size(640, 360), scale: scale);
        final strings = tester.element(find.byType(EditorWorkspace)).strings;
        final canvas = find.byKey(const ValueKey('drawing-canvas'));
        final bounds = tester.getRect(canvas);
        if (scale == 2) {
          // The deliberately retained very-short rail is one scrollable panel.
          await tester.ensureVisible(find.byTooltip(strings.play));
          await tester.pumpAndSettle();
        }
        _expectWholeWordsAndVisible(tester, find.text(strings.play));
        _expectWholeWordsAndVisible(tester, find.text(strings.undo));
        if (scale == 1) {
          _expectWholeWordsAndVisible(tester, find.text(strings.redo));
          _expectWholeWordsAndVisible(tester, find.text(strings.replay));
        }
        await tester.tap(find.byTooltip(strings.play));
        await waitFor(
          tester,
          () => find.byTooltip(strings.pause).evaluate().isNotEmpty,
        );
        _expectWholeWordsAndVisible(tester, find.text(strings.pause));
        expect(tester.getRect(canvas), bounds);
        expect(
          tester.getSize(find.byTooltip(strings.pause)).shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final language in [
    'en',
    'fr',
    'es',
    'it',
    'ko',
    'ja',
    'vi',
    'hi',
    'pt',
    'th',
    'fil',
    'id',
  ]) {
    testWidgets(
      'actual bundled-font $language 320dp 200% preserves initial Play/Pause captions, stable72dp paper and full tools/voice labels',
      (tester) async {
        await tester.runAsync(_loadProductFonts);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPadding);
        await mountEditor(
          tester,
          locale: language,
          size: const Size(320, 640),
          scale: 2,
          brightness: Brightness.dark,
        );
        final context = tester.element(find.byType(EditorWorkspace));
        final strings = context.strings;
        final original = current(tester).encode();
        final canvas = find.byKey(const ValueKey('drawing-canvas'));
        final initialCanvas = tester.getRect(canvas);
        expect(initialCanvas.width, greaterThanOrEqualTo(72));
        expect(initialCanvas.height, greaterThanOrEqualTo(72));
        _expectWholeWordsAndVisible(tester, find.text(strings.play));
        await tester.tap(find.byTooltip(strings.play));
        await waitFor(
          tester,
          () => find.byTooltip(strings.pause).evaluate().isNotEmpty,
        );
        _expectWholeWordsAndVisible(tester, find.text(strings.pause));
        expect(tester.getRect(canvas), initialCanvas);
        await tester.tap(find.byTooltip(strings.pause));
        await tester.pumpAndSettle();
        _expectWholeWordsAndVisible(tester, find.text(strings.play));
        expect(tester.getRect(canvas), initialCanvas);
        _expectWholeWordsAndVisible(tester, find.text(strings.draw));
        _expectWholeWordsAndVisible(tester, find.text(strings.erase));
        final tools = find.byKey(const ValueKey('editor-tools'));
        await tester.ensureVisible(tools);
        await tester.pumpAndSettle();
        _expectWholeWordsAndVisible(
          tester,
          find.text(strings.editorToolsShort),
        );
        expect(tools.hitTestable(), findsOneWidget);
        expect(tester.getSize(tools).shortestSide, greaterThanOrEqualTo(48));
        await tester.tap(tools);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('editor-tool-mix')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await chooseEditorVoice(tester, Instrument.saxophone);
        expect(
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).instrument,
          Instrument.saxophone,
        );
        expect(current(tester).encode(), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
