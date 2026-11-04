import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final device = Platform.environment['DOODIMO_CAPTURE_DEVICE'];
  if (device != 'iphone' && device != 'ipad') {
    throw StateError('Set DOODIMO_CAPTURE_DEVICE to iphone or ipad');
  }
  final output = Directory('distribution/app-store/captures/$device');
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^0[1-6]-[a-z-]+$').hasMatch(name)) return false;
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final manifest = data?['appStoreManifest'];
      if (manifest != null) {
        await File(
          '${output.path}/capture-manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      }
    },
  );
}
