import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../creative_document/document.dart';
import '../../composition/domain/score.dart';
import '../../composition/domain/audio_renderer.dart';
import '../domain/export_port.dart';

class AndroidVideoExportAdapter implements VideoExportPort {
  AndroidVideoExportAdapter(this.root);
  final Directory root;
  static const _channel = MethodChannel('scribblesong/video');
  static final _progress = <String, void Function(double)>{};
  static bool _registered = false;
  static void _register() {
    if (_registered) {
      return;
    }
    _registered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final arguments = call.arguments as Map;
        _progress[arguments['jobId']]?.call(
          (arguments['progress'] as num).toDouble().clamp(0, 1),
        );
      }
    });
  }

  @override
  Future<ExportArtifact> exportVideo(
    ProjectDocument document,
    ExportCancellation cancellation, {
    int width = 1080,
    void Function(double)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Video export currently requires Android');
    }
    cancellation.check();
    _register();
    final pcm = await compute(
      (ProjectDocument doc) => renderPcm(compileScore(doc)),
      document,
    );
    cancellation.check();
    await root.create(recursive: true);
    final id = newId();
    final stem = document.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final name = '${stem}_${document.id}_r${document.revision}_$id.mp4';
    final target = File('${root.path}/$name');
    final temporary = File('${target.path}.tmp');
    if (onProgress != null) {
      _progress[id] = onProgress;
    }
    final remove = cancellation.onCancel(
      () => unawaited(
        _channel.invokeMethod<void>('cancel', id).catchError((Object _) {}),
      ),
    );
    var complete = false;
    try {
      cancellation.check();
      final metadata = await _channel.invokeMapMethod<String, dynamic>(
        'export',
        {
          'jobId': id,
          'document': document.encode(),
          'pcm': pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
          'width': width,
          'path': temporary.path,
        },
      );
      cancellation.check();
      if (metadata == null ||
          !await temporary.exists() ||
          await temporary.length() == 0) {
        throw const FileSystemException('No encoded video was produced');
      }
      final encodedWidth = (metadata['width'] as num).toInt();
      final encodedHeight = (metadata['height'] as num).toInt();
      final encodedDuration = (metadata['durationSeconds'] as num).toDouble();
      if (encodedWidth != width ||
          encodedHeight != width * 5 ~/ 4 ||
          !encodedDuration.isFinite ||
          encodedDuration <= 0) {
        throw const FormatException('Invalid video metadata');
      }
      await temporary.rename(target.path);
      cancellation.check();
      complete = true;
      return ExportArtifact(
        target.path,
        'video/mp4',
        readableExportName(document.title, 'mp4'),
        document.id,
        document.revision,
        width: encodedWidth,
        height: encodedHeight,
        durationSeconds: encodedDuration,
      );
    } on PlatformException catch (error) {
      if (error.code == 'export_cancelled') {
        throw const ExportCancelled();
      }
      rethrow;
    } finally {
      remove();
      _progress.remove(id);
      if (!complete && await target.exists()) {
        await target.delete();
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
