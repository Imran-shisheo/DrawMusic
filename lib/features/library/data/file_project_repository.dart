import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../creative_document/document.dart';
import '../domain/project_repository.dart';

// Immutable checksummed revisions and atomic publication. Previous complete
// revisions remain available when the newest file is corrupt or a write fails.
class FileProjectRepository implements ProjectRepository {
  FileProjectRepository(this.root);
  final Directory root;
  Future<void> _queue = Future.value();
  void _validate(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid project ID');
    }
  }

  @override
  Future<void> save(ProjectDocument document) {
    final operation = _queue.then((_) => _save(document));
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _save(ProjectDocument document) async {
    _validate(document.id);
    final dir = Directory('${root.path}/${document.id}');
    await dir.create(recursive: true);
    final existing = await _revisions(dir);
    if (existing.isNotEmpty) {
      final current = await load(document.id);
      if (current.revision > document.revision) return;
    }
    final payload = document.encode();
    final envelope = jsonEncode({
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'document': payload,
    });
    final target = File(
      '${dir.path}/r${document.revision.toString().padLeft(12, '0')}.json',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(envelope, flush: true);
    await temporary.rename(target.path);
    // Keep the last 3 complete revisions. Orphan .tmp files never load.
    final revisions = await _revisions(dir);
    for (final file in revisions.skip(3)) {
      await file.delete();
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
    final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final payload = j['document'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != j['sha256']) {
      throw const FormatException('Project checksum failed');
    }
    return ProjectDocument.decode(payload);
  }

  @override
  Future<ProjectDocument> load(String id) async {
    _validate(id);
    final revisions = await _revisions(Directory('${root.path}/$id'));
    if (revisions.isEmpty) throw const FileSystemException('Drawing not found');
    Object? error;
    for (final file in revisions) {
      try {
        final doc = await _read(file);
        if (doc.id != id) {
          throw const FormatException('Project identity mismatch');
        }
        return doc;
      } catch (e) {
        error = e;
      }
    }
    throw FormatException('Could not recover drawing: $error');
  }

  @override
  Future<ProjectListing> list() async {
    await root.create(recursive: true);
    final projects = <ProjectDocument>[], failures = <String>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      try {
        projects.add(await load(id));
      } catch (_) {
        failures.add(id);
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ProjectListing(projects, failures);
  }
}
