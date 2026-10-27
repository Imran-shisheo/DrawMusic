import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';

ProjectDocument originalExpanded(ProjectDocument source) => source.copyWith(
  id: 'expanded-compatibility',
  root: RootKey.fSharp,
  scale: MusicalScale.dorian,
);
void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(File('test/fixtures/project_v1_music.json').readAsStringSync())
          as Map<String, dynamic>;
  test('unknown IDs use explicit safe fallbacks and preserve raw IDs/metadata through edit and reopen', () {
    final j = fixture();
    j['scale'] = 'future-scale';
    j['root'] = 'future-root';
    j['authorData'] = {
      'nested': ['keep', 3],
    };
    final stroke = (j['strokes'] as List).single as Map<String, dynamic>;
    stroke['instrument'] = 'future-instrument';
    stroke['license'] = {'original': 'retained'};
    final doc = ProjectDocument.decode(jsonEncode(j));
    expect(doc.hasCompatibilityFallbacks, isTrue);
    expect(doc.unknownInstrumentIds, ['future-instrument']);
    expect(doc.hasScaleFallback, isTrue);
    expect(doc.hasRootFallback, isTrue);
    expect(doc.scale, MusicalScale.major);
    expect(doc.root, RootKey.c);
    expect(doc.strokes.single.instrument, Instrument.keys);
    expect(compileScore(doc).notes.single.pitch, 67);
    final saved = ProjectDocument.decode(
      doc.copyWith(title: 'Recovered safely').encode(),
    ).toJson();
    expect(saved['scale'], 'future-scale');
    expect(saved['root'], 'future-root');
    expect(saved['authorData'], j['authorData']);
    expect(
      (saved['strokes'] as List).single['instrument'],
      'future-instrument',
    );
    expect((saved['strokes'] as List).single['license'], stroke['license']);
    final clipped = eraseAt(doc.strokes, InkPoint(.5, .5), .03);
    expect(clipped.every((s) => s.instrumentId == 'future-instrument'), isTrue);
    expect(doc.copyWith(scale: MusicalScale.minor).scaleId, 'minor');
    expect(doc.copyWith(root: RootKey.d).rootId, 'd');
    expect(
      doc.strokes.single.copyWith(instrument: Instrument.bell).instrumentId,
      'bell',
    );
  });
  test(
    'future schema/engine remain rejected without altering original bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('music-compatibility');
      try {
        for (final field in ['schemaVersion', 'engineVersion']) {
          final j = fixture();
          j[field] = 99;
          final file = File('${root.path}/$field.json');
          final bytes = jsonEncode(j);
          await file.writeAsString(bytes);
          expect(() => ProjectDocument.decode(bytes), throwsFormatException);
          expect(await file.readAsString(), bytes);
        }
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'extension metadata is deeply immutable, and v1 old minor stays pentatonic',
    () {
      final j = fixture();
      j['scale'] = 'minor';
      j['extra'] = {
        'list': [1, 2],
      };
      final doc = ProjectDocument.decode(jsonEncode(j));
      expect(doc.scale.intervals, [0, 3, 5, 7, 10]);
      expect(
        () => (doc.extraFields['extra']['list'] as List).add(3),
        throwsUnsupportedError,
      );
      expect(doc.formatVersion, 1);
      expect(doc.soundVersion, 1);
    },
  );
  test('real repository rename/duplicate/reopen preserves compatibility metadata and expanded root', () async {
    final root = await Directory.systemTemp.createTemp('unknown-project-file');
    try {
      final j = fixture();
      j['scale'] = 'unavailable-family';
      j['root'] = 'unavailable-root';
      j['originalMetadata'] = {
        'keep': [1, 2],
      };
      (j['strokes'] as List).single['instrument'] = 'unavailable-voice';
      final doc = ProjectDocument.decode(jsonEncode(j));
      final repository = FileProjectRepository(root);
      await repository.save(doc);
      await repository.rename(doc.id, 'Retained unknown project');
      final copy = await repository.duplicate(doc.id);
      expect(copy.id, isNot(doc.id));
      expect(copy.revision, 0);
      expect(copy.createdAt, isNot(doc.createdAt));
      expect(copy.scaleId, 'unavailable-family');
      expect(copy.rootId, 'unavailable-root');
      expect(copy.strokes.single.instrumentId, 'unavailable-voice');
      expect(copy.extraFields, doc.extraFields);
      final reopened = await FileProjectRepository(root).load(copy.id);
      expect(reopened.encode(), copy.encode());
      final expanded = originalExpanded(doc);
      await repository.save(expanded);
      final expandedCopy = await repository.duplicate(expanded.id);
      expect(expandedCopy.root, RootKey.fSharp);
      expect(expandedCopy.scale, MusicalScale.dorian);
      expect(expandedCopy.formatVersion, 2);
      expect(expandedCopy.soundVersion, 2);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
