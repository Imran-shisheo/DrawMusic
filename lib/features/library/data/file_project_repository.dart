import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../../../creative_document/document.dart';
import '../domain/project_repository.dart';
import '../domain/recovery_export_port.dart';

// Immutable checksummed revisions and atomic publication. Previous complete
// revisions remain available when the newest file is corrupt or a write fails.
class FileProjectRepository implements ProjectRepository, RecoveryExportPort {
  FileProjectRepository(this.root);
  final Directory root;
  Future<void> _queue = Future.value();
  void _validate(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid project ID');
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final pending = _queue.then((_) => operation());
    _queue = pending.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return pending;
  }

  @override
  Future<void> save(ProjectDocument document) =>
      _serialize(() => _save(document));

  Future<void> _save(ProjectDocument document) async {
    _validate(document.id);
    if (await File('${root.path}/${document.id}/deleted.json').exists()) {
      throw const FileSystemException('Drawing is deleted');
    }
    final dir = Directory('${root.path}/${document.id}');
    await dir.create(recursive: true);
    final existing = await _revisions(dir);
    if (existing.isNotEmpty) {
      final current = await load(document.id);
      if (current.revision > document.revision) return;
    }
    final encoded = await Isolate.run(() => _encodeRevision(document));
    final payload = encoded.payload, envelope = encoded.envelope;
    final target = File(
      '${dir.path}/r${document.revision.toString().padLeft(12, '0')}.json',
    );
    if (await target.exists()) {
      try {
        final existingDocument = await _read(target);
        if (await Isolate.run(() => existingDocument.encode() == payload)) {
          return;
        }
      } catch (_) {
        /* Preserve damaged or unsupported data before replacing its ordinal. */
      }
      await target.copy(
        '${target.path}.preserved-${DateTime.now().microsecondsSinceEpoch}',
      );
    }
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(envelope, flush: true);
    await temporary.rename(target.path);
    // Keep three VERIFIED complete revisions, not merely three filenames.
    // Damaged/future-version/foreign-identity files must neither consume the
    // recovery budget nor be removed by housekeeping.
    final revisions = await _revisions(dir);
    if (revisions.length <= 3) return;
    var verified = 0;
    for (final file in revisions) {
      try {
        final stored = await _read(file);
        if (stored.id != document.id) continue;
        verified++;
      } catch (_) {
        continue;
      }
      if (verified > 3) {
        try {
          await file.delete();
        } on FileSystemException {
          // Publication succeeded; a retention failure is safe to retry later.
        }
      }
    }
  }

  Future<List<File>> _revisions(Directory dir) async {
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((f) => f is File && RegExp(r'/r\d{12}\.json$').hasMatch(f.path))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<ProjectDocument> _read(File file) async {
    if (await file.length() > 20000000) {
      throw const FormatException('Project exceeds storage limit');
    }
    final text = await file.readAsString();
    return Isolate.run(() => _decodeRevision(text));
  }

  @override
  Future<ProjectLoad> open(String id) async {
    _validate(id);
    if (await File('${root.path}/$id/deleted.json').exists()) {
      throw const FileSystemException('Drawing is deleted');
    }
    final revisions = await _revisions(Directory('${root.path}/$id'));
    if (revisions.isEmpty) throw const FileSystemException('Drawing not found');
    Object? error;
    for (final file in revisions) {
      try {
        final doc = await _read(file);
        if (doc.id != id) {
          throw const FormatException('Project identity mismatch');
        }
        return ProjectLoad(doc, recovered: error != null);
      } catch (e) {
        error = e;
      }
    }
    throw FormatException('Could not recover drawing: $error');
  }

  @override
  Future<ProjectDocument> load(String id) async => (await open(id)).document;

  @override
  Future<void> rename(String id, String title) => _serialize(() async {
    final name = title.trim();
    if (name.isEmpty || name.length > 60) {
      throw const FormatException('Use a name of 1–60 characters');
    }
    final document = await load(id);
    await _save(document.copyWith(title: name));
  });

  @override
  Future<ProjectDocument> duplicate(String id) => _serialize(() async {
    final document = await load(id);
    var name = document.title;
    if (name.length > 55) {
      name = name.substring(0, 55);
      if (name.codeUnitAt(name.length - 1) >= 0xd800 &&
          name.codeUnitAt(name.length - 1) <= 0xdbff) {
        name = name.substring(0, name.length - 1);
      }
    }
    final now = DateTime.now().toUtc();
    final copy = document.copyWith(
      id: newId(),
      title: '$name copy',
      revision: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _save(copy);
    return copy;
  });

  /// A lossless, bounded raw-byte envelope, never a pretend decoded project.
  @override
  Future<String> exportRecoveryData(String id) => _serialize(() async {
    _validate(id);
    final directory = Directory('${root.path}/$id');
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException('Recovery project is unavailable');
    }
    final ownedRoot = await root.resolveSymbolicLinks();
    final ownedProject = await directory.resolveSymbolicLinks();
    if (ownedProject != '$ownedRoot/$id') {
      throw const FileSystemException('Invalid recovery project location');
    }
    const byteLimit = 64 * 1024 * 1024;
    const fileLimit = 200;
    final revisions = <(File, FileStat, String)>[];
    var totalBytes = 0;
    final allowed = RegExp(
      r'^(r[0-9]{12}\.json(\.tmp|\.preserved-[0-9]+)?|deleted\.json(\.tmp)?)$',
    );
    await for (final entity in directory.list(followLinks: false)) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File || !allowed.hasMatch(name)) {
        throw const FileSystemException(
          'Unsupported recovery entry; original files retained',
        );
      }
      final stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size < 0 ||
          await entity.resolveSymbolicLinks() != '$ownedProject/$name') {
        throw const FileSystemException('Invalid recovery file location');
      }
      totalBytes += stat.size;
      if (revisions.length >= fileLimit || totalBytes > byteLimit) {
        throw const FileSystemException(
          'Recovery export exceeds 200 files or 64 MiB',
        );
      }
      revisions.add((entity, stat, name));
    }
    if (revisions.isEmpty) throw const FileSystemException('No recovery files');
    revisions.sort((a, b) => a.$3.compareTo(b.$3));
    final destination = Directory('${root.parent.path}/recovery-exports');
    final destinationType = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (destinationType != FileSystemEntityType.notFound &&
        destinationType != FileSystemEntityType.directory) {
      throw const FileSystemException('Invalid recovery export destination');
    }
    await destination.create(recursive: true);
    final ownedParent = await root.parent.resolveSymbolicLinks();
    if (await destination.resolveSymbolicLinks() !=
        '$ownedParent/recovery-exports') {
      throw const FileSystemException('Invalid recovery export destination');
    }
    final output = File(
      '${destination.path}/${id}_${newId()}.drawmusic-recovery.json',
    );
    final temporary = File('${output.path}.tmp');
    IOSink? sink;
    var completed = false;
    try {
      sink = temporary.openWrite();
      // Install the asynchronous I/O error handler before the first write.
      final closed = sink.done;
      unawaited(closed.catchError((Object _) {}));
      sink.write(
        '{"format":"drawmusic-raw-recovery","bundleVersion":1,"projectId":${jsonEncode(id)},"totalBytes":$totalBytes,"files":[',
      );
      await sink.flush();
      var first = true;
      for (final (file, original, name) in revisions) {
        final digest = await sha256.bind(file.openRead(0, original.size)).first;
        if (!first) sink.write(',');
        first = false;
        sink.write(
          '{"name":${jsonEncode(name)},"bytes":${original.size},"sha256":${jsonEncode(digest.toString())},"contentBase64":"',
        );
        await sink.flush();
        await for (final chunk in base64.encoder.bind(
          file.openRead(0, original.size),
        )) {
          sink.write(chunk);
          // Backpressure bounds pending output, including a maximum-size file.
          await sink.flush();
        }
        sink.write('"}');
        final after = await file.stat();
        if (after.size != original.size ||
            after.modified != original.modified ||
            await FileSystemEntity.type(file.path, followLinks: false) !=
                FileSystemEntityType.file) {
          throw const FileSystemException('Recovery files changed; retry');
        }
      }
      sink.write(']}');
      await sink.flush();
      await sink.close();
      sink = null;
      await temporary.rename(output.path);
      completed = true;
      return output.path;
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        /* Preserve the original I/O failure. */
      }
      if (await temporary.exists()) await temporary.delete();
      if (!completed && await output.exists()) await output.delete();
    }
  });

  @override
  Future<void> softDelete(String id) => _serialize(() async {
    _validate(id);
    final directory = Directory('${root.path}/$id');
    if (!await directory.exists()) {
      throw const FileSystemException('Drawing not found');
    }
    final temporary = File('${directory.path}/deleted.json.tmp');
    await temporary.writeAsString(
      jsonEncode({'deletedAt': DateTime.now().toUtc().toIso8601String()}),
      flush: true,
    );
    await temporary.rename('${directory.path}/deleted.json');
  });
  @override
  Future<void> restore(String id) => _serialize(() async {
    _validate(id);
    if (!await Directory('${root.path}/$id').exists()) {
      throw const FileSystemException('Drawing not found');
    }
    final marker = File('${root.path}/$id/deleted.json');
    if (await marker.exists()) await marker.delete();
  });

  @override
  Future<ProjectListing> list() async {
    await root.create(recursive: true);
    final projects = <ProjectDocument>[],
        failures = <String>[],
        recoveredIds = <String>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (await File('${entry.path}/deleted.json').exists()) continue;
      try {
        final result = await open(id);
        projects.add(result.document);
        if (result.recovered) recoveredIds.add(id);
      } catch (_) {
        failures.add(id);
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ProjectListing(projects, failures, recoveredIds: recoveredIds);
  }
}

// CPU-heavy JSON and checksum work operates on immutable data in a worker.
// File publication/recovery stays in the repository's serialized I/O queue.
({String payload, String envelope}) _encodeRevision(ProjectDocument document) {
  final payload = document.encode();
  return (
    payload: payload,
    envelope: jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'document': payload,
    }),
  );
}

ProjectDocument _decodeRevision(String text) {
  final j = jsonDecode(text) as Map<String, dynamic>;
  final payload = j['document'] as String;
  if (sha256.convert(utf8.encode(payload)).toString() != j['sha256']) {
    throw const FormatException('Project checksum failed');
  }
  return ProjectDocument.decode(payload);
}
