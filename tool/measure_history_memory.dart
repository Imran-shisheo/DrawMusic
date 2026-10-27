import 'dart:convert';
import 'dart:io';

import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/domain/history.dart';

// Diagnostic only: desktop Dart VM/process observations, not a physical Android
// memory/FPS or retained-heap certification. Run with the pinned Dart SDK.
void main() {
  final baseline = ProcessInfo.currentRss;
  final history = DocumentHistory(ProjectDocument(id: 'memory-diagnostic'));
  final samples = <Map<String, int>>[];
  for (var revision = 0; revision < 8; revision++) {
    final watch = Stopwatch()..start();
    history.commit(
      history.document.copyWith(
        strokes: [
          Stroke(
            id: 'scene-$revision',
            instrument: Instrument.keys,
            points: List.generate(
              100000,
              (i) => InkPoint(i / 99999, .1 + revision * .1),
            ),
          ),
        ],
      ),
    );
    watch.stop();
    final memory = history.memory;
    if (memory.retainedBytes > history.maxHistoryBytes) {
      throw StateError('History accounting budget exceeded');
    }
    samples.add({
      'revision': revision,
      'undoCommands': history.undoCount,
      'redoCommands': history.redoCount,
      'currentDocumentAccountedBytes': memory.currentDocumentBytes,
      'historyAccountedBytes': memory.retainedBytes,
      'commitMicroseconds': watch.elapsedMicroseconds,
      'processRssBytes': ProcessInfo.currentRss,
      'processPeakRssBytes': ProcessInfo.maxRss,
    });
  }
  for (var i = 0; i < 2; i++) {
    history.undo();
  }
  final afterUndo = history.memory;
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'scope': 'Linux Dart VM diagnostic; RSS includes VM, working document, temporary ledger sets and unreclaimed garbage',
      'dartVersion': Platform.version,
      'baselineProcessRssBytes': baseline,
      'maxAdditionalHistoryAccountedBytes': history.maxHistoryBytes,
      'samples': samples,
      'afterUndo': {
        'undoCommands': history.undoCount,
        'redoCommands': history.redoCount,
        'historyAccountedBytes': afterUndo.retainedBytes,
        'currentDocumentPoints': history.document.pointCount,
      },
    }),
  );
}
