import 'package:flutter/services.dart';

import '../../export/domain/export_port.dart';
import '../domain/export_library.dart';

/// iOS system document menus. A successful picker is not a delivery promise.
class IosExportFileActions implements ExportFileActions {
  static const channel = MethodChannel('scribblesong/export-files');
  @override
  Future<void> open(ExportArtifact artifact) => channel.invokeMethod<void>(
    'open',
    {'path': artifact.path, 'name': artifact.name, 'mime': artifact.mime},
  );
  @override
  Future<PublicExportCopy?> save(ExportArtifact artifact) async {
    final result = await channel.invokeMapMethod<String, dynamic>('save', {
      'path': artifact.path,
      'name': artifact.name,
      'mime': artifact.mime,
    });
    if (result == null || result['cancelled'] == true) return null;
    final uri = result['uri'] as String;
    final bytes = (result['bytes'] as num).toInt();
    final parsed = Uri.tryParse(uri);
    if (bytes <= 0 ||
        parsed == null ||
        parsed.scheme != 'file' ||
        parsed.path.isEmpty) {
      throw const FormatException('Public copy was not verified');
    }
    return PublicExportCopy(uri, result['destination'] as String, bytes);
  }
}
