import 'dart:io';
import 'dart:typed_data';

import '../../../creative_document/document.dart';
import '../domain/export_port.dart';
import 'png_document_renderer.dart';

typedef PngRasterizer = Future<Uint8List> Function(
  ProjectDocument document,
  ExportCancellation cancellation, {
  required int width,
  required bool transparentBackground,
  void Function(double)? onProgress,
});

class FileImageExportAdapter implements ImageExportPort {
  FileImageExportAdapter(this.root, {PngRasterizer? rasterizer})
    : rasterizer = rasterizer ?? renderDocumentPng;
  final Directory root;
  final PngRasterizer rasterizer;

  @override
  Future<ExportArtifact> exportImage(
    ProjectDocument document,
    ExportCancellation cancellation, {
    int width = 1080,
    bool transparentBackground = false,
    void Function(double)? onProgress,
  }) async {
    cancellation.check();
    if (width != 640 && width != 1080) {
      throw const FormatException('Unsupported PNG dimensions');
    }
    onProgress?.call(0);
    final bytes = await rasterizer(
      document,
      cancellation,
      width: width,
      transparentBackground: transparentBackground,
      onProgress: onProgress,
    );
    cancellation.check();
    final height = width * 5 ~/ 4;
    _validatePng(bytes, width, height);
    await root.create(recursive: true);
    final stem = document.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final name = '${stem}_${document.id}_r${document.revision}_${newId()}.png';
    final target = File('${root.path}/$name');
    final temporary = File('${target.path}.tmp');
    var complete = false;
    try {
      cancellation.check();
      await temporary.writeAsBytes(bytes, flush: true);
      onProgress?.call(.95);
      cancellation.check();
      await temporary.rename(target.path);
      cancellation.check();
      onProgress?.call(1);
      cancellation.check();
      complete = true;
      return ExportArtifact(
        target.path,
        'image/png',
        readableExportName(document.title, 'png'),
        document.id,
        document.revision,
        width: width,
        height: height,
      );
    } finally {
      if (!complete && await target.exists()) await target.delete();
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

void _validatePng(Uint8List bytes, int width, int height) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 33 ||
      !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
    throw const FormatException('Invalid PNG output');
  }
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(8) != 13 ||
      String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR' ||
      header.getUint32(16) != width ||
      header.getUint32(20) != height) {
    throw const FormatException('Invalid PNG dimensions');
  }
}
