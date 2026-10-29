import 'dart:io';
import 'dart:async';
import 'dart:convert';
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

import 'support/export_gallery_navigation.dart';

const _captureKey = ValueKey('library-capture');
const _captureDiagnostics = bool.fromEnvironment('EXPORT_THUMBNAIL_CAPTURE');
var _diagnosticSequence = 0;

class _RecordingOpenActions implements ExportFileActions {
  final opened = <ExportArtifact>[];
  @override
  Future<void> open(ExportArtifact artifact) async => opened.add(artifact);
  @override
  Future<PublicExportCopy?> save(ExportArtifact artifact) async => null;
}

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

// Hold the exact, already decoded chrome asset before observing gallery-owned
// photo handles. Only actual clones of this same native image are chrome; an
// unrelated128×128 photo is still a photo and must satisfy its own role guard.
class _ChromeLease {
  _ChromeLease(this.info);
  final ImageInfo info;
  final created = <ui.Image>[];
  final live = <ui.Image>{};
  var peakLive = 0;
  var _released = false;

  bool record(ui.Image image) {
    if (!image.isCloneOf(info.image)) return false;
    created.add(image);
    live.add(image);
    if (live.length > peakLive) peakLive = live.length;
    return true;
  }

  void disposed(ui.Image image) => live.remove(image);

  void expectGalleryClonesReleased() {
    expect(info.image.width, 128);
    expect(info.image.height, 128);
    expect(info.image.width * info.image.height * 4, 65536);
    expect(created.every((image) => image.isCloneOf(info.image)), isTrue);
    // Only the selector and featured plate use this texture in this fixture.
    expect(peakLive, lessThanOrEqualTo(2));
    expect(live, isEmpty);
    expect(created.every((image) => image.debugDisposed), isTrue);
  }

  void release() {
    if (_released) return;
    _released = true;
    info.dispose();
  }
}

Future<_ChromeLease> _warmChrome(WidgetTester tester) async {
  final data = await tester.runAsync(
    () => File('assets/branding/graphite-grain.png').readAsBytes(),
  );
  expect(
    sha256.convert(data!).toString(),
    '1abd91ffa88167ed36a2cc4a72a6fb24cb57bef3207325b073a2e49b32ec3640',
  );
  final info = (await tester.runAsync(() async {
    final ready = Completer<ImageInfo>();
    final stream = const ExactAssetImage(
      'assets/branding/graphite-grain.png',
      scale: 2,
    ).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (image, synchronous) => ready.complete(image),
      onError: (Object error, StackTrace? stack) =>
          ready.completeError(error, stack),
    );
    stream.addListener(listener);
    try {
      return await ready.future;
    } finally {
      stream.removeListener(listener);
    }
  }))!;
  expect(info.scale, 2);
  expect(info.image.width, 128);
  expect(info.image.height, 128);
  return _ChromeLease(info);
}

Future<void> _pumpLibrary(
  WidgetTester tester,
  List<LibraryExport> entries, {
  ExportFileActions? actions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (actions != null)
          exportFileActionsProvider.overrideWithValue(actions),
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

Finder _thumbnail([String id = 'saved.mp4']) =>
    find.byKey(ValueKey('export-thumbnail-$id'));

Future<void> _revealThumbnail(
  WidgetTester tester, {
  String id = 'saved.mp4',
}) async {
  final tile = _thumbnail(id);
  final list = find.byKey(const PageStorageKey('exports-scroll'));
  final viewport = tester.getRect(list);
  var visible = false;
  if (tile.evaluate().isNotEmpty) {
    final rect = tester.getRect(tile);
    visible =
        viewport.contains(rect.topLeft) &&
        viewport.contains(rect.bottomRight - const Offset(.01, .01)) &&
        tile.hitTestable().evaluate().isNotEmpty;
  }
  if (!visible) await revealExportGalleryItem(tester, tile);
  final rect = tester.getRect(tile);
  expect(rect.left, greaterThanOrEqualTo(viewport.left));
  expect(rect.top, greaterThanOrEqualTo(viewport.top));
  expect(rect.right, lessThanOrEqualTo(viewport.right));
  expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
  expect(tile.hitTestable(), findsOneWidget);
}

Future<List<int>> _pixel(
  WidgetTester tester, {
  Offset fraction = const Offset(.5, .5),
  String id = 'saved.mp4',
}) async {
  await _revealThumbnail(tester, id: id);
  final box = tester.getRect(_thumbnail(id));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final localTopLeft = boundary.globalToLocal(box.topLeft);
  final localBottomRight = boundary.globalToLocal(box.bottomRight);
  expect(localTopLeft.dx, greaterThanOrEqualTo(0));
  expect(localTopLeft.dy, greaterThanOrEqualTo(0));
  expect(localBottomRight.dx, lessThanOrEqualTo(boundary.size.width));
  expect(localBottomRight.dy, lessThanOrEqualTo(boundary.size.height));
  final point = Offset(
    localTopLeft.dx + box.width * fraction.dx,
    localTopLeft.dy + box.height * fraction.dy,
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(point.dx, greaterThanOrEqualTo(0));
      expect(point.dy, greaterThanOrEqualTo(0));
      expect(point.dx, lessThan(image.width));
      expect(point.dy, lessThan(image.height));
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      if (_captureDiagnostics) {
        final directory = Directory('work/graphite-thumbnail-review');
        await directory.create(recursive: true);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/${_diagnosticSequence++}-$id-${fraction.dx}-${fraction.dy}.png',
        ).writeAsBytes(
          png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
      }
      final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      return bytes.buffer
          .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
          .sublist(at, at + 4);
    } finally {
      image.dispose();
    }
  }))!;
}

bool _featuredDecode(ui.Image image) => image.width > 112 || image.height > 140;

void _expectSurfaceRoleLimits(WidgetTester tester) {
  final featured = find.descendant(
    of: find.byKey(const ValueKey('export-featured-artwork')),
    matching: find.byType(BackgroundSurface),
  );
  expect(featured.evaluate().length, lessThanOrEqualTo(1));
  for (final surface in tester.widgetList<BackgroundSurface>(featured)) {
    expect(surface.maxWidth, lessThanOrEqualTo(420));
    expect(surface.maxHeight, lessThanOrEqualTo(525));
  }
  final rows = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('export-thumbnail-'),
  );
  for (final row in rows.evaluate()) {
    final surfaces = find.descendant(
      of: find.byElementPredicate((element) => identical(element, row)),
      matching: find.byType(BackgroundSurface),
    );
    for (final surface in tester.widgetList<BackgroundSurface>(surfaces)) {
      expect(surface.maxWidth, lessThanOrEqualTo(112));
      expect(surface.maxHeight, lessThanOrEqualTo(140));
    }
  }
}

void _expectDecodeRoleBounds(List<ui.Image> images) {
  for (final image in images) {
    if (_featuredDecode(image)) {
      expect(image.width, lessThanOrEqualTo(420));
      expect(image.height, lessThanOrEqualTo(525));
    } else {
      expect(image.width, lessThanOrEqualTo(112));
      expect(image.height, lessThanOrEqualTo(140));
    }
  }
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
      await _revealThumbnail(tester);
      final size = tester.getSize(
        find.descendant(
          of: _thumbnail(),
          matching: find.byType(BackgroundSurface),
        ),
      );
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
      final chrome = await _warmChrome(tester);
      addTearDown(chrome.release);
      final created = <ui.Image>[];
      final pageSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      final previousCreate = ui.Image.onCreate;
      final previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        if (chrome.record(image)) return;
        if (image.width != pageSize.width.round() ||
            image.height != pageSize.height.round()) {
          created.add(image);
        }
      };
      ui.Image.onDispose = (image) {
        previousDispose?.call(image);
        chrome.disposed(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      });
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
      _expectSurfaceRoleLimits(tester);
      _expectDecodeRoleBounds(created);
      expect(created.where(_featuredDecode), hasLength(1));
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
      chrome.expectGalleryClonesReleased();
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
        final actions = _RecordingOpenActions();
        await _pumpLibrary(tester, [_entry(saved)], actions: actions);
        await _revealThumbnail(tester);
        final missing = find.descendant(
          of: _thumbnail(),
          matching: find.byIcon(Icons.broken_image_outlined),
        );
        for (var i = 0; i < 50 && missing.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pumpAndSettle();
        }
        expect(missing, findsOneWidget);
        final notice = find.descendant(
          of: _thumbnail(),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label ==
                    'This photo is unavailable. Replace or remove it.',
          ),
        );
        expect(notice, findsOneWidget);
        expect(
          tester.getSemantics(notice).getSemanticsData().label,
          contains('This photo is unavailable. Replace or remove it.'),
        );
        expect(await _pixel(tester), [121, 97, 198, 255]);
        // The status overlay must not swallow the library file-open action.
        await tester.tapAt(tester.getCenter(missing));
        await tester.pumpAndSettle();
        expect(actions.opened.single.name, 'saved.mp4');
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
      final chrome = await _warmChrome(tester);
      addTearDown(chrome.release);
      final created = <ui.Image>[];
      final live = <ui.Image>{};
      var peakLiveRows = 0, peakLiveFeatured = 0, peakLiveHandles = 0;
      var peakLiveRgbaBytes = 0;
      const maxLiveRows = 8; // The actual800×600 fixture, viewport+cache rows.
      const maxLiveBytes = 420 * 525 * 4 + maxLiveRows * 112 * 140 * 4;
      final previousCreate = ui.Image.onCreate;
      final previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        // The source fixture was generated before this hook; this test captures
        // no screenshots. Exact shared chrome clones are counted separately;
        // ALL remaining photo handles retain the strict role/size budgets.
        if (chrome.record(image)) return;
        created.add(image);
        live.add(image);
        final featured = live.where(_featuredDecode).length;
        final rows = live.length - featured;
        final bytes = live.fold<int>(
          0,
          (sum, image) => sum + image.width * image.height * 4,
        );
        if (rows > peakLiveRows) peakLiveRows = rows;
        if (featured > peakLiveFeatured) peakLiveFeatured = featured;
        if (live.length > peakLiveHandles) peakLiveHandles = live.length;
        if (bytes > peakLiveRgbaBytes) peakLiveRgbaBytes = bytes;
      };
      ui.Image.onDispose = (image) {
        previousDispose?.call(image);
        chrome.disposed(image);
        live.remove(image);
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
        _expectSurfaceRoleLimits(tester);
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
        _expectSurfaceRoleLimits(tester);
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
        chrome.expectGalleryClonesReleased();
        expect(tester.takeException(), isNull);
      }
      expect(created.length, greaterThan(6));
      _expectDecodeRoleBounds(created);
      expect(peakLiveFeatured, lessThanOrEqualTo(1));
      expect(peakLiveRows, lessThanOrEqualTo(maxLiveRows));
      expect(peakLiveHandles, lessThanOrEqualTo(maxLiveRows + 1));
      expect(peakLiveRgbaBytes, lessThanOrEqualTo(maxLiveBytes));
      expect(live, isEmpty);
      debugPrint(
        'EXPORT_LIBRARY_DECODE_PROFILE ${jsonEncode({
          'logicalSize': [tester.view.physicalSize.width / tester.view.devicePixelRatio, tester.view.physicalSize.height / tester.view.devicePixelRatio],
          'testPhysicalSize': [tester.view.physicalSize.width, tester.view.physicalSize.height],
          'devicePixelRatio': tester.view.devicePixelRatio,
          'decodedSizes': created.map((image) => '${image.width}x${image.height}').toSet().toList(),
          'totalDecoderHandles': created.length,
          'peakLiveRows': peakLiveRows,
          'peakLiveFeatured': peakLiveFeatured,
          'peakLiveHandles': peakLiveHandles,
          'peakLiveRgbaBytes': peakLiveRgbaBytes,
          'allDisposed': created.every((image) => image.debugDisposed),
          'chromeSharedPayloadBytes': 65536,
          'chromeCreatedCloneHandles': chrome.created.length,
          'chromePeakLiveCloneHandles': chrome.peakLive,
          'chromeAllClonesDisposed': chrome.created.every((image) => image.debugDisposed),
          'chromeIdentity': 'Exact warmed AssetImage128×128 backing via ui.Image.isCloneOf; not size-only exclusion',
          'scope': 'Widget decoder handles and RGBA arithmetic only; not process RSS, GPU or physical memory.',
        })}',
      );
      expect(
        created.every((image) => image.debugDisposed),
        isTrue,
        reason: 'All on-screen and late background decodes must release their image handles',
      );
    },
  );
}
