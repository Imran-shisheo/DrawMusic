import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../../creative_document/document.dart';
import '../../export/domain/export_port.dart';
import '../domain/export_library.dart';

class FileExportLibrary implements ExportLibrary {
  FileExportLibrary(this.root, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final Directory root;
  final DateTime Function() clock;
  static const undoWindow = Duration(seconds: 7);
  Future<void> _queue = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _queue.then((_) => action());
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  void _validateId(String id) {
    if (id.isEmpty ||
        id.startsWith('.') ||
        id.length > 255 ||
        id.contains(RegExp(r'[/\\\x00-\x1f]')) ||
        !const ['mid', 'wav', 'mp4'].contains(id.split('.').last)) {
      throw const FormatException('Invalid export identifier');
    }
  }

  String _mime(String id) => switch (id.split('.').last) {
    'mid' => 'audio/midi',
    'wav' => 'audio/wav',
    _ => 'video/mp4',
  };
  File _file(String id) {
    _validateId(id);
    return File('${root.path}/$id');
  }

  File _metadata(String id) => File('${_file(id).path}.json');
  Future<bool> _available(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    if (!((await file.resolveSymbolicLinks()).startsWith(
      '${await root.resolveSymbolicLinks()}${Platform.pathSeparator}',
    ))) {
      return false;
    }
    final handle = await file.open();
    try {
      final bytes = await handle.read(12);
      if (bytes.length < 12) return false;
      final extension = file.path.split('.').last;
      return switch (extension) {
        'mid' =>
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'MThd',
        'wav' =>
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
              ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE',
        'mp4' =>
          ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp',
        _ => false,
      };
    } finally {
      await handle.close();
    }
  }

  Future<LibraryExport> _read(String id) async {
    final metadata = _metadata(id);
    if (await FileSystemEntity.type(metadata.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FileSystemException('Export details unavailable');
    }
    if (await metadata.length() > 256000) {
      throw const FormatException('Export details exceed budget');
    }
    final envelope = jsonDecode(await metadata.readAsString()) as Map;
    final payload = envelope['payload'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('Export details damaged');
    }
    final json = jsonDecode(payload) as Map;
    if (json['schema'] != 1 ||
        json['file'] != id ||
        json['mime'] != _mime(id)) {
      throw const FormatException('Unsupported export details');
    }
    final source = _file(id);
    final available = await _available(source);
    return LibraryExport(
      id: id,
      artifact: ExportArtifact(
        source.path,
        _mime(id),
        json['name'] as String,
        json['projectId'] as String,
        json['revision'] as int,
        width: json['width'] as int?,
        height: json['height'] as int?,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      bytes: available ? await source.length() : 0,
      available: available,
      preview: json['preview'] == null
          ? null
          : ProjectDocument.decode(json['preview'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      legacy: json['legacy'] == true,
    );
  }

  Future<LibraryExport> _legacy(String id) async {
    final file = _file(id);
    final stat = await file.stat();
    final available = await _available(file);
    return LibraryExport(
      id: id,
      artifact: ExportArtifact(file.path, _mime(id), id, '', 0),
      createdAt: stat.modified.toUtc(),
      bytes: available ? stat.size : 0,
      available: available,
      legacy: true,
    );
  }

  Future<LibraryExport> _entry(String id) async {
    try {
      return await _read(id);
    } catch (_) {
      return _legacy(id);
    }
  }

  Future<void> _write(LibraryExport entry) async {
    final metadata = _metadata(entry.id);
    if (await FileSystemEntity.type(metadata.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FileSystemException('Export details unavailable');
    }
    if (await metadata.exists()) {
      try {
        await _read(entry.id);
      } catch (_) {
        await metadata.copy(
          '${metadata.path}.preserved-${clock().microsecondsSinceEpoch}',
        );
      }
    }
    final artifact = entry.artifact;
    final payload = jsonEncode({
      'schema': 1,
      'file': entry.id,
      'name': artifact.name,
      'mime': artifact.mime,
      'projectId': artifact.projectId,
      'revision': artifact.revision,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'width': artifact.width,
      'height': artifact.height,
      'durationSeconds': artifact.durationSeconds,
      'preview': entry.preview?.encode(),
      'deletedAt': entry.deletedAt?.toUtc().toIso8601String(),
      'legacy': entry.legacy,
    });
    final temporary = File('${metadata.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'payload': payload,
        'sha256': sha256.convert(utf8.encode(payload)).toString(),
      }),
      flush: true,
    );
    await temporary.rename(metadata.path);
  }

  @override
  Future<ExportListing> list() => _serialize(() async {
    if (!await root.exists()) return const ExportListing([]);
    final ids = <String>{};
    await for (final item in root.list(followLinks: false)) {
      if (item is! File) continue;
      var id = item.uri.pathSegments.last;
      if (id.endsWith('.json')) id = id.substring(0, id.length - 5);
      try {
        _validateId(id);
        ids.add(id);
      } catch (_) {
        /* Ignore unrelated files and unfinished outputs. */
      }
    }
    final entries = <LibraryExport>[];
    var failures = 0;
    for (final id in ids) {
      LibraryExport entry;
      try {
        entry = await _read(id);
      } catch (_) {
        if (await _metadata(id).exists()) failures++;
        try {
          entry = await _legacy(id);
        } catch (_) {
          failures++;
          continue;
        }
      }
      if (entry.deletedAt != null) {
        if (clock().toUtc().difference(entry.deletedAt!) >= undoWindow) {
          if (await _file(id).exists()) await _file(id).delete();
          if (await _metadata(id).exists()) await _metadata(id).delete();
        }
        continue;
      }
      entries.add(entry);
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ExportListing(entries, detailFailures: failures);
  });
  @override
  Future<void> record(ExportArtifact artifact, ProjectDocument document) =>
      _serialize(() async {
        final id = File(artifact.path).uri.pathSegments.last;
        final file = _file(id);
        if (file.absolute.path != File(artifact.path).absolute.path ||
            artifact.mime != _mime(id) ||
            !await _available(file)) {
          throw const FileSystemException('Export is unavailable');
        }
        // Preview-only simplification never modifies the editable project or its score.
        final strokes = document.strokes.take(24).map((stroke) {
          final stride = math.max(1, (stroke.points.length / 64).ceil());
          final points = [
            for (var i = 0; i < stroke.points.length; i += stride)
              stroke.points[i],
          ];
          if (!identical(points.last, stroke.points.last)) {
            points.add(stroke.points.last);
          }
          return Stroke(
            id: stroke.id,
            instrument: stroke.instrument,
            width: stroke.width,
            points: points,
          );
        });
        await _write(
          LibraryExport(
            id: id,
            artifact: artifact,
            createdAt: clock().toUtc(),
            bytes: await file.length(),
            available: true,
            preview: document.copyWith(strokes: strokes.toList()),
          ),
        );
      });
  @override
  Future<void> rename(String id, String title) => _serialize(() async {
    final name = title.trim();
    if (name.isEmpty ||
        name.length > 60 ||
        name.contains(RegExp(r'[/\\\x00-\x1f]'))) {
      throw const FormatException(
        'Use a name of 1–60 characters without slashes',
      );
    }
    final entry = await _entry(id);
    if (entry.deletedAt != null) {
      throw const FileSystemException('Export was removed');
    }
    final old = entry.artifact;
    await _write(
      LibraryExport(
        id: id,
        artifact: ExportArtifact(
          old.path,
          old.mime,
          '$name.${id.split('.').last}',
          old.projectId,
          old.revision,
          width: old.width,
          height: old.height,
          durationSeconds: old.durationSeconds,
        ),
        createdAt: entry.createdAt,
        bytes: entry.bytes,
        available: entry.available,
        preview: entry.preview,
        legacy: entry.legacy,
      ),
    );
  });
  @override
  Future<void> remove(String id) => _serialize(() async {
    final entry = await _entry(id);
    await _write(
      LibraryExport(
        id: id,
        artifact: entry.artifact,
        createdAt: entry.createdAt,
        bytes: entry.bytes,
        available: entry.available,
        preview: entry.preview,
        deletedAt: clock().toUtc(),
        legacy: entry.legacy,
      ),
    );
  });
  @override
  Future<void> restore(String id) => _serialize(() async {
    final entry = await _read(id);
    if (entry.deletedAt == null ||
        clock().toUtc().difference(entry.deletedAt!) >= undoWindow) {
      throw const FileSystemException('Undo window ended');
    }
    await _write(
      LibraryExport(
        id: id,
        artifact: entry.artifact,
        createdAt: entry.createdAt,
        bytes: entry.bytes,
        available: entry.available,
        preview: entry.preview,
        legacy: entry.legacy,
      ),
    );
  });
}
