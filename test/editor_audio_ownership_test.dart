import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/transport/domain/audio_engine.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

class _OverlappingAudio extends TestAudio {
  _OverlappingAudio({required this.delayPreparation});
  final bool delayPreparation;
  final preparation = Completer<void>();
  final oldStatus = Completer<TransportStatus>();
  int stops = 0, pauses = 0, statusCalls = 0;
  @override
  Future<void> prepare(
    Int16List pcm, {
    int revision = 0,
    int tempo = 120,
  }) async {
    await super.prepare(pcm, revision: revision, tempo: tempo);
    if (delayPreparation && prepares == 1) await preparation.future;
  }

  @override
  Future<TransportStatus> status() async {
    statusCalls++;
    if (!delayPreparation && statusCalls == 1) return oldStatus.future;
    return super.status();
  }

  @override
  Future<void> pause() async {
    pauses++;
    await super.pause();
  }

  @override
  Future<void> stop() async {
    stops++;
    await super.stop();
  }
}

ProjectDocument _drawing(String id) => ProjectDocument(
  id: id,
  strokes: [
    Stroke(
      id: '$id-ink',
      instrument: Instrument.keys,
      points: [InkPoint(.1, .7), InkPoint(.9, .2)],
    ),
  ],
);

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    // Let real rendering/preparation finish without advancing the route's
    // animation clock. The old reverse route must still be alive at handoff.
    await tester.pump();
  }
  expect(condition(), isTrue);
}

void main() {
  for (final latePreparation in [false, true]) {
    testWidgets(
      'rapid Back/reopen keeps new shared-engine session when old ${latePreparation ? 'preparation' : 'poll'} and disposal complete',
      (tester) async {
        final audio = _OverlappingAudio(delayPreparation: latePreparation);
        final first = _drawing('old'), second = _drawing('new');
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/old'),
                  child: const Text('Open'),
                ),
              ),
            ),
            for (final doc in [first, second])
              GoRoute(
                path: '/${doc.id}',
                pageBuilder: (context, state) => CustomTransitionPage<void>(
                  key: state.pageKey,
                  transitionDuration: const Duration(milliseconds: 380),
                  reverseTransitionDuration: const Duration(milliseconds: 260),
                  transitionsBuilder: (context, animation, secondary, child) =>
                      FadeTransition(opacity: animation, child: child),
                  child: ProviderScope(
                    overrides: [initialDocumentProvider.overrideWithValue(doc)],
                    child: const EditorWorkspace(),
                  ),
                ),
              ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWith(
                (ref) async => MemoryRepository(),
              ),
              preferencesStoreProvider.overrideWith(
                (ref) async => MemoryPreferencesStore(),
              ),
              audioEngineProvider.overrideWithValue(audio),
            ],
            child: MaterialApp.router(
              theme: buildTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final oldWorkspace = find.byType(EditorWorkspace);
        final oldState = tester.state(oldWorkspace);
        await tester.tap(find.byTooltip('Play'));
        if (latePreparation) {
          await _until(tester, () => audio.prepares == 1);
        } else {
          await _until(tester, () => audio.playing);
          await tester.pump(const Duration(milliseconds: 60));
          await _until(tester, () => audio.statusCalls == 1);
        }
        await tester.tap(find.byTooltip('Back to gallery'));
        for (
          var i = 0;
          i < 20 && router.routeInformationProvider.value.uri.path != '/';
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(router.routeInformationProvider.value.uri.path, '/');
        await tester.pump(const Duration(milliseconds: 15));
        expect(oldState.mounted, isTrue);
        unawaited(router.push<void>('/new'));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(oldState.mounted, isTrue);
        final newWorkspace = find.byType(EditorWorkspace).last;
        final play = find
            .descendant(of: newWorkspace, matching: find.byTooltip('Play'))
            .hitTestable();
        expect(play, findsOneWidget);
        await tester.tap(play);
        await _until(tester, () => audio.playing && audio.prepares == 2);
        final stops = audio.stops, pauses = audio.pauses;
        if (latePreparation) {
          audio.preparation.complete();
        } else {
          audio.oldStatus.complete(
            const TransportStatus(
              playing: false,
              revision: 0,
              targetRevision: 0,
              fraction: 0,
              tempo: 120,
            ),
          );
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(oldState.mounted, isFalse);
        expect(audio.playing, isTrue);
        expect(
          audio.stops,
          stops,
          reason: 'Old route disposal/preparation cleanup must not stop its successor.',
        );
        expect(
          audio.pauses,
          pauses,
          reason: 'Old poll/completion must not pause its successor.',
        );
        expect(audio.prepares, 2);
        expect(
          audio.plays,
          latePreparation ? 1 : 2,
          reason: 'A stale preparation cannot start another playback session.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
