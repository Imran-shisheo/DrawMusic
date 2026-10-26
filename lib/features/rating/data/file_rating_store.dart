import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/rating_state.dart';

class FileRatingStore implements RatingStore {
  FileRatingStore(this.directory);
  final Directory directory;
  File get file => File('${directory.path}/rating-state.json');
  Future<void> _queue = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<RatingState> _read() async {
    if (!await file.exists()) return const RatingState();
    if (await file.length() > 4096) {
      throw const FormatException('Rating state too large');
    }
    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final payload = envelope['payload'] as String;
    if (envelope['sha256'] != sha256.convert(utf8.encode(payload)).toString()) {
      throw const FormatException('Rating state checksum mismatch');
    }
    return RatingState.fromJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  @override
  Future<RatingState> load() => _serialize(_read);

  @override
  Future<void> save(RatingState state) => _serialize(() async {
    // Never overwrite malformed/unknown eligibility with an eager new prompt.
    await _read();
    final payload = jsonEncode(RatingState.fromJson(state.toJson()).toJson());
    await directory.create(recursive: true);
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(
        jsonEncode({
          'payload': payload,
          'sha256': sha256.convert(utf8.encode(payload)).toString(),
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  });
}
