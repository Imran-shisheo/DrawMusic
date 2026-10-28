import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:scribblesong/features/backgrounds/data/background_assets.dart';

import 'background_model_test.dart' show render;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/data/background_cleanup.dart';
import 'package:scribblesong/features/backgrounds/data/background_cleanup_coordination.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';

class _Lease implements BackgroundCleanupLease {
  Set<String>? pins = {};
  int starts = 0, ends = 0;
  bool held = false, fail = false;
  @override
  Future<Set<String>?> begin(String token) async {
    starts++;
    if (fail) throw StateError('native unavailable');
    held = pins != null;
    return pins;
  }

  @override
  Future<void> end(String token) async {
    ends++;
    held = false;
  }
}

void main() {
  late Directory temporary, support, documents, assets, projects;
  final now = DateTime.utc(2026, 10, 27);
  late _Lease lease;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('background-cleanup');
    support = await Directory('${temporary.path}/support').create();
    documents = await Directory('${temporary.path}/documents').create();
    assets = await Directory('${support.path}/backgrounds').create();
    projects = await Directory('${support.path}/projects').create();
    lease = _Lease();
  });
  tearDown(() async => temporary.delete(recursive: true));
  Future<String> asset(
    String name, {
    Duration age = const Duration(days: 10),
  }) async {
    final bytes = utf8.encode('Owned hash-addressed fixture $name');
    final id = sha256.convert(bytes).toString();
    final file = File('${assets.path}/$id.png');
    await file.writeAsBytes(bytes);
    await file.setLastModified(now.subtract(age));
    return id;
  }

  ProjectDocument doc(String id, String image) => ProjectDocument(
    id: id,
    paper: BackgroundDefinition(kind: BackgroundKind.photo, assetId: image),
  );
  BackgroundCleanup cleanup({
    DateTime? at,
    BackgroundStorageCoordinator? coordinator,
    Future<void> Function(BackgroundCleanupPhase)? observe,
  }) => BackgroundCleanup(
    support: support,
    documents: documents,
    lease: lease,
    coordinator: coordinator ?? BackgroundStorageCoordinator(),
    clock: () => at ?? now,
    observe: observe,
  );
  Future<void> staged(String id, {DateTime? at, bool marker = true}) async {
    final stage = await Directory('${assets.path}/.cleanup-staging').create();
    await File('${assets.path}/$id.png').rename('${stage.path}/$id.png');
    if (marker) {
      await File('${stage.path}/$id.json').writeAsString(
        jsonEncode({
          'version': 1,
          'id': id,
          'stagedAt': (at ?? now.subtract(const Duration(days: 8)))
              .toIso8601String(),
        }),
      );
    }
  }

  Future<void> envelope(File file, String payload) async => file.writeAsString(
    jsonEncode({
      'document': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    }),
  );

  test('aged true orphan stages first and only a later verified startup reclaims bytes', () async {
    final id = await asset('orphan');
    final source = File('${assets.path}/$id.png');
    final before = await source.readAsBytes();
    expect(
      await source.exists(),
      isTrue,
    ); // Legacy retain-all policy left this indefinitely.
    final first = await cleanup().run();
    expect(first.status, 'completed');
    expect(first.staged, 1);
    expect(first.deleted, 0);
    final stagedFile = File('${assets.path}/.cleanup-staging/$id.png');
    expect(await source.exists(), isFalse);
    expect(await stagedFile.readAsBytes(), before);
    final young = await cleanup(at: now.add(const Duration(days: 2))).run();
    expect(young.deleted, 0);
    expect(await stagedFile.exists(), isTrue);
    final mature = await cleanup(at: now.add(const Duration(days: 8))).run();
    expect(mature.status, 'completed');
    expect(mature.deleted, 1);
    expect(await stagedFile.exists(), isFalse);
    expect(
      (await cleanup(at: now.add(const Duration(days: 9))).run()).deleted,
      0,
    );
    expect(lease.starts, 4);
    expect(lease.ends, 4);
    expect(lease.held, isFalse);
  });
  test('new imports and future timestamps retain age protection', () async {
    final young = await asset('young', age: const Duration(days: 1));
    final future = await asset('future', age: const Duration(days: -1));
    final report = await cleanup().run();
    expect(report.staged, 0);
    expect(await File('${assets.path}/$young.png').exists(), isTrue);
    expect(await File('${assets.path}/$future.png').exists(), isTrue);
  });
  test('active, shared duplicate, retained revision, preserved/temp and deleted Undo references all pin images', () async {
    final shared = await asset('shared'),
        older = await asset('older'),
        preserved = await asset('preserved'),
        deleted = await asset('deleted');
    final repository = FileProjectRepository(projects);
    await repository.save(doc('active', shared));
    await repository.duplicate('active');
    final previous = doc('revisions', older);
    await repository.save(previous);
    await repository.save(
      previous.copyWith(paper: BackgroundDefinition.solid(0xffffffff)),
    );
    final dir = await Directory('${projects.path}/preserved').create();
    await envelope(
      File('${dir.path}/r000000000000.json.preserved-123'),
      doc('preserved', preserved).encode(),
    );
    await envelope(
      File('${dir.path}/r000000000001.json.tmp'),
      doc('preserved', preserved).encode(),
    );
    await repository.save(doc('deleted', deleted));
    await repository.softDelete('deleted');
    final orphan = await asset('truly-free');
    final report = await cleanup().run();
    expect(report.status, 'completed');
    expect(report.staged, 1);
    for (final id in [shared, older, preserved, deleted]) {
      expect(await File('${assets.path}/$id.png').exists(), isTrue);
    }
    expect(await File('${assets.path}/$orphan.png').exists(), isFalse);
  });
  test('saved export snapshot is authoritative even when its project is gone and export is deleted with Undo', () async {
    final image = await asset('export-only');
    final directory = await Directory('${documents.path}/exports').create();
    final video = File('${directory.path}/snapshot.mp4');
    await video.writeAsBytes([
      0,
      0,
      0,
      20,
      102,
      116,
      121,
      112,
      105,
      115,
      111,
      109,
    ]);
    final library = FileExportLibrary(directory, clock: () => now);
    await library.record(
      ExportArtifact(video.path, 'video/mp4', 'Snapshot.mp4', 'gone', 0),
      doc('gone', image),
    );
    await library.remove('snapshot.mp4');
    final report = await cleanup().run();
    expect(report.status, 'completed');
    expect(report.staged, 0);
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
    expect(await video.exists(), isTrue);
  });
  test('raw recovery bundle retains original photo references after project directory removal', () async {
    final image = await asset('recovery-only');
    final repository = FileProjectRepository(projects);
    await repository.save(doc('recovery', image));
    await repository.exportRecoveryData('recovery');
    await Directory('${projects.path}/recovery').delete(recursive: true);
    final report = await cleanup().run();
    expect(report.status, 'completed');
    expect(report.staged, 0);
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
  });
  test(
    'completed pending import pin and uncertain native gate prevent collection',
    () async {
      final image = await asset('pending');
      lease.pins = {image};
      expect((await cleanup().run()).staged, 0);
      lease.pins = null;
      final denied = await cleanup().run();
      expect(denied.status, 'retained-native-busy');
      expect(await File('${assets.path}/$image.png').exists(), isTrue);
      expect(lease.held, isFalse);
      expect(lease.ends, 2);
    },
  );
  test('corrupt, future, unknown and checksum-damaged references fail closed and restore staged data', () async {
    final image = await asset('uncertain');
    final dir = await Directory('${projects.path}/unknown').create();
    final source = File('${dir.path}/r000000000000.json');
    final cases = <String>[
      '{broken',
      doc(
        'unknown',
        image,
      ).encode().replaceFirst('"schemaVersion":2', '"schemaVersion":99'),
      doc('unknown', image).copyWith().encode().replaceFirst(
        '"title":',
        '"futureAssetMetadata":"retained","title":',
      ),
    ];
    for (final payload in cases) {
      await envelope(source, payload);
      final report = await cleanup().run();
      expect(report.status, 'retained-uncertain');
      expect(await File('${assets.path}/$image.png').exists(), isTrue);
    }
    await source.writeAsString('{"document":"bad","sha256":"wrong"}');
    await staged(image);
    expect((await cleanup().run()).status, 'retained-uncertain');
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
  });
  test('malformed and unknown entries retain every asset; links cannot expose or delete outside owned storage', () async {
    final image = await asset('guarded');
    final mystery = File('${projects.path}/unexpected.json');
    await mystery.writeAsString('{}');
    expect((await cleanup().run()).status, 'retained-uncertain');
    await mystery.delete();
    final outside = File('${temporary.path}/external.png');
    await outside.writeAsString('external');
    await Link('${assets.path}/${'a' * 64}.png').create(outside.path);
    expect((await cleanup().run()).status, 'retained-uncertain');
    expect(await outside.readAsString(), 'external');
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
  });
  test('interruption before/after staging is recoverable; pinned or uncertain staged images restore', () async {
    final pinned = await asset('staged-pin');
    await staged(pinned);
    lease.pins = {pinned};
    final restored = await cleanup().run();
    expect(restored.restored, 1);
    expect(await File('${assets.path}/$pinned.png').exists(), isTrue);
    final missingMarker = await asset('missing-marker');
    await staged(missingMarker, marker: false);
    expect((await cleanup().run()).status, 'retained-uncertain');
    expect(await File('${assets.path}/$missingMarker.png').exists(), isTrue);
    final beforeMove = await asset('before-move');
    final marker = File('${assets.path}/.cleanup-staging/$beforeMove.json');
    await marker.writeAsString(
      jsonEncode({
        'version': 1,
        'id': beforeMove,
        'stagedAt': now.toIso8601String(),
      }),
    );
    await cleanup().run();
    expect(
      await File('${assets.path}/$beforeMove.png').exists(),
      isFalse,
    ); // safely staged anew
  });
  test('reference mutation during analysis prevents sweep and restores staged assets', () async {
    final image = await asset('late-reference');
    await staged(image);
    var changed = false;
    final report = await cleanup(
      observe: (phase) async {
        if (phase == BackgroundCleanupPhase.marked && !changed) {
          changed = true;
          final dir = await Directory('${projects.path}/late').create();
          await envelope(
            File('${dir.path}/r000000000000.json'),
            doc('late', image).encode(),
          );
        }
      },
    ).run();
    expect(report.status, 'retained-uncertain');
    expect(report.deleted, 0);
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
  });
  test('queued save aborts collection before writers resume and later duplicate stays usable', () async {
    final image = await asset('queued-save');
    final coordinator = BackgroundStorageCoordinator();
    final repository = FileProjectRepository(
      projects,
      coordinator: coordinator,
    );
    Future<void>? pending;
    final report = await cleanup(
      coordinator: coordinator,
      observe: (phase) async {
        if (phase == BackgroundCleanupPhase.marked && pending == null) {
          pending = repository.save(doc('queued', image));
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(await Directory('${projects.path}/queued').exists(), isFalse);
        }
      },
    ).run();
    await pending;
    expect(report.status, 'retained-uncertain');
    expect(report.deleted, 0);
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
    expect((await repository.load('queued')).paper!.assetId, image);
    await repository.duplicate('queued');
  });
  test('startup barrier denies active writer and permanently denies cleanup after editor/application start', () async {
    final image = await asset('live-history');
    final coordinator = BackgroundStorageCoordinator();
    final hold = Completer<void>();
    final entered = Completer<void>();
    final writer = coordinator.write(() async {
      entered.complete();
      await hold.future;
    });
    await entered.future;
    expect(
      (await cleanup(coordinator: coordinator).run()).status,
      'skipped-busy-or-running',
    );
    hold.complete();
    await writer;
    coordinator.applicationStarted();
    expect(
      (await cleanup(coordinator: coordinator).run()).status,
      'skipped-busy-or-running',
    );
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
  });
  test('failed native startup releases waiting writes and never leaves a lease held', () async {
    lease.fail = true;
    final coordinator = BackgroundStorageCoordinator();
    final report = await cleanup(coordinator: coordinator).run();
    expect(report.status, 'retained-uncertain');
    await FileProjectRepository(
      projects,
      coordinator: coordinator,
    ).save(ProjectDocument(id: 'usable'));
    expect(
      await File('${projects.path}/usable/r000000000000.json').exists(),
      isTrue,
    );
    expect(lease.ends, 1);
    expect(lease.held, isFalse);
  });
  test('interrupted temporary journal retries without losing PNG bytes or resetting a completed stage age', () async {
    final image = await asset('temporary-journal');
    final stage = await Directory('${assets.path}/.cleanup-staging').create();
    final temporaryMarker = File('${stage.path}/$image.json.tmp');
    await temporaryMarker.writeAsString('{interrupted before rename');
    final first = await cleanup().run();
    expect(first.status, 'completed');
    expect(first.staged, 1);
    expect(await temporaryMarker.exists(), isFalse);
    final marker = File('${stage.path}/$image.json');
    final originalMarker = await marker.readAsString();
    await cleanup(at: now.add(const Duration(days: 2))).run();
    expect(await marker.readAsString(), originalMarker);
    expect(
      (await cleanup(at: now.add(const Duration(days: 8))).run()).deleted,
      1,
    );
  });
  test('unknown staging journal restores valid image but preserves unknown journal bytes and fails closed', () async {
    final image = await asset('future-journal');
    await staged(image);
    final marker = File('${assets.path}/.cleanup-staging/$image.json');
    const future = '{"version":99,"unknown":"retain these bytes"}';
    await marker.writeAsString(future);
    final report = await cleanup().run();
    expect(report.status, 'retained-uncertain');
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
    expect(await marker.readAsString(), future);
    expect((await cleanup().run()).status, 'retained-uncertain');
  });
  test('queued export snapshot mutation aborts cleanup before it can make a new photo reference', () async {
    final image = await asset('queued-export');
    final coordinator = BackgroundStorageCoordinator();
    final dir = await Directory('${documents.path}/exports').create();
    final video = File('${dir.path}/queued.mp4');
    await video.writeAsBytes([
      0,
      0,
      0,
      20,
      102,
      116,
      121,
      112,
      105,
      115,
      111,
      109,
    ]);
    final library = FileExportLibrary(dir, coordinator: coordinator);
    Future<void>? pending;
    final report = await cleanup(
      coordinator: coordinator,
      observe: (phase) async {
        if (phase == BackgroundCleanupPhase.marked && pending == null) {
          pending = library.record(
            ExportArtifact(video.path, 'video/mp4', 'Queued.mp4', 'gone', 0),
            doc('gone', image),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(await File('${video.path}.json').exists(), isFalse);
        }
      },
    ).run();
    await pending;
    expect(report.status, 'retained-uncertain');
    expect(await File('${assets.path}/$image.png').exists(), isTrue);
    expect(
      (await library.list()).entries.single.preview!.paper!.assetId,
      image,
    );
  });
  test('application singleton storage barrier is the default repository coordination and permanently seals on UI start', () async {
    final coordinator = BackgroundStorageCoordinator.application;
    expect(coordinator.beginStartupCleanup(), isTrue);
    final repository = FileProjectRepository(projects);
    final pending = repository.save(ProjectDocument(id: 'startup-singleton'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      await Directory('${projects.path}/startup-singleton').exists(),
      isFalse,
    );
    expect(coordinator.hasWaitingWriters, isTrue);
    coordinator.finishStartupCleanup();
    await pending;
    coordinator.applicationStarted();
    expect(
      (await cleanup(coordinator: coordinator).run()).status,
      'skipped-busy-or-running',
    );
    expect(
      (await repository.load('startup-singleton')).id,
      'startup-singleton',
    );
  });
  test('bounded aborted rollback defers remaining PNGs and readonly decoder can still render staged data', () async {
    final image = await render(BackgroundDefinition.solid(0xffef1234));
    final encoded = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    final id = sha256.convert(encoded).toString();
    final stage = await Directory('${assets.path}/.cleanup-staging').create();
    final source = File('${stage.path}/$id.png');
    await source.writeAsBytes(encoded);
    await File('${stage.path}/$id.json').writeAsString('{"version":99}');
    final report = await BackgroundCleanup(
      support: support,
      documents: documents,
      lease: lease,
      coordinator: BackgroundStorageCoordinator(),
      clock: () => now,
      recoveryEntryLimit: 0,
    ).run();
    expect(report.status, 'retained-uncertain');
    expect(report.recoveryDeferred, isTrue);
    expect(await source.exists(), isTrue);
    expect(await File('${assets.path}/$id.png').exists(), isFalse);
    final decoded = await BackgroundAssets(assets).decode(
      BackgroundDefinition(kind: BackgroundKind.photo, assetId: id),
      maxWidth: 16,
      maxHeight: 20,
    );
    expect(decoded, isNotNull);
    expect(decoded!.width, 16);
    decoded.dispose();
    expect(await source.readAsBytes(), encoded);
    await source.writeAsBytes([1, 2, 3]);
    await expectLater(
      BackgroundAssets(
        assets,
      ).decode(BackgroundDefinition(kind: BackgroundKind.photo, assetId: id)),
      throwsFormatException,
    );
    await source.delete();
    final external = File('${temporary.path}/external-valid.png');
    await external.writeAsBytes(encoded);
    await Link(source.path).create(external.path);
    expect(await resolveBackgroundAssetFile(assets, id), isNull);
    expect(await external.readAsBytes(), encoded);
  });
  test('abort rollback only renames large unvalidated private bytes; decoder does not mistake them for valid art', () async {
    final id = sha256.convert(utf8.encode('large retained bytes')).toString();
    final stage = await Directory('${assets.path}/.cleanup-staging').create();
    final source = File('${stage.path}/$id.png');
    final handle = await source.open(mode: FileMode.write);
    await handle.setPosition(64 * 1024 * 1024);
    await handle.writeByte(7);
    await handle.close();
    await File('${stage.path}/$id.json').writeAsString('{"version":99}');
    final report = await cleanup().run();
    expect(report.status, 'retained-uncertain');
    expect(report.restored, 1);
    final active = File('${assets.path}/$id.png');
    expect(await active.length(), 64 * 1024 * 1024 + 1);
    expect(await source.exists(), isFalse);
    await expectLater(
      BackgroundAssets(
        assets,
      ).decode(BackgroundDefinition(kind: BackgroundKind.photo, assetId: id)),
      throwsFormatException,
    );
  });
}
