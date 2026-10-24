import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/composition/domain/audio_renderer.dart';
import 'package:scribblesong/features/export/domain/midi.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export/data/file_export_adapter.dart';

ProjectDocument sample({
  Instrument instrument = Instrument.keys,
  int tempo = 120,
}) => ProjectDocument(
  id: 'export',
  tempo: tempo,
  strokes: [
    Stroke(
      id: 'line',
      instrument: instrument,
      points: [InkPoint(.25, .5), InkPoint(.75, .5)],
    ),
  ],
);
void main() {
  test('WAV is decoded PCM16 mono with exact loop plus tail, real nonclipping audio', () {
    final score = compileScore(sample());
    final pcm = renderPcm(score);
    final wav = encodeWav(pcm);
    final data = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(4, Endian.little), wav.length - 8);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 44100);
    expect(data.getUint16(34, Endian.little), 16);
    expect(pcm.length, (5.25 * 44100).round());
    expect(data.getUint32(40, Endian.little), pcm.length * 2);
    expect(pcm.take(44100).every((n) => n == 0), isTrue);
    final energy = pcm.fold<double>(0, (sum, n) => sum + n * n) / pcm.length;
    expect(math.sqrt(energy), greaterThan(100));
    expect(pcm.every((n) => n.abs() < 32767), isTrue);
    expect(pcm.skip(4 * 44100 + 10000).every((n) => n == 0), isTrue);
    for (var i = 0; i < pcm.length; i++) {
      expect(data.getInt16(44 + 2 * i, Endian.little), pcm[i]);
    }
  });
  test(
    'voices are distinct, output deterministic, tempo changes duration only',
    () {
      final voices = [
        for (final instrument in Instrument.values)
          renderPcm(compileScore(sample(instrument: instrument))),
      ];
      expect(voices[0], isNot(orderedEquals(voices[1])));
      expect(voices[1], isNot(orderedEquals(voices[2])));
      expect(voices[0], orderedEquals(renderPcm(compileScore(sample()))));
      final slow = compileScore(sample(tempo: 60));
      expect(renderPcm(slow).length, (9.25 * 44100).round());
      expect(
        slow.notes.single.pitch,
        compileScore(sample()).notes.single.pitch,
      );
      expect(renderPcm(compileScore(sample()), loop: true).length, 176400);
    },
  );
  test(
    'MIDI header, tempo, programs and events retain 480 PPQ / eight beats',
    () {
      final midi = encodeMidi(compileScore(sample()));
      final header = ByteData.sublistView(midi);
      expect(String.fromCharCodes(midi.sublist(0, 4)), 'MThd');
      expect(header.getUint16(8), 0);
      expect(header.getUint16(10), 1);
      expect(header.getUint16(12), 480);
      expect(header.getUint32(18), midi.length - 22);
      expect(midi.sublist(22, 29), [
        0,
        255,
        81,
        3,
        7,
        161,
        32,
      ]); // 500,000 us / quarter
      expect(midi.sublist(midi.length - 3), [255, 47, 0]);
    },
  );
  test(
    'completed files publish atomically; cancellation publishes no artifact',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'drawmusic-export-test',
      );
      try {
        final adapter = FileExportAdapter(root);
        final canceled = ExportCancellation()..cancelled = true;
        await expectLater(
          adapter.export(sample(), ExportFormat.wav, canceled),
          throwsA(isA<ExportCancelled>()),
        );
        expect(await root.list().toList(), isEmpty);
        final artifact = await adapter.export(
          sample(),
          ExportFormat.midi,
          ExportCancellation(),
        );
        expect(
          await File(artifact.path).readAsBytes(),
          encodeMidi(compileScore(sample())),
        );
        expect(artifact.revision, 0);
        expect((await root.list().toList()).length, 1);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'cancellation notifies active native listeners once and cannot be reset',
    () {
      final cancellation = ExportCancellation();
      var calls = 0;
      var removedCalls = 0;
      cancellation.onCancel(() => calls++);
      final remove = cancellation.onCancel(() => removedCalls++);
      remove();
      cancellation.cancelled = true;
      cancellation.cancelled = true;
      cancellation.cancelled = false;
      expect(calls, 1);
      expect(removedCalls, 0);
      expect(cancellation.cancelled, isTrue);
      expect(cancellation.check, throwsA(isA<ExportCancelled>()));
    },
  );
  test('MP4 cannot accidentally fall through to a WAV file', () async {
    final root = await Directory.systemTemp.createTemp('video-port-test');
    try {
      await expectLater(
        FileExportAdapter(root)
            .export(sample(), ExportFormat.mp4, ExportCancellation()),
        throwsUnsupportedError,
      );
      expect(await root.list().toList(), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test(
    'canceling an in-flight PCM render never publishes a completed file',
    () async {
      final root = await Directory.systemTemp.createTemp('cancel-render-test');
      try {
        final cancellation = ExportCancellation();
        final future = FileExportAdapter(root)
            .export(sample(), ExportFormat.wav, cancellation);
        cancellation.cancelled = true;
        await expectLater(future, throwsA(isA<ExportCancelled>()));
        expect(await root.list().toList(), isEmpty);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
