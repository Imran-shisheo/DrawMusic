import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../creative_document/document.dart';
import '../../composition/domain/score.dart';
import '../../composition/domain/audio_renderer.dart';
import '../domain/midi.dart';
import '../domain/export_port.dart';

class FileExportAdapter implements ExportPort {
  FileExportAdapter(this.root);
  final Directory root;
  @override
  Future<ExportArtifact> export(
    ProjectDocument document,
    ExportFormat format,
    ExportCancellation cancellation,
  ) async {
    cancellation.check();
    if (format == ExportFormat.mp4) {
      throw UnsupportedError('Use the video export adapter for MP4');
    }
    final bytes = await compute((data) {
      final (doc, type) = data;
      final score = compileScore(doc);
      return type == ExportFormat.midi
          ? encodeMidi(score)
          : encodeWav(renderPcm(score));
    }, (document, format));
    cancellation.check();
    await root.create(recursive: true);
    final stem = document.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final extension = format == ExportFormat.midi ? 'mid' : 'wav';
    final name =
        '${stem}_${document.id}_r${document.revision}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final temporary = File('${root.path}/$name.tmp');
    final target = File('${root.path}/$name');
    var complete = false;
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      cancellation.check();
      await temporary.rename(target.path);
      cancellation.check();
      complete = true;
      return ExportArtifact(
        target.path,
        format == ExportFormat.midi ? 'audio/midi' : 'audio/wav',
        '$stem.$extension',
        document.id,
        document.revision,
      );
    } finally {
      if (!complete && await target.exists()) {
        await target.delete();
      }
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
