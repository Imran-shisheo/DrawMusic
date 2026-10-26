import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/export/data/file_image_export_adapter.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export/presentation/export_sheet.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

import 'export_library_test.dart' show RecordingFileActions;

void main() {
  testWidgets(
    'empty PNG requires confirmation and Cancel creates no export job',
    (tester) async {
      final document = ProjectDocument(id: 'empty-png');
      final before = document.encode();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExportSheet(snapshot: document)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Export PNG'));
      await tester.tap(find.text('Export PNG'));
      await tester.pumpAndSettle();
      expect(find.text('Export an empty drawing?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Export an empty drawing?'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Share exported file'), findsNothing);
      expect(document.encode(), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real PNG library thumbnail, Unicode rename, Open/Share/Save and Delete/Undo retain the image',
    (tester) async {
      final setup = await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp('png-ui-');
        final doc = ProjectDocument(id: 'png-ui', title: 'Drawing');
        final artifact = await FileImageExportAdapter(root).exportImage(
          doc,
          ExportCancellation(),
          width: 640,
          transparentBackground: true,
        );
        final library = FileExportLibrary(root);
        await library.record(artifact, doc);
        return (root, artifact, library);
      });
      final (root, artifact, library) = setup!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      final actions = RecordingFileActions();
      final shared = <ExportArtifact>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportLibraryProvider.overrideWith((ref) async => library),
            exportFileActionsProvider.overrideWithValue(actions),
            shareExportProvider.overrideWithValue((artifact, origin) async {
              shared.add(artifact);
              return ShareResultStatus.dismissed;
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExportsPage(),
          ),
        ),
      );
      Future<void> ready(String label) async {
        for (var i = 0; i < 100 && find.text(label).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
      }

      Future<void> menu(String name, String action) async {
        await tester.tap(find.byTooltip('Actions for $name'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await ready(artifact.name);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text(artifact.name));
      await tester.pumpAndSettle();
      expect(actions.opened.single.mime, 'image/png');
      await menu(artifact.name, 'Rename');
      await tester.enterText(find.byType(TextField), '雨の絵');
      await tester.tap(find.text('Apply'));
      await ready('雨の絵.png');
      await menu('雨の絵.png', 'Share');
      expect(shared.single.mime, 'image/png');
      expect(shared.single.name, '雨の絵.png');
      expect(
        find.text('Share sheet dismissed. Export is still saved.'),
        findsOneWidget,
      );
      await menu('雨の絵.png', 'Save a copy');
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(actions.saved.single.mime, 'image/png');
      await menu('雨の絵.png', 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await ready('Undo');
      await tester.tap(find.text('Undo'));
      await ready('雨の絵.png');
      expect(await tester.runAsync(() => File(artifact.path).exists()), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
