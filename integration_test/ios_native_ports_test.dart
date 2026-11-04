import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/export/data/ios_video_export_adapter.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/transport/data/ios_audio_engine.dart';
import 'package:scribblesong/features/transport/domain/audio_engine.dart';
import 'package:scribblesong/main.dart' as app;

/// Source-only on Linux. Execute explicitly on an iOS simulator from a Mac;
/// native completion still requires independent file inspection/device QA.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS native clock, boundaries, pause and real H264/AAC files', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final document = ProjectDocument(
      id: 'ios-native-qa',
      title: 'Original iOS port fixture',
      strokes: [
        Stroke(
          id: 'keys',
          instrument: Instrument.keys,
          points: [InkPoint(.1, .7), InkPoint(.7, .7)],
        ),
        Stroke(
          id: 'bell',
          instrument: Instrument.bell,
          points: [InkPoint(.3, .3), InkPoint(.8, .4)],
        ),
      ],
    );
    final engine = IosAudioEngine();
    Future<TransportStatus> until(bool Function(TransportStatus) ready) async {
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (true) {
        final status = await engine.status();
        if (ready(status)) return status;
        if (DateTime.now().isAfter(end)) {
          fail('iOS native clock/boundary stalled');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    try {
      await engine.prepare(
        renderPcm(compileScore(document), loop: true),
        revision: 0,
      );
      await engine.play();
      await until((status) => status.playing && status.fraction > .03);
      final changed = document.copyWith(tempo: 140);
      await engine.queue(
        renderPcm(compileScore(changed), loop: true),
        revision: changed.revision,
        tempo: 140,
        boundary: UpdateBoundary.beat,
      );
      await until(
        (status) => status.revision == changed.revision && status.tempo == 140,
      );
      await engine.pause();
      final paused = await engine.status();
      expect(paused.playing, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect((await engine.status()).fraction, closeTo(paused.fraction, .001));
      await engine.play();
      await until(
        (status) =>
            status.playing && (status.fraction - paused.fraction).abs() > .01,
      );
    } finally {
      await engine.stop();
    }
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/exports');
    await root.create(recursive: true);
    await File(
      '${root.path}/ios-native-expected.wav',
    ).writeAsBytes(encodeWav(renderPcm(compileScore(document))), flush: true);
    await File('${root.path}/ios-native-project.json')
        .writeAsString(document.encode(), flush: true);
    final reports = <Map<String, Object>>[];
    for (final (width, fps) in const [
      (640, 30),
      (640, 60),
      (1080, 30),
      (1080, 60),
    ]) {
      final clock = Stopwatch()..start();
      final artifact = await IosVideoExportAdapter(root)
          .exportVideo(document, ExportCancellation(), width: width, fps: fps);
      clock.stop();
      final bytes = await File(artifact.path).readAsBytes();
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
      expect(artifact.width, width);
      expect(artifact.height, width * 5 ~/ 4);
      reports.add({
        'width': width,
        'fps': fps,
        'elapsedMs': clock.elapsedMilliseconds,
        'bytes': bytes.length,
        'path': artifact.path,
      });
    }
    final report = File('${root.path}/ios-native-port-report.json');
    await report.writeAsString(
      jsonEncode({
        'platform': Platform.operatingSystem,
        'videos': reports,
        'independentInspection': 'required',
        'physicalAudio': 'unverified',
      }),
    );
  }, skip: !Platform.isIOS);
}
