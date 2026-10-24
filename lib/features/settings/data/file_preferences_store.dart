import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/preferences.dart';

class FilePreferencesStore implements PreferencesStore {
  FilePreferencesStore(this.directory);
  final Directory directory;
  Future<void> _queue = Future.value();
  File get file => File('${directory.path}/preferences.json');
  File get backup => File('${directory.path}/preferences.backup.json');
  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _queue.then((_) => action());
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<UserPreferences> _read(File source) async {
    if (await source.length() > 16384) {
      throw const FormatException('Settings exceed size limit');
    }
    final envelope = jsonDecode(await source.readAsString()) as Map;
    final payload = envelope['payload'] as String;
    if (envelope['sha256'] != sha256.convert(utf8.encode(payload)).toString()) {
      throw const FormatException('Settings checksum mismatch');
    }
    return UserPreferences.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  }

  @override
  Future<PreferencesLoad> load() => _serialize(() async {
    if (!await file.exists() && !await backup.exists()) {
      return const PreferencesLoad(UserPreferences());
    }
    try {
      return PreferencesLoad(await _read(file));
    } catch (_) {
      return PreferencesLoad(await _read(backup), recovered: true);
    }
  });

  @override
  Future<void> save(UserPreferences preferences) => _serialize(() async {
    // Validate values before touching the last complete settings file.
    final payload = jsonEncode(
      UserPreferences.fromJson(preferences.toJson()).toJson(),
    );
    await directory.create(recursive: true);
    if (await file.exists()) {
      var valid = false;
      try {
        await _read(file);
        valid = true;
      } catch (_) {
        await file.copy(
          '${file.path}.preserved-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      if (valid) {
        final copy = await file.copy('${backup.path}.tmp');
        await copy.rename(backup.path);
      }
    }
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'payload': payload,
        'sha256': sha256.convert(utf8.encode(payload)).toString(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  });
}
