// Linux cloud diagnostic. Kills only the child process this probe starts, using
// an isolated temporary project directory. It never controls a device/app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/library/data/file_project_repository.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.firstOrNull == '--writer') {
    final root = Directory(arguments[1]);
    final document = ProjectDocument(
      id: 'drawing',
      title: 'Candidate',
      revision: 1,
      strokes: List.generate(
        100,
        (s) => Stroke(
          id: 'mark_$s',
          instrument: Instrument.values[s % 3],
          points: List.generate(1000, (p) => InkPoint(p / 999, s / 100, p * 2)),
        ),
      ),
    );
    await FileProjectRepository(root).save(document);
    return;
  }
  if (!Platform.isLinux ||
      arguments.length != 2 ||
      arguments[0] != '--report') {
    stderr.writeln(
      'Compile this diagnostic to an executable, then run it on Linux with --report <path>.',
    );
    exitCode = 2;
    return;
  }
  // Re-executing a compiled binary avoids per-attempt compiler processes.
  if (Platform.script.path.endsWith('.dart') ||
      Platform.script.path.endsWith('.dill')) {
    stderr.writeln(
      'Use dart compile exe tool/crash_recovery_probe.dart first.',
    );
    exitCode = 2;
    return;
  }
  final attempts = <Map<String, Object>>[];
  var interrupted = 0;
  for (var run = 0; run < 12; run++) {
    final root = await Directory.systemTemp.createTemp(
      'drawmusic-owned-crash-',
    );
    Process? child;
    var childExited = false;
    StreamSubscription<FileSystemEvent>? watch;
    try {
      final repository = FileProjectRepository(root);
      final baseline = ProjectDocument(
        id: 'drawing',
        title: 'Baseline',
        background: 0x80f3eef9,
        style: DrawingStyle.pixel,
        strokes: [
          Stroke(
            id: 'original',
            instrument: Instrument.bell,
            points: [InkPoint(.1, .3), InkPoint(.8, .6)],
          ),
        ],
      );
      await repository.save(baseline);
      final original = File('${root.path}/drawing/r000000000000.json');
      final before = await original.readAsString();
      var observed = false, killed = false;
      watch = Directory('${root.path}/drawing')
          .watch(events: FileSystemEvent.create)
          .listen((event) {
            if (!observed && event.path.endsWith('/r000000000001.json.tmp')) {
              observed = true;
              killed = child?.kill(ProcessSignal.sigkill) ?? false;
            }
          });
      child = await Process.start(Platform.resolvedExecutable, [
        '--writer',
        root.path,
      ]);
      final output = child.stdout.transform(utf8.decoder).join();
      final errors = child.stderr.transform(utf8.decoder).join();
      final result = await child.exitCode.timeout(const Duration(seconds: 15));
      childExited = true;
      final messages = '${await output}${await errors}';
      if (!observed || !killed || result != -9) {
        throw StateError(
          'Did not interrupt the owned writer at the temporary-file window: $result $messages',
        );
      }
      await watch.cancel();
      watch = null;
      final pending = File('${root.path}/drawing/r000000000001.json.tmp');
      final published = File('${root.path}/drawing/r000000000001.json');
      final hasPublished = await published.exists();
      final reopened = await FileProjectRepository(root).open('drawing');
      if (await original.readAsString() != before) {
        throw StateError('Published baseline changed');
      }
      if (!hasPublished) {
        interrupted++;
        if (reopened.document.encode() != baseline.encode()) {
          throw StateError('Baseline did not recover exactly');
        }
      } else {
        if (reopened.recovered ||
            reopened.document.revision != 1 ||
            reopened.document.title != 'Candidate' ||
            reopened.document.pointCount != 100000) {
          throw StateError('Incomplete candidate was published');
        }
      }
      final retry = baseline.copyWith(
        title: 'Retry after interruption',
        revision: 2,
      );
      await FileProjectRepository(root).save(retry);
      if ((await FileProjectRepository(root).load('drawing')).encode() !=
          retry.encode()) {
        throw StateError('Saving after recovery did not reopen exactly');
      }
      attempts.add({
        'attempt': run + 1,
        'exit_code': result,
        'temporary_creation_observed': observed,
        'published_candidate': hasPublished,
        'temporary_bytes': await pending.exists() ? await pending.length() : 0,
        'reopened_revision': reopened.document.revision,
        'baseline_bytes_preserved': true,
        'retry_saved_and_reopened': true,
      });
    } finally {
      await watch?.cancel();
      // This handle belongs to this attempt only. No PID/name scans or broad kills.
      if (child != null && !childExited) {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode.timeout(const Duration(seconds: 2));
      }
      await root.delete(recursive: true);
    }
  }
  if (interrupted == 0) {
    throw StateError('No pre-publication window was exercised');
  }
  final report = {
    'platform': Platform.operatingSystem,
    'dart': Platform.version.split(' ').first,
    'scope': 'Linux process interruption during real FileProjectRepository writes; not Android force-stop, disk-full or power-loss acceptance',
    'attempts': attempts,
    'interrupted_before_publication': interrupted,
    'all_recovered': true,
  };
  final destination = File(arguments[1]);
  await destination.parent.create(recursive: true);
  await destination.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Process recovery: ${attempts.length} owned writers interrupted; $interrupted before publication; all drafts recovered.',
  );
}
