import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
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

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

// A diagnostic entry point, never the shipping lib/main.dart target. Android
// launches it directly; validation does not require a debugger/test connection.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  unawaited(probe());
}

Future<void> probe() async {
  const token = String.fromEnvironment('FORCE_STOP_TOKEN');
  const phase = String.fromEnvironment('FORCE_STOP_PHASE');
  File? report;
  final audio = AndroidAudioEngine();
  try {
    require(Platform.isAndroid, 'The probe is Android-only');
    require(
      RegExp(r'^[a-f0-9]{32}$').hasMatch(token),
      'Invalid diagnostic token',
    );
    require(['prepare', 'resume'].contains(phase), 'Invalid diagnostic phase');
    final docs = await getApplicationDocumentsDirectory();
    final cache = await getTemporaryDirectory();
    final root = Directory('${docs.path}/qa-force-stop-$token');
    report = File('${cache.path}/qa-force-stop-$token.json');
    final repository = FileProjectRepository(root);
    final baselineFile = File(
      '${root.path}/restart-drawing/r000000000000.json',
    );
    Future<void> play(ProjectDocument document) async {
      await audio
          .prepare(
            renderPcm(compileScore(document), loop: true),
            revision: document.revision,
            tempo: document.tempo,
          )
          .timeout(const Duration(seconds: 10));
      await audio.play().timeout(const Duration(seconds: 10));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (true) {
        final status = await audio.status().timeout(const Duration(seconds: 5));
        if (status.playing && status.fraction > 0) break;
        require(
          DateTime.now().isBefore(deadline),
          'Android output clock did not advance',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    if (phase == 'prepare') {
      require(!await root.exists(), 'Expected a fresh isolated directory');
      await report.writeAsString(
        jsonEncode({'token': token, 'phase': 'starting', 'pid': pid}),
        flush: true,
      );
      await repository.save(fixture()).timeout(const Duration(seconds: 30));
      final bytes = await baselineFile.readAsBytes();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await play(fixture());
      await report.writeAsString(
        jsonEncode({
          'token': token,
          'phase': 'ready',
          'pid': pid,
          'baselineSha256': sha256.convert(bytes).toString(),
          'playing': (await audio.status().timeout(const Duration(seconds: 5)))
              .playing,
        }),
        flush: true,
      );
      for (var revision = 1; revision <= 2; revision++) {
        await repository.save(fixture(revision: revision));
      }
      // Android's host-driven force-stop ends this live process.
      await Completer<void>().future;
    } else {
      final before =
          jsonDecode(await report.readAsString()) as Map<String, dynamic>;
      require(
        before['token'] == token && before['phase'] == 'ready',
        'Missing ready report',
      );
      require(
        before['pid'] != pid && before['playing'] == true,
        'Expected a fresh process after active playback',
      );
      require(
        sha256.convert(await baselineFile.readAsBytes()).toString() ==
            before['baselineSha256'],
        'Published baseline bytes changed',
      );
      final recovered = await repository
          .open('restart-drawing')
          .timeout(const Duration(seconds: 30));
      require(
        recovered.document.revision >= 0 && recovered.document.revision <= 2,
        'Unexpected recovered revision',
      );
      require(
        recovered.document.encode() ==
            fixture(revision: recovered.document.revision).encode(),
        'Recovered document is not the exact complete fixture',
      );
      require(
        !(await audio.status().timeout(const Duration(seconds: 5))).playing,
        'Playback automatically resumed',
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await play(recovered.document);
      await audio.stop().timeout(const Duration(seconds: 10));
      final retry = fixture(revision: 3);
      await repository.save(retry).timeout(const Duration(seconds: 30));
      final reopened = await FileProjectRepository(root)
          .open(retry.id)
          .timeout(const Duration(seconds: 30));
      require(
        reopened.document.encode() == retry.encode(),
        'Retry did not reopen exactly',
      );
      await root.delete(recursive: true);
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
          'probeMode': 'standalone-debug-APK',
          'scope': 'Disposable API 35 emulator force-stop/relaunch; not power loss, disk full, physical audio or guaranteed temporary-write interruption.',
        }),
        flush: true,
      );
    }
  } catch (error, stack) {
    if (report != null) {
      await report.writeAsString(
        jsonEncode({
          'token': token,
          'phase': 'failed',
          'pid': pid,
          'error': error.toString(),
        }),
        flush: true,
      );
    }
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    try {
      await audio.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
