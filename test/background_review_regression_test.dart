import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/paper_panel.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/data/background_assets.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/export/data/png_document_renderer.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('scribblesong/backgrounds');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => messenger.setMockMethodCallHandler(channel, (_) async => null));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> open(
    WidgetTester tester, {
    BackgroundDefinition? initial,
    BackgroundAssets? assets,
    ValueChanged<BackgroundDefinition?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await showBackgroundPanel(
                  context,
                  initial ?? BackgroundDefinition.solid(0xfff7f5eb),
                  assets: assets,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> kind(WidgetTester tester, String label) async {
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<BackgroundKind>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<BackgroundKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    if (label == 'Photo') {
      // A busy native import must be allowed real filesystem/decoder work;
      // settling an indeterminate spinner alone cannot complete that work.
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  FilledButton apply(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'));

  testWidgets('invalid second color cannot block valid Solid settings', (
    tester,
  ) async {
    await open(tester);
    await kind(tester, 'Linear gradient');
    final second = field('Second color (RRGGBB)');
    await tester.ensureVisible(second);
    await tester.enterText(second, 'ZZZZZZ');
    await tester.pumpAndSettle();
    expect(apply(tester).onPressed, isNull);
    await kind(tester, 'Solid color');
    expect(field('Second color (RRGGBB)'), findsNothing);
    expect(apply(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'valid gradient preset replaces invalid text and clears validation',
    (tester) async {
      BackgroundDefinition? result;
      await open(tester, onResult: (value) => result = value);
      await kind(tester, 'Linear gradient');
      final first = field('Custom color (RRGGBB)');
      await tester.ensureVisible(first);
      await tester.enterText(first, 'XXXXXX');
      final second = field('Second color (RRGGBB)');
      await tester.ensureVisible(second);
      await tester.enterText(second, 'ZZZZZZ');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Dawn gradient'));
      await tester.tap(find.byTooltip('Dawn gradient'));
      await tester.pumpAndSettle();
      final text = tester
          .widget<EditableText>(
            find.descendant(of: second, matching: find.byType(EditableText)),
          )
          .controller
          .text;
      expect(text, 'A4C9CE');
      expect(tester.widget<TextField>(first).controller!.text, 'F5D8B0');
      expect(apply(tester).onPressed, isNotNull);
      await tester.ensureVisible(second);
      await tester.enterText(second, '123ABC');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.colors, [0xfff5d8b0, 0xff123abc]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'canceling a Photo type selection retains the visible gradient and its relevant validation',
    (tester) async {
      await open(tester);
      await kind(tester, 'Linear gradient');
      final second = field('Second color (RRGGBB)');
      await tester.ensureVisible(second);
      await tester.enterText(second, 'ZZZZZZ');
      await tester.pumpAndSettle();
      await kind(tester, 'Photo');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<BackgroundKind>>(
              find.byType(DropdownButtonFormField<BackgroundKind>),
            )
            .initialValue,
        BackgroundKind.linear,
      );
      expect(second, findsOneWidget);
      expect(tester.widget<TextField>(second).controller!.text, 'ZZZZZZ');
      expect(apply(tester).onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preview actual constrained layout preserves 4:5 document aspect',
    (tester) async {
      await open(tester);
      final size = tester.getSize(find.byKey(const ValueKey('paper-preview')));
      expect(size.width / size.height, closeTo(.8, .00001));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'type round trips restore last valid palette and relevant invalid input remains blocked',
    (tester) async {
      BackgroundDefinition? result;
      await open(tester, onResult: (value) => result = value);
      await kind(tester, 'Linear gradient');
      final first = field('Custom color (RRGGBB)'),
          second = field('Second color (RRGGBB)');
      await tester.ensureVisible(second);
      await tester.enterText(second, 'ABCDEF');
      await tester.pumpAndSettle();
      await kind(tester, 'Solid color');
      expect(apply(tester).onPressed, isNotNull);
      await tester.ensureVisible(first);
      await tester.enterText(first, 'NOTHEX');
      await tester.pumpAndSettle();
      expect(apply(tester).onPressed, isNull);
      await kind(tester, 'Radial gradient');
      expect(tester.widget<TextField>(first).controller!.text, 'F7F5EB');
      expect(tester.widget<TextField>(second).controller!.text, 'ABCDEF');
      expect(apply(tester).onPressed, isNotNull);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.kind, BackgroundKind.radial);
      expect(result!.colors, [0xfff7f5eb, 0xffabcdef]);
    },
  );

  for (final colors in const [
    [0xff112233, 0xff445566, 0xff778899],
    [0xff112233, 0xff445566, 0xff778899, 0xffaabbdd],
  ]) {
    testWidgets(
      '${colors.length}-stop gradient Second field edits index1 and valid preset replaces the whole palette',
      (tester) async {
        final initial = BackgroundDefinition(
          kind: BackgroundKind.linear,
          colors: colors,
        );
        BackgroundDefinition? result;
        await open(
          tester,
          initial: initial,
          onResult: (value) => result = value,
        );
        final first = field('Custom color (RRGGBB)'),
            second = field('Second color (RRGGBB)');
        expect(tester.widget<TextField>(second).controller!.text, '445566');
        await tester.ensureVisible(second);
        await tester.enterText(second, 'AABBCC');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(result!.colors, [colors.first, 0xffaabbcc, ...colors.skip(2)]);
        expect(initial.colors, colors);
        await open(
          tester,
          initial: result,
          onResult: (value) => result = value,
        );
        expect(tester.widget<TextField>(second).controller!.text, 'AABBCC');
        await tester.ensureVisible(first);
        await tester.enterText(first, 'ZZZZZZ');
        await tester.ensureVisible(second);
        await tester.enterText(second, 'XXXXXX');
        await tester.pumpAndSettle();
        expect(apply(tester).onPressed, isNull);
        await tester.ensureVisible(find.byTooltip('Dawn gradient'));
        await tester.tap(find.byTooltip('Dawn gradient'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(first).controller!.text, 'F5D8B0');
        expect(tester.widget<TextField>(second).controller!.text, 'A4C9CE');
        expect(apply(tester).onPressed, isNotNull);
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(result!.colors, [0xfff5d8b0, 0xffa4c9ce]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<
    ({
      BackgroundAssets assets,
      BackgroundDefinition paper,
      int width,
      int height,
      int bytes,
    })
  >
  photo(WidgetTester tester, int width, int height) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('background-review-'),
    );
    final assets = BackgroundAssets(root!);
    addTearDown(() => root.delete(recursive: true));
    final recorder = ui.PictureRecorder();
    // Independent asymmetric source: red encodes horizontal position and green
    // vertical position, so a wrong cover crop cannot hide behind symmetry.
    final sourceCanvas = ui.Canvas(recorder);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final red = (x * 255 / (width - 1)).round(),
            green = (y * 255 / (height - 1)).round();
        sourceCanvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          ui.Paint()..color = ui.Color(0xff000020 | red << 16 | green << 8),
        );
      }
    }
    // Keep construction outside the widget's fake clock.
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(width, height));
    final encoded = (await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    ))!.buffer.asUint8List();
    image!.dispose();
    picture.dispose();
    final id = sha256.convert(encoded).toString();
    await tester.runAsync(
      () => assets.file(id).writeAsBytes(encoded, flush: true),
    );
    return (
      assets: assets,
      paper: BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: id,
        crop: const CropWindow(left: .12, top: .17, width: .73, height: .61),
      ),
      width: width,
      height: height,
      bytes: encoded.length,
    );
  }

  Future<void> loaded(WidgetTester tester) async {
    for (var i = 0; i < 100 && apply(tester).onPressed == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(
      apply(tester).onPressed,
      isNotNull,
      reason: 'The actual private image must finish decoding before Apply.',
    );
  }

  testWidgets(
    'invalid manual colors do not block a real imported photo and Cancel preserves original',
    (tester) async {
      final fixture = await photo(tester, 120, 80);
      final original = BackgroundDefinition(
        kind: BackgroundKind.linear,
        colors: [0xff112233, 0xff445566],
      );
      final before = original.toJson();
      BackgroundDefinition? result;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pickPhoto') {
          return {
            'id': fixture.paper.assetId,
            'width': fixture.width,
            'height': fixture.height,
            'bytes': fixture.bytes,
          };
        }
        return null;
      });
      await open(
        tester,
        initial: original,
        assets: fixture.assets,
        onResult: (value) => result = value,
      );
      final first = field('Custom color (RRGGBB)'),
          second = field('Second color (RRGGBB)');
      await tester.ensureVisible(first);
      await tester.enterText(first, 'XXXXXX');
      await tester.ensureVisible(second);
      await tester.enterText(second, 'ZZZZZZ');
      await tester.pumpAndSettle();
      expect(apply(tester).onPressed, isNull);
      await kind(tester, 'Photo');
      await loaded(tester);
      expect(field('Custom color (RRGGBB)'), findsNothing);
      expect(field('Second color (RRGGBB)'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(original.toJson(), before);
      await open(
        tester,
        initial: original,
        assets: fixture.assets,
        onResult: (value) => result = value,
      );
      await kind(tester, 'Photo');
      await loaded(tester);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.kind, BackgroundKind.photo);
      expect(result!.assetId, fixture.paper.assetId);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, height) in [(120, 120), (80, 160), (200, 100)]) {
    for (final (turns, mirror) in [
      (0, false),
      (0, true),
      (1, false),
      (1, true),
      (2, false),
      (2, true),
      (3, false),
      (3, true),
    ]) {
      testWidgets(
        'photo ${width}x$height crop turn$turns mirror$mirror preview matches saved PNG framing',
        (tester) async {
          final fixture = await photo(tester, width, height);
          final paper = fixture.paper.copyWith(
            quarterTurns: turns,
            mirror: mirror,
          );
          await open(tester, initial: paper, assets: fixture.assets);
          await loaded(tester);
          final previewFinder = find.byKey(const ValueKey('paper-preview'));
          await tester.ensureVisible(previewFinder);
          await tester.pumpAndSettle();
          final size = tester.getSize(previewFinder);
          expect(size.width / size.height, closeTo(.8, .00001));
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('paper-preview-boundary')),
          );
          final preview = await tester.runAsync(
            () => boundary.toImage(pixelRatio: 1),
          );
          final previewData = (await tester.runAsync(
            () => preview!.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!.buffer.asUint8List();
          final png = await tester.runAsync(
            () => renderDocumentPng(
              ProjectDocument(id: 'preview-parity', paper: paper),
              ExportCancellation(),
              width: 640,
              assets: fixture.assets,
            ),
          );
          final codec = await tester.runAsync(
            () => ui.instantiateImageCodec(png!),
          );
          final finalImage = (await tester.runAsync(
            () => codec!.getNextFrame(),
          ))!.image;
          final finalData = (await tester.runAsync(
            () => finalImage.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!.buffer.asUint8List();
          try {
            for (final u in [.1, .3, .7, .9]) {
              for (final v in [.1, .3, .7, .9]) {
                final px = (preview!.width * u).floor(),
                    py = (preview.height * v).floor();
                final fx = (finalImage.width * u).floor(),
                    fy = (finalImage.height * v).floor();
                for (var channel = 0; channel < 3; channel++) {
                  expect(
                    previewData[(py * preview.width + px) * 4 + channel],
                    closeTo(
                      finalData[(fy * finalImage.width + fx) * 4 + channel],
                      3,
                    ),
                    reason:
                        'source $width x $height turn $turns mirror $mirror at $u,$v channel $channel',
                  );
                }
                // Independent inverse transform of the declared source crop.
                final tw = turns.isOdd ? size.height : size.width,
                    th = turns.isOdd ? size.width : size.height;
                final cw = paper.crop.width * width,
                    ch = paper.crop.height * height;
                final ratio = math.max(tw / cw, th / ch),
                    sw = tw / ratio,
                    sh = th / ratio;
                var x = px + .5 - size.width / 2, y = py + .5 - size.height / 2;
                for (var i = 0; i < turns; i++) {
                  final previous = x;
                  x = y;
                  y = -previous;
                }
                if (mirror) x = -x;
                final sourceX =
                    paper.crop.left * width +
                    (cw - sw) / 2 +
                    (x / tw + .5) * sw;
                final sourceY =
                    paper.crop.top * height +
                    (ch - sh) / 2 +
                    (y / th + .5) * sh;
                expect(
                  previewData[(py * preview.width + px) * 4],
                  closeTo((sourceX - .5) * 255 / (width - 1), 3),
                );
                expect(
                  previewData[(py * preview.width + px) * 4 + 1],
                  closeTo((sourceY - .5) * 255 / (height - 1), 3),
                );
              }
            }
          } finally {
            preview!.dispose();
            finalImage.dispose();
            codec!.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets(
      'background controls remain reachable at $size with 200 percent text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await open(tester);
        final preview = find.byKey(const ValueKey('paper-preview'));
        expect(tester.getSize(preview).aspectRatio, closeTo(.8, .00001));
        await tester.ensureVisible(field('Custom color (RRGGBB)'));
        await tester.enterText(field('Custom color (RRGGBB)'), 'ABC123');
        await tester.pumpAndSettle();
        expect(find.text('Apply').hitTestable(), findsOneWidget);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(apply(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  }
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets(
      'photo crop rotation controls remain reachable at $size with 200 percent text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = await photo(tester, 160, 80);
        BackgroundDefinition? result;
        await open(
          tester,
          initial: fixture.paper,
          assets: fixture.assets,
          onResult: (value) => result = value,
        );
        await loaded(tester);
        final preview = find.byKey(const ValueKey('paper-preview'));
        expect(tester.getSize(preview).aspectRatio, closeTo(.8, .00001));
        await tester.ensureVisible(find.byTooltip('Rotate photo'));
        await tester.tap(find.byTooltip('Rotate photo'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Mirror photo'));
        await tester.tap(find.byTooltip('Mirror photo'));
        await tester.pumpAndSettle();
        final cropColumn = find
            .ancestor(
              of: find.text('Crop width'),
              matching: find.byType(Column),
            )
            .first;
        final slider = find.descendant(
          of: cropColumn,
          matching: find.byType(Slider),
        );
        await tester.ensureVisible(slider);
        await tester.drag(slider, const Offset(-30, 0));
        await tester.pumpAndSettle();
        expect(find.text('Apply').hitTestable(), findsOneWidget);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(result!.quarterTurns, 1);
        expect(result!.mirror, isTrue);
        expect(result!.crop.width, lessThan(fixture.paper.crop.width));
        expect(result!.assetId, fixture.paper.assetId);
      },
    );
  }
}
