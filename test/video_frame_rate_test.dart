import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export/presentation/export_sheet.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

void main() {
  test(
    'video FPS metadata survives restart, rename, delete and restore',
    () async {
      final root = await Directory.systemTemp.createTemp('video-fps-metadata');
      try {
        final video = File('${root.path}/actual-video.mp4');
        // Catalog metadata test only; native tests validate real encoded video.
        final bytes = [0, 0, 0, 20, 102, 116, 121, 112, 105, 115, 111, 109];
        await video.writeAsBytes(bytes);
        final document = ProjectDocument(id: 'fps-fixture');
        final artifact = ExportArtifact(
          video.path,
          'video/mp4',
          'Sixty frames.mp4',
          document.id,
          document.revision,
          width: 640,
          height: 800,
          durationSeconds: 5.3,
          framesPerSecond: 60,
        );
        await FileExportLibrary(root).record(artifact, document);
        var entry = (await FileExportLibrary(root).list()).entries.single;
        expect(entry.artifact.framesPerSecond, 60);
        await FileExportLibrary(root).rename(entry.id, 'Renamed sixty');
        entry = (await FileExportLibrary(root).list()).entries.single;
        expect(entry.artifact.framesPerSecond, 60);
        expect(entry.artifact.width, 640);
        expect(entry.artifact.durationSeconds, 5.3);
        await FileExportLibrary(root).remove(entry.id);
        expect((await FileExportLibrary(root).list()).entries, isEmpty);
        await FileExportLibrary(root).restore(entry.id);
        expect(
          (await FileExportLibrary(
            root,
          ).list()).entries.single.artifact.framesPerSecond,
          60,
        );
        expect(await video.readAsBytes(), bytes);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'FPS selector defaults to 30, selects 60 and never mutates document',
    (tester) async {
      final document = ProjectDocument(id: 'fps-ui');
      final before = document.encode();
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExportSheet(snapshot: document)),
          ),
        ),
      );
      final selector = find.byKey(const ValueKey('video-output-fps'));
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(selector).value, 30);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 FPS — smoother, slower export').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(selector).value, 60);
      expect(document.encode(), before);
      expect(tester.takeException(), isNull);
    },
  );
}
