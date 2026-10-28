import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:scribblesong/features/settings/data/file_preferences_store.dart';

/// Explicit functional-runtime fixture only. This uses the real checksummed
/// preference repository and preserves every other saved setting. It does not
/// disable production motion or the separate motion/profile recording fixture.
Future<void> prepareFunctionalMotion() async {
  final support = await getApplicationSupportDirectory();
  final store = FilePreferencesStore(Directory('${support.path}/settings'));
  final loaded = await store.load();
  await store.save(loaded.preferences.copyWith(reduceMotion: true));
}
