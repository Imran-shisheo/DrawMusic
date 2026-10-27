import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/library/domain/recovery_export_port.dart';
import 'package:scribblesong/features/library/presentation/drafts.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

import 'widget_test.dart' show MemoryRepository;

class _Repository extends MemoryRepository implements RecoveryExportPort {
  final calls = <String>[];
  bool exportFails = false;
  @override
  Future<String> exportRecoveryData(String projectId) async {
    calls.add(projectId);
    if (exportFails) {
      throw const FormatException('Private diagnostic must not show');
    }
    return '/app-private/recovered.drawmusic-recovery.json';
  }
}

void main() {
  testWidgets(
    'damaged draft exports only after explicit tap and handles every sharing result honestly',
    (tester) async {
      final repository = _Repository();
      final shared = <String>[];
      var result = ShareResultStatus.dismissed;
      Rect? anchor;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repository),
            libraryProvider.overrideWith(
              (ref) async => const ProjectListing([], ['damaged']),
            ),
            shareRecoveryDataProvider.overrideWithValue((path, origin) async {
              shared.add(path);
              anchor = origin;
              return result;
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DraftsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      expect(shared, isEmpty);
      Future<void> export() async {
        await tester.tap(find.text('Export recovery data'));
        await tester.pumpAndSettle();
      }

      await export();
      expect(repository.calls, ['damaged']);
      expect(shared, ['/app-private/recovered.drawmusic-recovery.json']);
      expect(anchor, isNotNull);
      // Check the actual localized result rather than inventing platform delivery.
      final context = tester.element(find.byType(DraftsPage));
      final strings = AppLocalizations.of(context)!;
      expect(find.text(strings.shareDismissed), findsOneWidget);
      result = ShareResultStatus.unavailable;
      await export();
      expect(find.text(strings.shareUnavailable), findsOneWidget);
      result = ShareResultStatus.success;
      await export();
      expect(find.text(strings.shareClosed), findsOneWidget);
      repository.exportFails = true;
      await export();
      expect(find.text(strings.recoveryExportFailed), findsOneWidget);
      expect(find.textContaining('Private diagnostic'), findsNothing);
      expect(shared.length, 3);
    },
  );
}
