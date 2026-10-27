import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../export/domain/export_port.dart';
import '../domain/export_library.dart';
import 'file_export_library.dart';
import 'ios_export_file_actions.dart';
import '../../settings/application/settings_controller.dart';
import '../../../l10n/strings.dart';

final exportLibraryProvider = FutureProvider<ExportLibrary>((ref) async {
  final directory = await getApplicationDocumentsDirectory();
  return FileExportLibrary(Directory('${directory.path}/exports'));
});
final exportListingProvider = FutureProvider<ExportListing>(
  (ref) async => (await ref.watch(exportLibraryProvider.future)).list(),
);
final exportFileActionsProvider = Provider<ExportFileActions>(
  (ref) => Platform.isIOS
      ? IosExportFileActions()
      : AndroidExportFileActions(
          chooserTitle: lookupAppLocalizations(
            Locale(
              ref.watch(
                settingsProvider.select((s) => s.preferences.languageCode),
              ),
            ),
          ).openWithAnotherApp,
        ),
);

typedef ShareExport = Future<ShareResultStatus> Function(
  ExportArtifact artifact,
  Rect? origin,
);
final shareExportProvider = Provider<ShareExport>(
  (ref) =>
      (artifact, origin) async => (await SharePlus.instance.share(
        ShareParams(
          files: [XFile(artifact.path, mimeType: artifact.mime)],
          fileNameOverrides: [artifact.name],
          sharePositionOrigin: origin,
        ),
      )).status,
);

class AndroidExportFileActions implements ExportFileActions {
  AndroidExportFileActions({this.chooserTitle});
  final String? chooserTitle;
  static const channel = MethodChannel('scribblesong/export-files');
  @override
  Future<void> open(ExportArtifact artifact) =>
      channel.invokeMethod<void>('open', {
        'path': artifact.path,
        'name': artifact.name,
        'mime': artifact.mime,
        if (chooserTitle != null) 'chooserTitle': chooserTitle,
      });
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
    if (bytes <= 0 || !uri.startsWith('content://')) {
      throw const FormatException('Public copy was not verified');
    }
    return PublicExportCopy(uri, result['destination'] as String, bytes);
  }
}
