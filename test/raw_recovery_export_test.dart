import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';

void main() {
  late Directory temporary, root, project;
  late FileProjectRepository repository;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('raw-recovery-tests');
    root = await Directory('${temporary.path}/projects').create();
    project = await Directory('${root.path}/broken').create();
    repository = FileProjectRepository(root);
  });
  tearDown(() async => temporary.delete(recursive: true));

  test('raw corrupt/future/preserved/temp bytes round-trip with independent SHA; no original files change', () async {
    final originals = <String, List<int>>{
      'r000000000000.json': [255, 0, 128, 10, 123],
      'r000000000001.json': utf8.encode(
        '{"schemaVersion":99,"engineVersion":99,"unrecognized":[1,2]}',
      ),
      'r000000000001.json.preserved-123': utf8.encode('truncated {"original":'),
      'r000000000002.json.tmp': [],
    };
    for (final entry in originals.entries) {
      await File('${project.path}/${entry.key}').writeAsBytes(entry.value);
    }
    expect((await repository.list()).failures, ['broken']);
    final path = await repository.exportRecoveryData('broken');
    expect(path.endsWith('.drawmusic-recovery.json'), isTrue);
    final bundle =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    expect(bundle['format'], 'drawmusic-raw-recovery');
    expect(bundle['bundleVersion'], 1);
    expect(bundle['projectId'], 'broken');
    expect(
      bundle['totalBytes'],
      originals.values.fold<int>(0, (n, b) => n + b.length),
    );
    final entries = (bundle['files'] as List).cast<Map<String, dynamic>>();
    expect(entries.length, originals.length);
    for (final entry in entries) {
      final name = entry['name'] as String;
      final bytes = base64Decode(entry['contentBase64'] as String);
      expect(bytes, originals[name]);
      expect(entry['bytes'], bytes.length);
      expect(entry['sha256'], sha256.convert(bytes).toString());
      expect(
        await File('${project.path}/$name').readAsBytes(),
        originals[name],
      );
      expect(name.contains('/'), isFalse);
    }
    expect(await File(path).readAsString(), isNot(contains(temporary.path)));
    expect(
      (await Directory(
        '${temporary.path}/recovery-exports',
      ).list().toList()).length,
      1,
    );
    expect((await repository.list()).failures, ['broken']);
  });

  test('path escape, missing/empty projects and symlink entries fail without artifacts', () async {
    await expectLater(
      repository.exportRecoveryData('../outside'),
      throwsFormatException,
    );
    await expectLater(
      repository.exportRecoveryData('missing'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      repository.exportRecoveryData('broken'),
      throwsA(isA<FileSystemException>()),
    );
    final outside = File('${temporary.path}/not-project-secret');
    await outside.writeAsString('private');
    await Link('${project.path}/r000000000000.json').create(outside.path);
    await expectLater(
      repository.exportRecoveryData('broken'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await outside.readAsString(), 'private');
    expect(
      await Directory('${temporary.path}/recovery-exports').exists(),
      isFalse,
    );
  });

  test('unknown files and nested directories are explicit failures, never silently skipped', () async {
    final unsupported = File('${project.path}/unexpected.txt');
    await unsupported.writeAsString('keep');
    await expectLater(
      repository.exportRecoveryData('broken'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await unsupported.readAsString(), 'keep');
    await unsupported.delete();
    await Directory('${project.path}/nested').create();
    await expectLater(
      repository.exportRecoveryData('broken'),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      await Directory('${temporary.path}/recovery-exports').exists(),
      isFalse,
    );
  });

  test(
    '200-file and 64 MiB raw byte limits fail before copying source bytes',
    () async {
      final large = File('${project.path}/r000000000000.json');
      final handle = await large.open(mode: FileMode.write);
      await handle.setPosition(64 * 1024 * 1024);
      await handle.writeByte(1);
      await handle.close();
      await expectLater(
        repository.exportRecoveryData('broken'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await large.length(), 64 * 1024 * 1024 + 1);
      await large.delete();
      for (var i = 0; i < 201; i++) {
        await File('${project.path}/r${i.toString().padLeft(12, '0')}.json')
            .writeAsBytes([]);
      }
      await expectLater(
        repository.exportRecoveryData('broken'),
        throwsA(isA<FileSystemException>()),
      );
      expect((await project.list().toList()).length, 201);
      expect(
        await Directory('${temporary.path}/recovery-exports').exists(),
        isFalse,
      );
    },
  );

  test('destination filesystem failure preserves source and publishes no partial bundle', () async {
    final source = File('${project.path}/r000000000000.json');
    await source.writeAsString('corrupt retained bytes');
    final obstruction = File('${temporary.path}/recovery-exports');
    await obstruction.writeAsString('not a directory');
    await expectLater(
      repository.exportRecoveryData('broken'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await source.readAsString(), 'corrupt retained bytes');
    expect(await obstruction.readAsString(), 'not a directory');
    expect(
      (await temporary.list(recursive: true).toList()).where(
        (f) => f.path.endsWith('.tmp'),
      ),
      isEmpty,
    );
  });
}
