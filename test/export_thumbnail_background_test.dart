import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/presentation/background_surface.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

const _captureKey = ValueKey('library-capture');

LibraryExport _entry(
  ProjectDocument saved, {
  String id = 'saved.mp4',
}) => LibraryExport(
  id: id,
  artifact: ExportArtifact(
    '/test/exports/$id',
    'video/mp4',
    id,
    saved.id,
    saved.revision,
  ),
  createdAt: DateTime.utc(2026, 10, 27),
  bytes: 1234,
  available: true,
  // Catalog-only MP4 fixture: this test exercises actual thumbnail rendering,
  // not video encoding. Encode/decode models the persisted export snapshot.
  preview: ProjectDocument.decode(saved.encode()),
);

Future<void> _pumpLibrary(
  WidgetTester tester,
  List<LibraryExport> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exportListingProvider.overrideWith(
          (ref) async => ExportListing(entries),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(key: _captureKey, child: ExportsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<int>> _pixel(
  WidgetTester tester, {
  Offset fraction = const Offset(.5, .5),
  int tile = 0,
}) async {
  final listTile = tester.widget<ListTile>(find.byType(ListTile).at(tile));
  final leading = find.byWidget(listTile.leading!);
  final box = tester.getRect(leading);
  final point = Offset(
    box.left + box.width * fraction.dx,
    box.top + box.height * fraction.dy,
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      return bytes.buffer
          .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
          .sublist(at, at + 4);
    } finally {
      image.dispose();
    }
  }))!;
}

Future<Uint8List> _quadrants() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (final (rect, color) in [
    (const ui.Rect.fromLTWH(0, 0, 200, 250), 0xffff0000),
    (const ui.Rect.fromLTWH(200, 0, 200, 250), 0xff00ff00),
    (const ui.Rect.fromLTWH(0, 250, 200, 250), 0xff0000ff),
    (const ui.Rect.fromLTWH(200, 250, 200, 250), 0xffffff00),
  ]) {
    canvas.drawRect(rect, ui.Paint()..color = ui.Color(color));
  }
  final picture = recorder.endRecording();
  ui.Image? image;
  try {
    image = await picture.toImage(400, 500);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image?.dispose();
    picture.dispose();
  }
}

Future<List<int>> _waitForPixel(
  WidgetTester tester,
  bool Function(List<int>) ready, {
  Offset fraction = const Offset(.5, .5),
}) async {
  var pixel = <int>[];
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
    pixel = await _pixel(tester, fraction: fraction);
    if (ready(pixel)) return pixel;
  }
  fail('Thumbnail never rendered expected photo pixels; last RGBA=$pixel');
}

void main() {
  testWidgets(
    'MP4 thumbnail renders saved red/blue gradient instead of legacy beige',
    (tester) async {
      final saved = ProjectDocument(
        id: 'gradient',
        paper: BackgroundDefinition(
          kind: BackgroundKind.linear,
          colors: [0xffff0000, 0xff0000ff],
        ),
      );
      await _pumpLibrary(tester, [_entry(saved)]);
      final size = tester.getSize(find.byType(BackgroundSurface));
      expect(size.width / size.height, closeTo(.8, .00001));
      final pixel = await _pixel(tester);
      expect(
        pixel[1],
        lessThan(40),
        reason: 'saved gradient has no green; beige legacy paper has green245',
      );
      expect(pixel[0], inInclusiveRange(110, 145));
      expect(pixel[2], inInclusiveRange(110, 145));
      expect(pixel[3], 255);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('saved MP4 gradient and opacity stay frozen after source edits', (
    tester,
  ) async {
    var source = ProjectDocument(
      id: 'edited-source',
      revision: 7,
      paper: BackgroundDefinition(
        kind: BackgroundKind.linear,
        colors: [0xffff0000, 0xff0000ff],
        opacity: .5,
      ),
    );
    final exported = _entry(source);
    final frozen = exported.preview!.encode();
    source = source.copyWith(paper: BackgroundDefinition.solid(0xff00ff00));
    await _pumpLibrary(tester, [exported]);
    final pixel = await _pixel(tester);
    expect(pixel[1], inInclusiveRange(126, 129));
    expect(pixel[0], inInclusiveRange(180, 202));
    expect(pixel[2], inInclusiveRange(180, 202));
    expect(exported.preview!.encode(), frozen);
    expect(exported.artifact.revision, 7);
    expect(source.revision, 8);
    expect(source.effectiveBackground.colors, [0xff00ff00]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'MP4 photo thumbnail applies saved crop, quarter-turn, mirror and opacity with bounded decode',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('export-photo-thumb-'),
      ))!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      final bytes = (await tester.runAsync(_quadrants))!;
      final id = sha256.convert(bytes).toString();
      await tester.runAsync(() async {
        await Directory('${root.path}/backgrounds').create();
        await File('${root.path}/backgrounds/$id.png').writeAsBytes(bytes);
      });
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => root.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final created = <ui.Image>[];
      final pageSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      final previousCreate = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        if (image.width != pageSize.width.round() ||
            image.height != pageSize.height.round()) {
          created.add(image);
        }
      };
      addTearDown(() => ui.Image.onCreate = previousCreate);
      var paper = BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: id,
        crop: const CropWindow(left: .5, top: 0, width: .5, height: .5),
      );
      // Crop isolates the green upper-right quadrant before all transforms.
      final cropOnly = _entry(ProjectDocument(id: 'photo-crop', paper: paper));
      await _pumpLibrary(tester, [cropOnly]);
      expect(await _waitForPixel(tester, (p) => p[1] > 240 && p[0] < 15), [
        0,
        255,
        0,
        255,
      ]);
      expect(created, isNotEmpty);
      expect(
        created.every((image) => image.width <= 112 && image.height <= 140),
        isTrue,
      );
      paper = paper.copyWith(
        crop: const CropWindow(),
        quarterTurns: 1,
        mirror: true,
        opacity: .5,
      );
      // Mirror then a clockwise quarter-turn maps bottom-right yellow to
      // the thumbnail top-left, and top-left red to bottom-right.
      await tester.pumpWidget(const SizedBox());
      await _pumpLibrary(tester, [
        _entry(ProjectDocument(id: 'photo-transform', paper: paper)),
      ]);
      final transformed = await _waitForPixel(
        tester,
        (p) => p[0] > 240 && p[1] > 240 && p[2] < 150,
        fraction: const Offset(.25, .25),
      );
      expect(transformed.take(2), [255, 255]);
      expect(transformed[2], inInclusiveRange(127, 128));
      expect(transformed[3], 255);
      final bottomRight = await _pixel(
        tester,
        fraction: const Offset(.75, .75),
      );
      expect(bottomRight[0], 255);
      expect(bottomRight[1], inInclusiveRange(127, 128));
      expect(bottomRight[2], inInclusiveRange(127, 128));
      expect(bottomRight[3], 255);
      final frozen = _entry(ProjectDocument(id: 'frozen-photo', paper: paper));
      final before = frozen.preview!.encode();
      final edited = frozen.preview!.copyWith(
        paper: BackgroundDefinition.solid(0xff000000),
      );
      expect(edited.effectiveBackground.kind, BackgroundKind.solid);
      expect(frozen.preview!.encode(), before);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      expect(created.every((image) => image.debugDisposed), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing MP4 photo asset keeps ink accessible with honest missing-image indicator',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('export-missing-thumb-'),
        ))!;
        addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (_) async => root.path);
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final saved = ProjectDocument(
          id: 'missing-photo',
          paper: BackgroundDefinition(
            kind: BackgroundKind.photo,
            assetId: 'f' * 64,
          ),
          strokes: [
            Stroke(
              id: 'ink',
              instrument: Instrument.keys,
              points: [InkPoint(.1, .5), InkPoint(.9, .5)],
              width: .1,
            ),
          ],
        );
        await _pumpLibrary(tester, [_entry(saved)]);
        for (
          var i = 0;
          i < 50 && find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('This photo is unavailable')),
          findsOneWidget,
        );
        expect(await _pixel(tester), [121, 97, 198, 255]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'library scroll and repeated disposal release bounded photo image handles, including late loads',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('export-scroll-thumb-'),
      ))!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      final bytes = (await tester.runAsync(_quadrants))!;
      final id = sha256.convert(bytes).toString();
      await tester.runAsync(() async {
        await Directory('${root.path}/backgrounds').create();
        await File('${root.path}/backgrounds/$id.png').writeAsBytes(bytes);
      });
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var decodeRequests = 0;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          decodeRequests++;
        }
        return root.path;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final created = <ui.Image>[];
      final previousCreate = ui.Image.onCreate;
      final previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        // The source fixture was generated before this hook; this test captures
        // no screenshots. Record ALL decoder handles so oversized images fail.
        created.add(image);
      };
      ui.Image.onDispose = (image) {
        previousDispose?.call(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      });
      Future<void> until(bool Function() condition, String operation) async {
        final deadline = Stopwatch()..start();
        while (!condition()) {
          // Filesystem/codec completions run in real time; their awaiting widget
          // continuations still need a FakeAsync pump. Readiness is the observed
          // request/image condition, never an assumed fixed I/O duration.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pumpAndSettle();
          if (deadline.elapsed > const Duration(seconds: 15)) {
            fail(
              '$operation did not finish: $decodeRequests requests, '
              '${created.length} decoded, '
              '${created.where((image) => image.debugDisposed).length} disposed',
            );
          }
        }
      }

      final paper = BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: id,
      );
      final entries = [
        for (var i = 0; i < 24; i++)
          _entry(
            ProjectDocument(id: 'photo-$i', paper: paper),
            id: 'saved-$i.mp4',
          ),
      ];
      for (var cycle = 0; cycle < 3; cycle++) {
        final beforeMount = decodeRequests;
        await _pumpLibrary(tester, entries);
        await until(
          () => decodeRequests > beforeMount,
          'Initial thumbnail requests',
        );
        await until(
          () => created.length == decodeRequests,
          'Initial thumbnail decodes',
        );
        final beforeScroll = decodeRequests;
        await tester.drag(find.byType(ListView), const Offset(0, -1400));
        await tester.pumpAndSettle();
        await until(
          () => decodeRequests > beforeScroll,
          'Scrolled thumbnail requests',
        );
        await until(
          () => created.length == decodeRequests,
          'Scrolled thumbnail decodes',
        );
        final beforeReturn = decodeRequests;
        await tester.drag(find.byType(ListView), const Offset(0, 1400));
        await tester.pumpAndSettle();
        await until(
          () => decodeRequests > beforeReturn,
          'Returning thumbnail requests',
        );
        // Intentionally dispose before waiting for the returning filesystem /
        // codec work. Late successful decodes must also release their handles.
        await tester.pumpWidget(const SizedBox());
        await until(
          () =>
              created.length == decodeRequests &&
              created.every((image) => image.debugDisposed),
          'Unmounted and late thumbnail disposal',
        );
        expect(tester.takeException(), isNull);
      }
      expect(created.length, greaterThan(6));
      expect(
        created.every((image) => image.width <= 112 && image.height <= 140),
        isTrue,
      );
      expect(
        created.every((image) => image.debugDisposed),
        isTrue,
        reason: 'All on-screen and late background decodes must release their image handles',
      );
    },
  );
}
