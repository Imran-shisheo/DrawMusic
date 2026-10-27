import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/ios_export_file_actions.dart';
import 'package:scribblesong/features/transport/data/ios_audio_engine.dart';
import 'package:scribblesong/features/transport/domain/audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const audio = MethodChannel('scribblesong/audio');
  const files = MethodChannel('scribblesong/export-files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(audio, null);
    messenger.setMockMethodCallHandler(files, null);
  });

  test(
    'iOS audio IPC preserves sliced PCM and native clock/revision status',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(audio, (call) async {
        calls.add(call);
        if (call.method == 'status') {
          return <String, Object>{
            'playing': true,
            'revision': 11,
            'targetRevision': 12,
            'fraction': .375,
            'tempo': 137,
          };
        }
        return null;
      });
      final engine = IosAudioEngine();
      final data = Int16List.fromList([999, -32768, 0, 32767, 888]);
      final slice = Int16List.sublistView(data, 1, 4);
      await engine.prepare(slice, revision: 11, tempo: 137);
      await engine.queue(
        slice,
        revision: 12,
        tempo: 140,
        boundary: UpdateBoundary.beat,
      );
      final first = calls.first.arguments as Map;
      expect(first['pcm'], orderedEquals([0, 128, 0, 0, 255, 127]));
      expect(first['revision'], 11);
      expect(first['tempo'], 137);
      expect((calls[1].arguments as Map)['boundary'], 'beat');
      final status = await engine.status();
      expect(status.fraction, .375);
      expect(status.revision, 11);
      expect(status.targetRevision, 12);
      expect(status.tempo, 137);
      expect(status.playing, isTrue);
    },
  );

  test(
    'iOS native audio failures remain failures rather than silent success',
    () async {
      messenger.setMockMethodCallHandler(audio, (_) async {
        throw PlatformException(
          code: 'audio_unavailable',
          message: 'Session rejected',
        );
      });
      await expectLater(
        IosAudioEngine().play(),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'iOS document Save validates a verified file URL and honest cancellation',
    () async {
      const artifact = ExportArtifact(
        '/private/app/Documents/exports/drawing.png',
        'image/png',
        'Drawing.png',
        'project',
        4,
      );
      var response = <String, Object>{
        'uri': 'file:///private/provider/Drawing.png',
        'bytes': 43,
        'destination': 'Selected folder',
      };
      messenger.setMockMethodCallHandler(files, (call) async {
        expect(call.method, 'save');
        expect((call.arguments as Map)['mime'], 'image/png');
        return response;
      });
      final adapter = IosExportFileActions();
      final saved = await adapter.save(artifact);
      expect(saved?.bytes, 43);
      response = {'cancelled': true};
      expect(await adapter.save(artifact), isNull);
      response = {
        'uri': 'file:///private/provider/Drawing.png',
        'bytes': 0,
        'destination': 'Folder',
      };
      await expectLater(adapter.save(artifact), throwsFormatException);
      response = {
        'uri': 'https://example.invalid/upload',
        'bytes': 43,
        'destination': 'Web',
      };
      await expectLater(adapter.save(artifact), throwsFormatException);
    },
  );
}
