import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';

void main() {
  late Directory root;
  late FileProjectRepository repo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('drawmusic-project-test');
    repo = FileProjectRepository(root);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test('save and reopen preserve complete editable music document', () async {
    final doc = ProjectDocument(
      id: 'original',
      title: 'My song',
      tempo: 157,
      scale: MusicalScale.minor,
      background: 0xffeef5f1,
      strokes: [
        Stroke(
          id: 'star',
          instrument: Instrument.bell,
          points: [InkPoint(.1, .5, 10), InkPoint(.8, .2, 800)],
        ),
      ],
    );
    await repo.save(doc);
    final reopened = await FileProjectRepository(root).load(doc.id);
    expect(reopened.encode(), doc.encode());
    expect((await repo.list()).projects.single.id, doc.id);
  });
  test(
    'truncated newest revision falls back, and incomplete temps are ignored',
    () async {
      final doc = ProjectDocument(id: 'recover');
      await repo.save(doc);
      await repo.save(doc.copyWith(title: 'New revision'));
      await File('${root.path}/recover/r000000000001.json')
          .writeAsString('{broken');
      await File('${root.path}/recover/r000000000099.json.tmp')
          .writeAsString('unfinished');
      expect((await repo.load('recover')).title, doc.title);
      expect((await repo.list()).failures, isEmpty);
    },
  );
  test('stale save cannot overwrite newer revision and corrupt projects stay isolated', () async {
    final doc = ProjectDocument(id: 'good');
    await Future.wait([repo.save(doc.copyWith(revision: 4)), repo.save(doc)]);
    expect((await repo.load('good')).revision, 4);
    await Directory('${root.path}/bad').create();
    await File('${root.path}/bad/r000000000000.json').writeAsString('bad');
    final listing = await repo.list();
    expect(listing.projects.length, 1);
    expect(listing.failures, ['bad']);
    expect(() => repo.load('../escape'), throwsFormatException);
  });
  test('unsupported future schema fails without pretending to migrate', () {
    final payload = ProjectDocument(id: 'future')
        .encode()
        .replaceFirst('"schemaVersion":1', '"schemaVersion":99');
    expect(() => ProjectDocument.decode(payload), throwsFormatException);
  });
}
