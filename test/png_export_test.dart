import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/data/background_assets.dart';
import 'package:scribblesong/features/export/data/file_image_export_adapter.dart';
import 'package:scribblesong/features/export/data/png_document_renderer.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';

// An independent PNG reader: validates chunk CRCs and reconstructs the PNG
// scanline filters after zlib decompression, rather than trusting export metadata.
class _Png {
  _Png(Uint8List bytes) {
    final header = ByteData.sublistView(bytes);
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final compressed = BytesBuilder();
    var at = 8;
    while (at < bytes.length) {
      final count = header.getUint32(at);
      final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
      final payload = bytes.sublist(at + 8, at + 8 + count);
      var crc = 0xffffffff;
      for (final byte in bytes.sublist(at + 4, at + 8 + count)) {
        crc ^= byte;
        for (var bit = 0; bit < 8; bit++) {
          crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
        }
      }
      expect((crc ^ 0xffffffff) & 0xffffffff, header.getUint32(at + 8 + count));
      if (type == 'IHDR') {
        final ihdr = ByteData.sublistView(payload);
        width = ihdr.getUint32(0);
        height = ihdr.getUint32(4);
        expect(payload[8], 8);
        channels = switch (payload[9]) {
          2 => 3,
          6 => 4,
          _ => throw StateError('Unsupported PNG test format'),
        };
        expect(payload[12], 0); // Noninterlaced document raster.
      } else if (type == 'IDAT') {
        compressed.add(payload);
      }
      at += 12 + count;
      if (type == 'IEND') break;
    }
    final filtered = zlib.decode(compressed.takeBytes());
    expect(filtered.length, (width * channels + 1) * height);
    pixels = Uint8List(width * height * channels);
    final stride = width * channels;
    var source = 0;
    for (var row = 0; row < height; row++) {
      final filter = filtered[source++];
      for (var column = 0; column < stride; column++) {
        final target = row * stride + column;
        final a = column >= channels ? pixels[target - channels] : 0;
        final b = row > 0 ? pixels[target - stride] : 0;
        final c = row > 0 && column >= channels
            ? pixels[target - stride - channels]
            : 0;
        final predictor = switch (filter) {
          0 => 0,
          1 => a,
          2 => b,
          3 => (a + b) ~/ 2,
          4 => _paeth(a, b, c),
          _ => throw StateError('Invalid PNG filter'),
        };
        pixels[target] = (filtered[source++] + predictor) & 255;
      }
    }
  }
  late final int width, height, channels;
  late final Uint8List pixels;
  List<int> pixel(int x, int y) {
    final at = (y * width + x) * channels;
    return [
      ...pixels.sublist(at, at + 3),
      channels == 4 ? pixels[at + 3] : 255,
    ];
  }

  static int _paeth(int a, int b, int c) {
    final p = a + b - c,
        pa = (p - a).abs(),
        pb = (p - b).abs(),
        pc = (p - c).abs();
    return pa <= pb && pa <= pc
        ? a
        : pb <= pc
        ? b
        : c;
  }
}

ProjectDocument _sample({
  DrawingStyle style = DrawingStyle.smooth,
  BackgroundDefinition? paper,
}) => ProjectDocument(
  id: 'png-real',
  title: 'Rain 音',
  background: 0xfff7f5eb,
  style: style,
  paper: paper,
  strokes: [
    Stroke(
      id: 'line',
      instrument: Instrument.keys,
      points: [InkPoint(.25, .5), InkPoint(.75, .5)],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PNG native file-action contract sends the exact image and handles canceled public saving honestly', () async {
    const channel = MethodChannel('scribblesong/export-files');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var cancelSave = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'save') {
        return cancelSave
            ? {'cancelled': true}
            : {
                'uri': 'content://downloads/image',
                'bytes': 1234,
                'destination': 'Downloads/DrawMusic',
              };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const artifact = ExportArtifact(
      '/private/exports/still.png',
      'image/png',
      '雨の絵.png',
      'png-contract',
      2,
      width: 640,
      height: 800,
    );
    final actions = AndroidExportFileActions();
    await actions.open(artifact);
    final saved = await actions.save(artifact);
    expect(saved!.bytes, 1234);
    for (final call in calls) {
      expect(call.arguments, {
        'path': artifact.path,
        'name': '雨の絵.png',
        'mime': 'image/png',
      });
    }
    cancelSave = true;
    expect(await actions.save(artifact), isNull);
    expect(calls.map((c) => c.method), ['open', 'save', 'save']);
  });
  test('real PNG parses independently: both sizes, exact geometry and paper, no cursor or mutation', () async {
    final document = _sample();
    final before = document.encode();
    for (final width in [640, 1080]) {
      final png = _Png(
        await renderDocumentPng(document, ExportCancellation(), width: width),
      );
      expect(png.width, width);
      expect(png.height, width * 5 ~/ 4);
      expect(png.pixel(width ~/ 2, png.height ~/ 2), [121, 97, 198, 255]);
      expect(png.pixel(0, 0), [247, 245, 235, 255]);
      // Cursor starts at x=0 in the editor; it must never be in a still export.
      expect(png.pixel(0, png.height ~/ 2), [247, 245, 235, 255]);
    }
    expect(document.encode(), before);
  });
  test(
    'transparent PNG omits background, retains ink and exact fixed Pixel grid',
    () async {
      final png = _Png(
        await renderDocumentPng(
          _sample(style: DrawingStyle.pixel),
          ExportCancellation(),
          width: 640,
          transparentBackground: true,
        ),
      );
      expect(png.pixel(0, 0)[3], 0);
      expect(png.pixel(320, 405), [121, 97, 198, 255]);
      expect(png.pixel(320, 420)[3], 0);
    },
  );
  test('gradient backgrounds render and missing photo fails instead of publishing a substitute', () async {
    final gradient = BackgroundDefinition(
      kind: BackgroundKind.linear,
      colors: [0xffff0000, 0xff0000ff],
    );
    final png = _Png(
      await renderDocumentPng(
        _sample(paper: gradient),
        ExportCancellation(),
        width: 640,
      ),
    );
    expect(png.pixel(10, 10)[0], greaterThan(240));
    expect(png.pixel(630, 790)[2], greaterThan(240));
    final root = await Directory.systemTemp.createTemp('png-missing-photo');
    addTearDown(() => root.delete(recursive: true));
    final missing = _sample(
      paper: BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: '0' * 64,
      ),
    );
    await expectLater(
      renderDocumentPng(
        missing,
        ExportCancellation(),
        width: 640,
        assets: BackgroundAssets(root),
      ),
      throwsFormatException,
    );
    // An explicitly transparent export can still recover just the drawing.
    final transparent = _Png(
      await renderDocumentPng(
        missing,
        ExportCancellation(),
        width: 640,
        transparentBackground: true,
      ),
    );
    expect(transparent.pixel(0, 0)[3], 0);
  });
  test(
    'photo asset crop/rotation is used in exported pixels with bounded decode',
    () async {
      final root = await Directory.systemTemp.createTemp('png-photo');
      addTearDown(() => root.delete(recursive: true));
      final source = await renderDocumentPng(
        ProjectDocument(id: 'photo', background: 0xff22aa44),
        ExportCancellation(),
        width: 640,
      );
      final id = sha256.convert(source).toString();
      await File('${root.path}/$id.png').writeAsBytes(source);
      final photo = BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: id,
        quarterTurns: 1,
        crop: const CropWindow(left: .1, top: .1, width: .8, height: .8),
      );
      final output = _Png(
        await renderDocumentPng(
          _sample(paper: photo),
          ExportCancellation(),
          width: 640,
          assets: BackgroundAssets(root),
        ),
      );
      expect(output.pixel(10, 10), [34, 170, 68, 255]);
    },
  );
  test('atomic PNG library: discover, rename, recreate, delete/Undo preserve real bytes and source', () async {
    final root = await Directory.systemTemp.createTemp('png-library');
    addTearDown(() => root.delete(recursive: true));
    final doc = _sample();
    final before = doc.encode();
    final artifact = await FileImageExportAdapter(root)
        .exportImage(doc, ExportCancellation(), width: 640);
    final bytes = await File(artifact.path).readAsBytes();
    final decoded = _Png(bytes);
    expect(decoded.width, 640);
    expect(artifact.mime, 'image/png');
    expect(artifact.name, 'Rain 音.png');
    final library = FileExportLibrary(root);
    await library.record(artifact, doc);
    final id = (await library.list()).entries.single.id;
    await library.rename(id, 'Still image');
    final entry = (await FileExportLibrary(root).list()).entries.single;
    expect(entry.available, isTrue);
    expect(entry.artifact.name, 'Still image.png');
    expect(entry.artifact.width, 640);
    expect(entry.artifact.height, 800);
    await library.remove(id);
    expect((await library.list()).entries, isEmpty);
    await library.restore(id);
    expect((await library.list()).entries.single.available, isTrue);
    expect(await File(artifact.path).readAsBytes(), bytes);
    expect(doc.encode(), before);
  });
  test('cancel before, during drawing, writing and final publication never leaves a library artifact', () async {
    final root = await Directory.systemTemp.createTemp('png-cancel');
    addTearDown(() => root.delete(recursive: true));
    for (final threshold in [0.0, .1, .6, .85, .95, 1.0]) {
      final cancellation = ExportCancellation();
      await expectLater(
        FileImageExportAdapter(root).exportImage(
          _sample(),
          cancellation,
          width: 640,
          onProgress: (p) {
            if (p >= threshold) cancellation.cancelled = true;
          },
        ),
        throwsA(isA<ExportCancelled>()),
      );
      expect(await root.list().toList(), isEmpty);
      expect((await FileExportLibrary(root).list()).entries, isEmpty);
    }
  });
  test('invalid dimensions, corrupt raster and output errors never publish success', () async {
    final root = await Directory.systemTemp.createTemp('png-fail');
    addTearDown(() => root.delete(recursive: true));
    await expectLater(
      FileImageExportAdapter(root)
          .exportImage(_sample(), ExportCancellation(), width: 16384),
      throwsFormatException,
    );
    await expectLater(
      FileImageExportAdapter(
        root,
        rasterizer: (
          _,
          _, {
          required width,
          required transparentBackground,
          onProgress,
        }) async => Uint8List(64),
      ).exportImage(_sample(), ExportCancellation(), width: 640),
      throwsFormatException,
    );
    final unavailable = File('${root.path}/not-a-directory');
    await unavailable.writeAsString('preserved');
    await expectLater(
      FileImageExportAdapter(Directory(unavailable.path))
          .exportImage(_sample(), ExportCancellation(), width: 640),
      throwsA(isA<FileSystemException>()),
    );
    expect(await unavailable.readAsString(), 'preserved');
    expect((await FileExportLibrary(root).list()).entries, isEmpty);
  });
}
