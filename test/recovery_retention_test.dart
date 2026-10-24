import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';

void main() {
  late Directory root;
  late FileProjectRepository repository;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('retention-test');
    repository = FileProjectRepository(root);
  });
  tearDown(() async => root.delete(recursive: true));
  File revision(int number) =>
      File('${root.path}/drawing/r${number.toString().padLeft(12, '0')}.json');
  test('corrupt ordinals do not evict the last usable backup', () async {
    final document = ProjectDocument(
      id: 'drawing',
      title: 'Original',
      strokes: [
        Stroke(
          id: 'mark',
          instrument: Instrument.mallet,
          points: [InkPoint(.2, .4), InkPoint(.8, .6)],
        ),
      ],
    );
    for (var n = 0; n < 3; n++) {
      await repository.save(document.copyWith(revision: n));
    }
    await revision(1).writeAsString('damaged revision one');
    await revision(2).writeAsString('damaged revision two');
    expect((await repository.open(document.id)).recovered, isTrue);
    await repository.save(document.copyWith(title: 'New', revision: 3));
    expect(await revision(0).exists(), isTrue);
    await revision(3).writeAsString('interrupted newest file');
    final recovered = await FileProjectRepository(root).open(document.id);
    expect(recovered.document.revision, 0);
    expect(
      recovered.document.strokes.single.toJson(),
      document.strokes.single.toJson(),
    );
    expect(recovered.recovered, isTrue);
    for (var n = 4; n < 7; n++) {
      await repository.save(document.copyWith(revision: n));
    }
    expect(await revision(0).exists(), isFalse);
    expect(await revision(1).readAsString(), 'damaged revision one');
    expect(await revision(2).readAsString(), 'damaged revision two');
    expect(await revision(3).readAsString(), 'interrupted newest file');
    for (final n in [4, 5, 6]) {
      expect(await revision(n).exists(), isTrue);
    }
    await revision(6).writeAsString('damaged after publication');
    expect((await repository.load(document.id)).revision, 5);
  });
  test('unsupported engine data survives pruning while valid backups remain bounded', () async {
    final document = ProjectDocument(id: 'drawing');
    await repository.save(document);
    final payload = document
        .copyWith(revision: 1)
        .encode()
        .replaceFirst('"engineVersion":1', '"engineVersion":99');
    final future = jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'document': payload,
    });
    await revision(1).writeAsString(future);
    for (var n = 2; n < 6; n++) {
      await repository.save(document.copyWith(revision: n));
    }
    expect(await revision(1).readAsString(), future);
    expect(await revision(0).exists(), isFalse);
    expect(await revision(2).exists(), isFalse);
    for (final n in [3, 4, 5]) {
      expect(await revision(n).exists(), isTrue);
    }
  });
  test(
    'real write failure preserves the published draft and can be retried',
    () async {
      final document = ProjectDocument(
        id: 'drawing',
        background: 0x80f3eef9,
        style: DrawingStyle.pixel,
      );
      await repository.save(document);
      final before = await revision(0).readAsBytes();
      final directory = '${root.path}/drawing';
      final result = await Process.run('chmod', ['500', directory]);
      expect(result.exitCode, 0);
      try {
        await expectLater(
          repository.save(document.copyWith(title: 'Retry me')),
          throwsA(isA<FileSystemException>()),
        );
        expect(await revision(0).readAsBytes(), before);
        expect(
          (await repository.load(document.id)).encode(),
          document.encode(),
        );
      } finally {
        final restored = await Process.run('chmod', ['700', directory]);
        expect(restored.exitCode, 0);
      }
      await repository.save(document.copyWith(title: 'Retry me'));
      final saved = await repository.load(document.id);
      expect(saved.title, 'Retry me');
      expect(saved.background, document.background);
      expect(saved.style, DrawingStyle.pixel);
    },
    skip: !Platform.isLinux,
  );
}
