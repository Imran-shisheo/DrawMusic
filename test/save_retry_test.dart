import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

class CountingRepository extends MemoryRepository {
  int attempts = 0;
  @override
  Future<void> save(ProjectDocument document) async {
    attempts++;
    await super.save(document);
  }
}

void main() {
  testWidgets('failed first autosave waits for user retry instead of looping', (
    tester,
  ) async {
    final repository = CountingRepository()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialDocumentProvider.overrideWithValue(
            ProjectDocument(id: 'save-retry'),
          ),
          repositoryProvider.overrideWith((ref) async => repository),
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(),
          ),
          audioEngineProvider.overrideWithValue(TestAudio()),
        ],
        child: const MaterialApp(home: EditorWorkspace()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('drawing-canvas')),
      const Offset(60, 30),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(repository.attempts, 1);
    expect(find.textContaining('Could not save this drawing'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(repository.attempts, 1);
    repository.fail = false;
    await tester.tap(find.byTooltip('Save drawing'));
    await tester.pumpAndSettle();
    expect(repository.attempts, 2);
    expect(
      repository.documents['save-retry']!.strokes.single.points,
      isNotEmpty,
    );
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
