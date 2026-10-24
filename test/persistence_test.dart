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
  test(
    'serialized renames preserve latest document and reject invalid titles',
    () async {
      final document = ProjectDocument(id: 'rename');
      await repo.save(document);
      await Future.wait([
        repo.rename(document.id, ' First '),
        repo.rename(document.id, 'Second'),
      ]);
      final renamed = await repo.load(document.id);
      expect(renamed.title, 'Second');
      expect(renamed.revision, 2);
      await expectLater(repo.rename(document.id, '   '), throwsFormatException);
      expect((await repo.load(document.id)).title, 'Second');
    },
  );
  test('duplicate is independent; soft delete survives restart and undo restores exactly', () async {
    final document = ProjectDocument(
      id: 'original',
      title: 'Song',
      strokes: [
        Stroke(
          id: 'line',
          instrument: Instrument.bell,
          points: [InkPoint(.2, .4), InkPoint(.8, .4)],
        ),
      ],
    );
    await repo.save(document);
    final copy = await repo.duplicate(document.id);
    expect(copy.id, isNot(document.id));
    expect(copy.title, 'Song copy');
    await repo.save(copy.copyWith(strokes: []));
    expect((await repo.load(document.id)).strokes.length, 1);
    await repo.softDelete(document.id);
    final restarted = FileProjectRepository(root);
    expect((await restarted.list()).projects.map((p) => p.id), [copy.id]);
    await expectLater(
      restarted.load(document.id),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      restarted.save(document),
      throwsA(isA<FileSystemException>()),
    );
    await restarted.restore(document.id);
    expect((await restarted.load(document.id)).encode(), document.encode());
  });
  test(
    'recovery is visible and damaged bytes survive repair of their revision',
    () async {
      final doc = ProjectDocument(id: 'recovery-banner');
      await repo.save(doc);
      final damaged = File('${root.path}/${doc.id}/r000000000001.json');
      await damaged.writeAsString('broken revision');
      expect((await repo.open(doc.id)).recovered, isTrue);
      expect((await repo.list()).recoveredIds, [doc.id]);
      await repo.save(doc.copyWith(tempo: 130));
      expect((await repo.open(doc.id)).recovered, isFalse);
      final preserved = await Directory('${root.path}/${doc.id}')
          .list()
          .where((f) => f.path.contains('.preserved-'))
          .cast<File>()
          .toList();
      expect(preserved.length, 1);
      expect(await preserved.single.readAsString(), 'broken revision');
    },
  );
}
