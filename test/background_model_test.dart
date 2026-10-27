import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/data/background_assets.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/presentation/background_painter.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';

Future<ui.Image> render(BackgroundDefinition paper, {ui.Image? image}) async {
  final recorder = ui.PictureRecorder();
  paintBackground(
    ui.Canvas(recorder),
    const ui.Rect.fromLTWH(0, 0, 100, 100),
    paper,
    image: image,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(100, 100);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> rgba(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
        .asUint8List();
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('picker validates metadata before acknowledging recovered assets and leaves canceled actions explicit', () async {
    const channel = MethodChannel('scribblesong/backgrounds');
    final calls = <String>[];
    var width = 2048;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'acknowledge') return null;
          if (call.method == 'capture') return {'cancelled': true};
          return {
            'id': 'a' * 64,
            'width': width,
            'height': 1000,
            'bytes': 4096,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final asset = await const BackgroundPicker().recover();
    expect(asset!.id, 'a' * 64);
    expect(calls, ['recover', 'acknowledge']);
    calls.clear();
    expect(await const BackgroundPicker().pick(camera: true), isNull);
    expect(calls, ['capture']);
    width = 4096;
    calls.clear();
    await expectLater(const BackgroundPicker().pick(), throwsFormatException);
    expect(calls, ['pickPhoto']);
  });
  test('background model validates bounded crop/assets and preserves unknown type metadata', () {
    expect(
      () => BackgroundDefinition(kind: BackgroundKind.photo),
      throwsFormatException,
    );
    expect(
      () =>
          BackgroundDefinition(kind: BackgroundKind.solid, opacity: double.nan),
      throwsFormatException,
    );
    expect(
      () => BackgroundDefinition(
        kind: BackgroundKind.solid,
        crop: const CropWindow(left: .9, width: .5),
      ),
      throwsFormatException,
    );
    expect(
      () => BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: '../../other',
      ),
      throwsFormatException,
    );
    final future = BackgroundDefinition.fromJson({
      'kind': 'future-violet',
      'colors': [0xffabcdef],
      'opacity': .5,
      'quarterTurns': 2,
      'mirror': true,
    });
    expect(future.kind, BackgroundKind.solid);
    expect(future.unknownKind, 'future-violet');
    expect(future.toJson()['kind'], 'future-violet');
    final crop = CropWindow.fromJson([.1, .2, .8, .6]);
    expect(crop.toJson(), [.1, .2, .8, .6]);
  });
  test('gradients crop transform and opacity persist without changing notes or PCM', () async {
    final root = await Directory.systemTemp.createTemp('background-revisions-');
    addTearDown(() => root.delete(recursive: true));
    final original = ProjectDocument(
      id: 'backgrounds',
      strokes: [
        Stroke(
          id: 'line',
          instrument: Instrument.keys,
          points: [InkPoint(.1, .4), InkPoint(.8, .4)],
        ),
      ],
    );
    final score = compileScore(original);
    final pcm = renderPcm(score);
    final paper = BackgroundDefinition(
      kind: BackgroundKind.radial,
      colors: [0xffeeccaa, 0xff112233],
      opacity: .45,
      quarterTurns: 1,
      mirror: true,
      crop: const CropWindow(left: .1, width: .9),
    );
    final document = original.copyWith(paper: paper);
    final repository = FileProjectRepository(root);
    await repository.save(document);
    final reopened = await repository.load(document.id);
    expect(reopened.paper!.toJson(), paper.toJson());
    expect(reopened.formatVersion, 2);
    expect(reopened.soundVersion, 1);
    expect(
      compileScore(reopened).notes.map((n) => n.fixture),
      score.notes.map((n) => n.fixture),
    );
    expect(renderPcm(compileScore(reopened)), pcm);
  });
  test('shared gradient painter produces actual interpolated opaque output and transparent color composition', () async {
    final image = await render(
      BackgroundDefinition(
        kind: BackgroundKind.linear,
        colors: [0xffff0000, 0xff0000ff],
      ),
    );
    addTearDown(image.dispose);
    final bytes = await rgba(image);
    int at(int x, int y, int channel) => bytes[(y * 100 + x) * 4 + channel];
    expect(at(0, 0, 0), greaterThan(240));
    expect(at(99, 99, 2), greaterThan(240));
    expect(at(50, 50, 0), inInclusiveRange(120, 135));
    expect(at(50, 50, 2), inInclusiveRange(120, 135));
    expect(at(50, 50, 3), 255);
    final faded = await render(BackgroundDefinition.solid(0x80000000));
    addTearDown(faded.dispose);
    final fadedBytes = await rgba(faded);
    expect(fadedBytes.take(4), [127, 127, 127, 255]);
  });
  test('content-addressed image loading rejects tampering and preserves shared assets on missing references', () async {
    final root = await Directory.systemTemp.createTemp('background-assets-');
    addTearDown(() => root.delete(recursive: true));
    final image = await render(
      BackgroundDefinition(
        kind: BackgroundKind.linear,
        colors: [0xffff0000, 0xff0000ff],
      ),
    );
    addTearDown(image.dispose);
    final encoded = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    final id = sha256.convert(encoded).toString();
    final assets = BackgroundAssets(root);
    await assets.file(id).writeAsBytes(encoded, flush: true);
    final photo = BackgroundDefinition(kind: BackgroundKind.photo, assetId: id);
    final decoded = await assets.decode(photo, maxWidth: 20, maxHeight: 30);
    addTearDown(() => decoded?.dispose());
    expect(decoded!.width, 20);
    expect(decoded.height, 20);
    final duplicate = ProjectDocument(id: 'duplicate', paper: photo);
    expect(ProjectDocument.decode(duplicate.encode()).paper!.assetId, id);
    expect(
      await assets.decode(
        BackgroundDefinition(kind: BackgroundKind.photo, assetId: '0' * 64),
      ),
      isNull,
    );
    expect(await assets.file(id).exists(), isTrue);
    await assets.file(id).writeAsBytes([1, 2, 3]);
    await expectLater(assets.decode(photo), throwsFormatException);
  });
  test('photo crop quarter rotation and mirror use the same source image, never notes', () async {
    final source = await render(
      BackgroundDefinition(
        kind: BackgroundKind.linear,
        colors: [0xffff0000, 0xff0000ff],
      ),
    );
    addTearDown(source.dispose);
    final original = BackgroundDefinition(
      kind: BackgroundKind.photo,
      assetId: 'a' * 64,
      crop: const CropWindow(left: 0, top: 0, width: .5, height: .5),
    );
    final a = await render(original, image: source),
        b = await render(original.copyWith(quarterTurns: 2), image: source);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final pa = await rgba(a), pb = await rgba(b);
    expect(pb, isNot(equals(pa))); // Rotation changes visible sampling.
    expect(pa[3], 255);
    expect(pb[3], 255);
  });
}
