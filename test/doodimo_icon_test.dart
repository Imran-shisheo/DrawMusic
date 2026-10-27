import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/doodimo_icon.dart';
import 'package:scribblesong/design_system/theme.dart';

const _paintKey = ValueKey('icon-pixels');

Future<Uint8List> _pixels(
  WidgetTester tester,
  DoodimoGlyph glyph, {
  bool rtl = false,
  IconThemeData? iconTheme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: _paintKey,
            child: IconTheme(
              data: iconTheme ?? const IconThemeData(color: Color(0xff223c35)),
              child: DoodimoIcon(glyph),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_paintKey))
        .toImage(pixelRatio: 1);
    try {
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  testWidgets(
    'all original glyphs contain bounded visible ink at their actual 24px optical size',
    (tester) async {
      for (final glyph in DoodimoGlyph.values) {
        final pixels = await _pixels(tester, glyph);
        var ink = 0;
        for (var y = 0; y < 24; y++) {
          for (var x = 0; x < 24; x++) {
            if (pixels[(y * 24 + x) * 4 + 3] > 0) {
              ink++;
              expect(
                x,
                inInclusiveRange(1, 22),
                reason: '${glyph.name} horizontal optical inset',
              );
              expect(
                y,
                inInclusiveRange(1, 22),
                reason: '${glyph.name} vertical optical inset',
              );
            }
          }
        }
        expect(
          ink,
          greaterThan(30),
          reason: '${glyph.name} cannot be an empty decorative control',
        );
      }
    },
  );
  testWidgets(
    'directional actions mirror in RTL while play and musical symbols keep their meaning',
    (tester) async {
      for (final glyph in [
        DoodimoGlyph.back,
        DoodimoGlyph.undo,
        DoodimoGlyph.redo,
        DoodimoGlyph.arrowUpRight,
        DoodimoGlyph.play,
        DoodimoGlyph.music,
        DoodimoGlyph.voice,
      ]) {
        final ltr = await _pixels(tester, glyph),
            rtl = await _pixels(tester, glyph, rtl: true);
        final directional = [
          DoodimoGlyph.back,
          DoodimoGlyph.undo,
          DoodimoGlyph.redo,
          DoodimoGlyph.arrowUpRight,
        ].contains(glyph);
        if (!directional) {
          expect(
            rtl,
            ltr,
            reason: '${glyph.name}: musical symbols never mirror',
          );
        } else {
          var mirroredCoverageDifference = 0;
          var unmirroredCoverageDifference = 0;
          for (var y = 0; y < 24; y++) {
            for (var x = 0; x < 24; x++) {
              final observed = rtl[(y * 24 + x) * 4 + 3];
              mirroredCoverageDifference +=
                  (observed - ltr[(y * 24 + 23 - x) * 4 + 3]).abs();
              unmirroredCoverageDifference +=
                  (observed - ltr[(y * 24 + x) * 4 + 3]).abs();
            }
          }
          // Opposite stroke windings can quantize antialias edge coverage
          // slightly differently. The mean must differ by <1 alpha level.
          expect(
            mirroredCoverageDifference / 576,
            lessThan(1),
            reason: '${glyph.name}: reflected stroke coverage',
          );
          expect(
            unmirroredCoverageDifference,
            greaterThan(100),
            reason: '${glyph.name}: RTL action must actually reverse',
          );
        }
      }
    },
  );
  testWidgets('icon color and disabled opacity follow the host IconTheme', (
    tester,
  ) async {
    final data = await _pixels(
      tester,
      DoodimoGlyph.play,
      iconTheme: const IconThemeData(color: Color(0x80223c35), opacity: .5),
    );
    final alphas = [for (var i = 3; i < data.length; i += 4) data[i]];
    expect(alphas.reduce((a, b) => a > b ? a : b), inInclusiveRange(63, 65));
  });
  testWidgets(
    'custom glyphs keep labeled 48dp button targets and optional image semantics',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  children: [
                    for (final glyph in DoodimoGlyph.values)
                      IconButton(
                        onPressed: () {},
                        tooltip: glyph.name,
                        icon: DoodimoIcon(glyph),
                      ),
                    const DoodimoIcon(
                      DoodimoGlyph.voice,
                      semanticLabel: 'Creative voice illustration',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Creative voice illustration'),
          findsOneWidget,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('render an actual-font icon contact sheet for optical review', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final loader = FontLoader('NunitoSans')
        ..addFont(
          File('assets/fonts/NunitoSans/NunitoSans-Regular.ttf')
              .readAsBytes()
              .then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    });
    tester.view.physicalSize = const Size(640, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: RepaintBoundary(
          key: _paintKey,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Doodimo · original line glyphs',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    '24 px · round 1.85-unit strokes · no icon font',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final glyph in DoodimoGlyph.values)
                        SizedBox(
                          width: 92,
                          height: 76,
                          child: Column(
                            children: [
                              DoodimoIcon(glyph),
                              const SizedBox(height: 9),
                              Text(
                                glyph.name,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'RTL: arrows mirror; playback and music stay fixed',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        DoodimoIcon(DoodimoGlyph.back),
                        DoodimoIcon(DoodimoGlyph.undo),
                        DoodimoIcon(DoodimoGlyph.redo),
                        DoodimoIcon(DoodimoGlyph.arrowUpRight),
                        DoodimoIcon(DoodimoGlyph.play),
                        DoodimoIcon(DoodimoGlyph.music),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(_paintKey))
          .toImage(pixelRatio: 1);
      try {
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final folder = Directory('work/ui-icons');
        await folder.create(recursive: true);
        await File('${folder.path}/contact-sheet.png').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    });
    expect(tester.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('DOODIMO_ICON_CAPTURE'));
}
