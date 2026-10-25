import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/transport/data/android_audio_engine.dart';

ProjectDocument fixture({int revision = 0}) => ProjectDocument(
  id: 'restart-drawing',
  title: 'Cloud recovery — موسيقى',
  tempo: 137,
  scale: MusicalScale.minor,
  background: 0x80f3eef9,
  style: DrawingStyle.pixel,
  revision: revision,
  createdAt: DateTime.utc(2026, 10, 25),
  updatedAt: DateTime.utc(2026, 10, 25, 0, 0, revision),
  strokes: [
    Stroke(
      id: 'restart-ink',
      instrument: Instrument.bell,
      points: revision == 0
          ? [InkPoint(.1, .4), InkPoint(.9, .5)]
          : [for (var i = 0; i < 100000; i++) InkPoint(i / 99999, .4)],
    ),
  ],
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const token = String.fromEnvironment('FORCE_STOP_TOKEN');
  const phase = String.fromEnvironment('FORCE_STOP_PHASE');
  testWidgets('Android process force-stop recovery: $phase', (tester) async {
    expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(token), isTrue);
    expect(['prepare', 'resume'], contains(phase));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final docs = await getApplicationDocumentsDirectory();
    final cache = await getTemporaryDirectory();
    final root = Directory('${docs.path}/qa-force-stop-$token');
    final report = File('${cache.path}/qa-force-stop-$token.json');
    final repository = FileProjectRepository(root);
    final baselineFile = File(
      '${root.path}/restart-drawing/r000000000000.json',
    );
    final audio = AndroidAudioEngine();
    Future<void> play(ProjectDocument document) async {
      await audio.prepare(
        renderPcm(compileScore(document), loop: true),
        revision: document.revision,
        tempo: document.tempo,
      );
      await audio.play();
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!(await audio.status()).playing ||
          (await audio.status()).fraction <= 0) {
        expect(
          DateTime.now().isBefore(deadline),
          isTrue,
          reason: 'Real Android output must restart and advance its clock',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    if (phase == 'prepare') {
      expect(
        await root.exists(),
        isFalse,
        reason: 'The diagnostic must own a fresh isolated directory',
      );
      await repository.save(fixture());
      final baselineBytes = await baselineFile.readAsBytes();
      await play(fixture());
      await report.writeAsString(
        jsonEncode({
          'token': token,
          'phase': 'ready',
          'pid': pid,
          'baselineSha256': sha256.convert(baselineBytes).toString(),
          'playing': (await audio.status()).playing,
        }),
        flush: true,
      );
      // The host force-stops this package. Its first Flutter runner is expected
      // to lose the connection, not report this preparation as a passing test.
      for (var revision = 1; revision <= 2; revision++) {
        await repository.save(fixture(revision: revision));
      }
      await Completer<void>().future;
    } else {
      final before =
          jsonDecode(await report.readAsString()) as Map<String, dynamic>;
      expect(before['token'], token);
      expect(before['pid'], isNot(pid));
      expect(before['playing'], isTrue);
      expect(
        sha256.convert(await baselineFile.readAsBytes()).toString(),
        before['baselineSha256'],
      );
      final recovered = await repository.open('restart-drawing');
      expect(recovered.document.revision, inInclusiveRange(0, 2));
      expect(
        recovered.document.encode(),
        fixture(revision: recovered.document.revision).encode(),
      );
      expect(
        (await audio.status()).playing,
        isFalse,
        reason: 'Process relaunch must never auto-resume the old session',
      );
      await play(recovered.document);
      await audio.stop();
      final retry = fixture(revision: 3);
      await repository.save(retry);
      expect(
        (await FileProjectRepository(root).open(retry.id)).document.encode(),
        retry.encode(),
      );
      await report.writeAsString(
        jsonEncode({
          ...before,
          'phase': 'verified',
          'resumedPid': pid,
          'recoveredRevision': recovered.document.revision,
          'baselineBytesUnchanged': true,
          'completeDocumentMatched': true,
          'automaticPlayback': false,
          'explicitPlaybackRestarted': true,
          'retryRevision': 3,
          'retryReopenedExactly': true,
          'scope': 'Disposable API 35 emulator force-stop/relaunch; not power loss, disk full, physical audio or guaranteed temporary-write interruption.',
        }),
        flush: true,
      );
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
