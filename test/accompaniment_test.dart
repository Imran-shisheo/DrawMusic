import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/editor/domain/history.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/export/domain/midi.dart';
import 'package:scribblesong/features/home/domain/template_catalog.dart';

void main() {
  AccompanimentMix kit() => const AccompanimentMix().withLayer(
    AccompanimentLayer.drumKit,
    const LayerMix(enabled: true),
  );
  test('empty drawing kit produces deterministic distinct drums with no duplicates', () {
    final base = ProjectDocument(id: 'mix', mix: kit());
    final score = compileScore(base);
    expect(score.notes.length, 26);
    expect(score.notes.every((n) => n.percussion), isTrue);
    expect(
      score.notes.map((n) => '${n.pitch}:${n.startBin}').toSet().length,
      26,
    );
    final overlap = base.copyWith(
      mix: kit().withLayer(
        AccompanimentLayer.kick,
        const LayerMix(enabled: true),
      ),
    );
    expect(
      compileScore(overlap).notes.map((n) => n.fixture),
      score.notes.map((n) => n.fixture),
    );
    final muted = base.copyWith(
      mix: overlap.mix.withLayer(
        AccompanimentLayer.kick,
        const LayerMix(enabled: true, muted: true),
      ),
    );
    expect(compileScore(muted).notes.where((n) => n.pitch == 36), isEmpty);
    expect(renderPcm(score).any((n) => n != 0), isTrue);
    expect(renderPcm(score), renderPcm(compileScore(base)));
  });
  test('mix snapshots tempo transpose MIDI percussion and actual save/reopen retain exact layers', () async {
    final root = await Directory.systemTemp.createTemp('drawmusic-mix-');
    addTearDown(() => root.delete(recursive: true));
    final mix = kit()
        .withLayer(
          AccompanimentLayer.bass,
          const LayerMix(enabled: true, level: .25),
        )
        .withLayer(
          AccompanimentLayer.arpeggio,
          const LayerMix(enabled: true, level: .75),
        );
    final doc = ProjectDocument(
      id: 'snapshot',
      root: RootKey.g,
      scale: MusicalScale.dorian,
      mix: mix,
    );
    final history = DocumentHistory(doc);
    final before = compileScore(doc);
    history.commit(doc.copyWith(mix: const AccompanimentMix()));
    expect(compileScore(history.document).notes, isEmpty);
    history.undo();
    final repository = FileProjectRepository(root);
    await repository.save(history.document);
    final reopened = (await repository.open('snapshot')).document;
    expect(reopened.mix.toJson(), mix.toJson());
    expect(
      compileScore(reopened).notes.map((n) => n.fixture),
      before.notes.map((n) => n.fixture),
    );
    expect(
      compileScore(reopened.copyWith(tempo: 200)).notes.map((n) => n.fixture),
      before.notes.map((n) => n.fixture),
    );
    final bytes = encodeMidi(before);
    expect(bytes.contains(0x99), isTrue); // zero-based percussion channel9
    expect(bytes.contains(0x89), isTrue);
    expect(
      renderPcm(before).length,
      (before.loopSeconds * 44100).round() + (1.25 * 44100).round(),
    );
    expect(
      () => LayerMix.fromJson({
        'level': double.nan,
        'enabled': true,
        'muted': false,
      }),
      throwsFormatException,
    );
  });
  test('twenty original templates are independent and compile safely', () {
    expect(originalTemplates.length, greaterThanOrEqualTo(20));
    expect(
      originalTemplates.map((t) => t.id).toSet().length,
      originalTemplates.length,
    );
    final signatures = <String>{};
    for (final template in originalTemplates) {
      final first = template.create(), second = template.create();
      expect(first.id, isNot(second.id));
      expect(first.strokes, isNotEmpty);
      expect(template.description, isNotEmpty);
      signatures.add(
        first.strokes
            .map((s) => s.points.map((p) => '${p.u},${p.v}').join(';'))
            .join('|'),
      );
      expect(compileScore(first).notes, isNotEmpty);
      expect(ProjectDocument.decode(first.encode()).encode(), first.encode());
    }
    expect(signatures.length, originalTemplates.length);
  });
}
