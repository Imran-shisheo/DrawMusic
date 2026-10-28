import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../creative_document/document.dart';
import 'background_cleanup_coordination.dart';

abstract interface class BackgroundCleanupLease {
  /// Null denies cleanup. A successful lease excludes native imports/recovery
  /// and exports until end, and pins every completed but unacknowledged import.
  Future<Set<String>?> begin(String token);
  Future<void> end(String token);
}

class NativeBackgroundCleanupLease implements BackgroundCleanupLease {
  static const channel = MethodChannel('scribblesong/backgrounds');
  @override
  Future<Set<String>?> begin(String token) async {
    final value = await channel.invokeMapMethod<String, dynamic>(
      'beginCleanup',
      {'token': token},
    );
    if (value == null || value['allowed'] != true) return null;
    return (value['pins'] as List).cast<String>().toSet();
  }

  @override
  Future<void> end(String token) =>
      channel.invokeMethod<void>('endCleanup', {'token': token});
}

class BackgroundCleanupReport {
  const BackgroundCleanupReport(
    this.status, {
    this.staged = 0,
    this.deleted = 0,
    this.restored = 0,
    this.recoveryDeferred = false,
  });
  final String status;
  final int staged, deleted, restored;
  final bool recoveryDeferred;
  Map<String, Object> toJson() => {
    'status': status,
    'staged': staged,
    'deleted': deleted,
    'restored': restored,
    'recoveryDeferred': recoveryDeferred,
  };
}

enum BackgroundCleanupPhase { marked, staged, beforeDelete }

/// Only run before applicationStarted: no editor, Undo state or picker may be
/// constructed. Uncertain storage is retained; staged valid bytes are restored.
class BackgroundCleanup {
  BackgroundCleanup({
    required this.support,
    required this.documents,
    required this.lease,
    BackgroundStorageCoordinator? coordinator,
    DateTime Function()? clock,
    this.assetGrace = const Duration(days: 7),
    this.stageGrace = const Duration(days: 7),
    this.observe,
    this.recoveryEntryLimit = 1000,
    this.recoveryBudget = const Duration(seconds: 2),
  }) : coordinator = coordinator ?? BackgroundStorageCoordinator.application,
       clock = clock ?? DateTime.now;
  final Directory support, documents;
  final BackgroundCleanupLease lease;
  final BackgroundStorageCoordinator coordinator;
  final DateTime Function() clock;
  final Duration assetGrace, stageGrace, recoveryBudget;
  final int recoveryEntryLimit;
  final Future<void> Function(BackgroundCleanupPhase)? observe;
  static final _id = RegExp(r'^[a-f0-9]{64}$');
  static final _projectId = RegExp(r'^[a-zA-Z0-9_-]{1,80}$');
  static final _revision = RegExp(
    r'^r[0-9]{12}\.json(\.tmp|\.preserved-[0-9]+)?$',
  );
  Directory get assets => Directory('${support.path}/backgrounds');
  Directory get staging => Directory('${assets.path}/.cleanup-staging');
  int _files = 0, _bytes = 0;
  final _fingerprints = <String, String>{};
  final _pins = <String>{};
  int _staged = 0, _deleted = 0, _restored = 0;
  bool _ownershipVerified = false, _recoveryDeferred = false;
  final Stopwatch _elapsed = Stopwatch();

  Future<BackgroundCleanupReport> run() async {
    if (!coordinator.beginStartupCleanup()) {
      return const BackgroundCleanupReport('skipped-busy-or-running');
    }
    final token = newId();
    var acquired = false;
    _elapsed.start();
    try {
      final pins = await lease
          .begin(token)
          .timeout(const Duration(seconds: 10));
      if (pins == null || pins.any((id) => !_id.hasMatch(id))) {
        return const BackgroundCleanupReport('retained-native-busy');
      }
      acquired = true;
      _pins.addAll(pins);
      await _ownedDirectory(support, create: false);
      await _ownedDirectory(assets, create: false);
      await _ownedDirectory(staging, create: false);
      _ownershipVerified = true;
      await _recoverJournalTemps();
      final staged = await _readStaged();
      final active = await _readAssets();
      _fingerprints.clear();
      await _markReferences();
      final firstInventory = Map<String, String>.of(_fingerprints);
      await observe?.call(BackgroundCleanupPhase.marked);
      // Detect writers or files appearing during the scan. Legitimate writers
      // are excluded by the Dart/native startup leases; this is additional care.
      _files = 0;
      _bytes = 0;
      _fingerprints.clear();
      await _markReferences();
      if (!_sameInventory(firstInventory, _fingerprints)) {
        throw const FormatException('Reference inventory changed');
      }
      for (final item in staged.entries) {
        _bound();
        final id = item.key;
        if (_pins.contains(id)) {
          await _restore(id);
        } else if (clock().toUtc().difference(item.value) >= stageGrace) {
          await observe?.call(BackgroundCleanupPhase.beforeDelete);
          // A fresh full source inventory is required immediately before sweep.
          _files = 0;
          _bytes = 0;
          _fingerprints.clear();
          await _markReferences();
          if (!_sameInventory(firstInventory, _fingerprints) ||
              _pins.contains(id)) {
            throw const FormatException('References changed before sweep');
          }
          await _verifiedAsset(File('${staging.path}/$id.png'), id);
          _bound();
          await File('${staging.path}/$id.png').delete();
          await File('${staging.path}/$id.json').delete();
          _deleted++;
        }
      }
      for (final file in active) {
        _bound();
        final id = file.uri.pathSegments.last.substring(0, 64);
        if (_pins.contains(id) ||
            await File('${staging.path}/$id.png').exists()) {
          continue;
        }
        final stat = await file.stat();
        final age = clock().toUtc().difference(stat.modified.toUtc());
        if (age < assetGrace) continue;
        await _verifiedAsset(file, id);
        await _ownedDirectory(staging, create: true);
        final marker = File('${staging.path}/$id.json');
        final temporary = File('${marker.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({
            'version': 1,
            'id': id,
            'stagedAt': clock().toUtc().toIso8601String(),
          }),
          flush: true,
        );
        await temporary.rename(marker.path);
        await file.rename('${staging.path}/$id.png');
        _staged++;
        await observe?.call(BackgroundCleanupPhase.staged);
      }
      _files = 0;
      _bytes = 0;
      _fingerprints.clear();
      await _markReferences();
      if (!_sameInventory(firstInventory, _fingerprints)) {
        throw const FormatException('References changed after staging');
      }
      _bound();
      return BackgroundCleanupReport(
        'completed',
        staged: _staged,
        deleted: _deleted,
        restored: _restored,
      );
    } catch (_) {
      if (acquired && _ownershipVerified) {
        try {
          await _restoreAll();
        } catch (_) {
          /* Never sweep on uncertain recovery. */
        }
      }
      return BackgroundCleanupReport(
        'retained-uncertain',
        staged: _staged,
        deleted: _deleted,
        restored: _restored,
        recoveryDeferred: _recoveryDeferred,
      );
    } finally {
      // Also release when begin's response was lost/late: calls are ordered on
      // the native main channel and only this token may release this lease.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await lease.end(token).timeout(const Duration(seconds: 10));
          break;
        } catch (_) {
          // Idempotent retry handles a lost completion. A broken native bridge
          // stays conservatively blocked until engine restart, never swept.
        }
      }
      coordinator.finishStartupCleanup();
      _elapsed.stop();
    }
  }

  void _bound() {
    if (coordinator.hasWaitingWriters ||
        _elapsed.elapsed > const Duration(seconds: 10) ||
        ++_files > 10000 ||
        _bytes > 64 * 1024 * 1024) {
      throw const FormatException('Cleanup analysis budget exceeded');
    }
  }

  Future<void> _ownedDirectory(
    Directory directory, {
    required bool create,
  }) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      if (create) await directory.create(recursive: true);
      return;
    }
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('Unexpected storage link or type');
    }
    final parent = await directory.parent.resolveSymbolicLinks();
    if (await directory.resolveSymbolicLinks() !=
        '$parent/${directory.uri.pathSegments.where((s) => s.isNotEmpty).last}') {
      throw const FormatException('Unowned storage directory');
    }
  }

  Future<List<FileSystemEntity>> _entries(Directory dir) async {
    await _ownedDirectory(dir, create: false);
    if (!await dir.exists()) return [];
    final result = <FileSystemEntity>[];
    await for (final item in dir.list(followLinks: false)) {
      _bound();
      result.add(item);
    }
    return result;
  }

  Future<List<int>> _source(File file, {int maxBytes = 20000000}) async {
    _bound();
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Unexpected reference source');
    }
    final size = await file.length();
    if (size > maxBytes || size < 0) {
      throw const FormatException('Reference size exceeded');
    }
    _bytes += size;
    _bound();
    final bytes = await file.readAsBytes();
    _fingerprints[file.path] = sha256.convert(bytes).toString();
    return bytes;
  }

  Future<List<File>> _readAssets() async {
    final result = <File>[];
    for (final item in await _entries(assets)) {
      final name = item.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name == '.cleanup-staging' && item is Directory) continue;
      if (item is! File || !RegExp(r'^[a-f0-9]{64}\.png$').hasMatch(name)) {
        throw const FormatException('Unknown background entry');
      }
      result.add(item);
    }
    return result;
  }

  Future<void> _verifiedAsset(File file, String id) async {
    if (!_id.hasMatch(id) ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const FormatException('Unsafe asset');
    }
    final size = await file.length();
    if (size < 1 || size > 32 * 1024 * 1024) {
      throw const FormatException('Unsafe asset size');
    }
    _bytes += size;
    _bound();
    if ((await sha256.bind(file.openRead()).first).toString() != id) {
      throw const FormatException('Asset checksum mismatch');
    }
  }

  Future<void> _recoverJournalTemps() async {
    for (final entry in await _entries(staging)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!RegExp(r'^[a-f0-9]{64}\.json\.tmp$').hasMatch(name)) continue;
      if (entry is! File) {
        throw const FormatException('Unsafe journal temporary');
      }
      final id = name.substring(0, 64);
      final image = File('${staging.path}/$id.png');
      if (!await image.exists()) {
        // Journal publication precedes moving any bytes. An interrupted partial
        // journal without staged bytes cannot describe a committed deletion.
        await entry.delete();
      } else {
        final j = jsonDecode(
          utf8.decode(await _source(entry, maxBytes: 4096)),
        ) as Map<String, dynamic>;
        _known(j, {'version', 'id', 'stagedAt'});
        if (j['version'] != 1 || j['id'] != id) {
          throw const FormatException('Unknown journal temporary');
        }
        DateTime.parse(j['stagedAt'] as String);
        final marker = File('${staging.path}/$id.json');
        if (!await marker.exists()) {
          await entry.rename(marker.path);
        } else {
          await entry.delete();
        }
      }
    }
  }

  Future<Map<String, DateTime>> _readStaged() async {
    final entries = await _entries(staging);
    final names = entries
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    final result = <String, DateTime>{};
    for (final entry in entries) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entry is! File ||
          !RegExp(r'^[a-f0-9]{64}\.(png|json)$').hasMatch(name)) {
        throw const FormatException('Unknown cleanup journal');
      }
      if (!name.endsWith('.json')) continue;
      final id = name.substring(0, 64);
      final j = jsonDecode(
        utf8.decode(await _source(entry, maxBytes: 4096)),
      ) as Map<String, dynamic>;
      if (j.keys.toSet().difference({'version', 'id', 'stagedAt'}).isNotEmpty ||
          j['version'] != 1 ||
          j['id'] != id) {
        throw const FormatException('Unknown cleanup journal');
      }
      final at = DateTime.parse(j['stagedAt'] as String).toUtc();
      if (at.isAfter(clock().toUtc())) {
        throw const FormatException('Cleanup clock rollback');
      }
      if (!names.contains('$id.png')) {
        if (await File('${assets.path}/$id.png').exists()) {
          await entry.delete();
          continue;
        }
        // A completed deletion may have been interrupted before marker removal.
        await entry.delete();
        continue;
      }
      await _verifiedAsset(File('${staging.path}/$id.png'), id);
      result[id] = at;
    }
    for (final name in names.where((n) => n.endsWith('.png'))) {
      if (!names.contains('${name.substring(0, 64)}.json')) {
        throw const FormatException('Interrupted cleanup journal');
      }
    }
    return result;
  }

  Future<void> _restore(String id) async {
    final file = File('${staging.path}/$id.png');
    if (!await file.exists()) return;
    await _verifiedAsset(file, id);
    final original = File('${assets.path}/$id.png');
    if (await original.exists()) {
      await _verifiedAsset(original, id);
      await file.delete(); // The identical active copy remains available.
    } else {
      await file.rename(original.path);
    }
    _restored++;
    await _removeKnownMarker(id);
  }

  Future<void> _removeKnownMarker(String id) async {
    final marker = File('${staging.path}/$id.json');
    if (await FileSystemEntity.type(marker.path, followLinks: false) ==
        FileSystemEntityType.file) {
      try {
        if (await marker.length() <= 4096) {
          final j =
              jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
          _known(j, {'version', 'id', 'stagedAt'});
          if (j['version'] == 1 && j['id'] == id) {
            DateTime.parse(j['stagedAt'] as String);
            await marker.delete();
          }
        }
      } catch (_) {
        /* Unknown/corrupt journal bytes remain untouched. */
      }
    }
  }

  Future<void> _restoreAll() async {
    // Abort recovery is nondestructive: no whole-image reads/hashes or active
    // overwrite. A bounded number of private renames restores availability;
    // normal decoders still verify SHA, size and image bounds on every read.
    await _ownedDirectory(staging, create: false);
    if (!await staging.exists()) return;
    final recoveryClock = Stopwatch()..start();
    var inspected = 0;
    await for (final item in staging.list(followLinks: false)) {
      if (++inspected > recoveryEntryLimit ||
          recoveryClock.elapsed > recoveryBudget) {
        _recoveryDeferred = true;
        return;
      }
      if (item is! File ||
          !RegExp(r'^[a-f0-9]{64}\.png$')
              .hasMatch(item.uri.pathSegments.last)) {
        continue;
      }
      final id = item.uri.pathSegments.last.substring(0, 64);
      try {
        if (await FileSystemEntity.type(item.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await item.resolveSymbolicLinks() !=
                '${await staging.resolveSymbolicLinks()}/$id.png') {
          continue;
        }
        final original = File('${assets.path}/$id.png');
        if (await FileSystemEntity.type(original.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
          await item.rename(original.path);
          _restored++;
          await _removeKnownMarker(id);
        } else {
          _recoveryDeferred = true; // Retain both copies; never overwrite uncertain active bytes.
        }
      } catch (_) {
        _recoveryDeferred =
            true; /* Retain bytes for on-demand read/next startup. */
      }
    }
  }

  void _known(Map<dynamic, dynamic> j, Set<String> keys) {
    if (j.keys.any((k) => k is! String || !keys.contains(k))) {
      throw const FormatException('Unknown reference metadata');
    }
  }

  void _markDocument(String payload, {String? projectId}) {
    final j = jsonDecode(payload) as Map<String, dynamic>;
    _known(j, {
      'schemaVersion',
      'engineVersion',
      'id',
      'title',
      'strokes',
      'tempo',
      'scale',
      'root',
      'background',
      'paper',
      'mix',
      'style',
      'expressionMode',
      'revision',
      'createdAt',
      'updatedAt',
    });
    final doc = ProjectDocument.decode(payload);
    if (projectId != null && doc.id != projectId ||
        doc.hasCompatibilityFallbacks) {
      throw const FormatException('Uncertain document compatibility');
    }
    for (final stroke in doc.strokes) {
      if (stroke.extraFields.isNotEmpty) {
        throw const FormatException('Unknown stroke metadata');
      }
    }
    if (j['paper'] != null) {
      final paper = j['paper'] as Map<String, dynamic>;
      _known(paper, {
        'kind',
        'colors',
        'opacity',
        'assetId',
        'crop',
        'quarterTurns',
        'mirror',
      });
      if (doc.paper!.unknownKind != null) {
        throw const FormatException('Unknown background kind');
      }
      if (doc.paper!.assetId != null) _pins.add(doc.paper!.assetId!);
    }
    if (j['mix'] != null) {
      final mix = j['mix'] as Map<String, dynamic>;
      _known(mix, AccompanimentLayer.values.map((l) => l.name).toSet());
      for (final value in mix.values) {
        _known(value as Map, {'enabled', 'muted', 'level'});
      }
    }
  }

  void _markRevision(List<int> bytes, {String? projectId}) {
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    _known(envelope, {'sha256', 'document'});
    final payload = envelope['document'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('Damaged revision');
    }
    _markDocument(payload, projectId: projectId);
  }

  Future<void> _markReferences() async {
    final projects = Directory('${support.path}/projects');
    for (final project in await _entries(projects)) {
      final id = project.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (project is! Directory || !_projectId.hasMatch(id)) {
        throw const FormatException('Unknown project entry');
      }
      var sawRevision = false;
      for (final entry in await _entries(project)) {
        if (entry is! File) {
          throw const FormatException('Unknown revision entry');
        }
        final name = entry.uri.pathSegments.last;
        final bytes = await _source(entry);
        if (_revision.hasMatch(name)) {
          sawRevision = true;
          _markRevision(bytes, projectId: id);
        } else if (name == 'deleted.json' || name == 'deleted.json.tmp') {
          final marker = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          _known(marker, {'deletedAt'});
          DateTime.parse(marker['deletedAt'] as String);
        } else {
          throw const FormatException('Unknown project file');
        }
      }
      if (!sawRevision) {
        throw const FormatException('Project has no analyzable revision');
      }
    }
    for (final entry in await _entries(
      Directory('${documents.path}/exports'),
    )) {
      if (entry is! File) throw const FormatException('Unknown export entry');
      final name = entry.uri.pathSegments.last;
      if (RegExp(r'\.(mid|wav|mp4|png)$').hasMatch(name)) continue;
      if (!RegExp(r'\.(mid|wav|mp4|png)\.json(\.tmp|\.preserved-[0-9]+)?$')
          .hasMatch(name)) {
        throw const FormatException('Unknown export metadata');
      }
      final envelope = jsonDecode(
        utf8.decode(await _source(entry, maxBytes: 256000)),
      ) as Map<String, dynamic>;
      _known(envelope, {'sha256', 'payload'});
      final payload = envelope['payload'] as String;
      if (sha256.convert(utf8.encode(payload)).toString() !=
          envelope['sha256']) {
        throw const FormatException('Damaged export metadata');
      }
      final j = jsonDecode(payload) as Map<String, dynamic>;
      _known(j, {
        'schema',
        'file',
        'name',
        'mime',
        'projectId',
        'revision',
        'createdAt',
        'width',
        'height',
        'durationSeconds',
        'framesPerSecond',
        'preview',
        'deletedAt',
        'legacy',
      });
      if (j['schema'] != 1) {
        throw const FormatException('Unknown export version');
      }
      if (j['preview'] != null) _markDocument(j['preview'] as String);
    }
    for (final path in {
      '${support.path}/recovery-exports',
      '${documents.path}/recovery-exports',
    }) {
      for (final file in await _entries(Directory(path))) {
        if (file is! File || !file.path.endsWith('.drawmusic-recovery.json')) {
          throw const FormatException('Unknown recovery export');
        }
        final j = jsonDecode(
          utf8.decode(await _source(file, maxBytes: 64 * 1024 * 1024)),
        ) as Map<String, dynamic>;
        _known(j, {
          'format',
          'bundleVersion',
          'projectId',
          'totalBytes',
          'files',
        });
        if (j['format'] != 'drawmusic-raw-recovery' ||
            j['bundleVersion'] != 1) {
          throw const FormatException('Unknown recovery format');
        }
        if (!_projectId.hasMatch(j['projectId'] as String) ||
            (j['files'] as List).isEmpty ||
            (j['files'] as List).length > 200) {
          throw const FormatException('Uncertain recovery contents');
        }
        var recoveredBytes = 0;
        for (final raw in j['files'] as List) {
          final record = raw as Map<String, dynamic>;
          _known(record, {'name', 'bytes', 'sha256', 'contentBase64'});
          final bytes = base64Decode(record['contentBase64'] as String);
          if (bytes.length != record['bytes'] ||
              sha256.convert(bytes).toString() != record['sha256']) {
            throw const FormatException('Damaged recovery payload');
          }
          recoveredBytes += bytes.length;
          final name = record['name'] as String;
          if (_revision.hasMatch(name)) {
            _markRevision(bytes, projectId: j['projectId'] as String);
          } else if (name == 'deleted.json' || name == 'deleted.json.tmp') {
            final marker =
                jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            _known(marker, {'deletedAt'});
            DateTime.parse(marker['deletedAt'] as String);
          } else {
            throw const FormatException('Unknown recovered file');
          }
        }
        if (recoveredBytes != j['totalBytes']) {
          throw const FormatException('Recovery byte count mismatch');
        }
      }
    }
  }

  bool _sameInventory(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

Future<BackgroundCleanupReport> cleanupBackgroundsBeforeApplication() async {
  try {
    final support = await getApplicationSupportDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final report = await BackgroundCleanup(
      support: support,
      documents: documents,
      lease: NativeBackgroundCleanupLease(),
    ).run();
    try {
      await File('${support.path}/background-cleanup-report.json')
          .writeAsString(jsonEncode(report.toJson()), flush: true);
    } catch (_) {
      /* Optional diagnostic never blocks creation. */
    }
    return report;
  } catch (_) {
    return const BackgroundCleanupReport('retained-unavailable');
  }
}
