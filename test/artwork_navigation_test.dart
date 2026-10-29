import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/app/artwork_navigation.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/artwork_flight.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

class _DelayedRepository extends MemoryRepository {
  final requests = <Completer<ProjectLoad>>[];
  final openedIds = <String>[];
  @override
  Future<ProjectLoad> open(String id) {
    openedIds.add(id);
    final request = Completer<ProjectLoad>();
    requests.add(request);
    return request.future;
  }
}

ProjectDocument _stored() => ProjectDocument(
  id: 'stored',
  title: 'Actual stored drawing',
  strokes: [
    Stroke(
      id: 'stored-ink',
      instrument: Instrument.guitar,
      points: [InkPoint(.2, .2), InkPoint(.8, .7)],
    ),
  ],
);

class _Harness {
  _Harness() {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TextButton(
                      onPressed: () => context.go('/away'),
                      child: const Text('Leave'),
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 150,
                    child: ArtworkFlightSource(
                      routeId: 'stored',
                      document: preview,
                      artwork: const ColoredBox(color: Colors.orange),
                      onOpen: (intent) {
                        received = intent;
                        return openEditorWithArtworkFlight(
                          context,
                          'stored',
                          intent,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/away',
          builder: (context, state) => const Scaffold(body: Text('Elsewhere')),
        ),
        GoRoute(
          path: '/editor/:id',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            transitionsBuilder: (context, animation, secondary, child) =>
                FadeTransition(opacity: animation, child: child),
            child: EditorPage(
              projectId: state.pathParameters['id']!,
              loadSessionId: state.uri.queryParameters['session'],
              flightIntent: state.extra is ArtworkFlightIntent
                  ? state.extra as ArtworkFlightIntent
                  : null,
            ),
          ),
        ),
      ],
    );
  }
  final preview = ProjectDocument(id: 'preview-only', title: 'Cached preview');
  final repository = _DelayedRepository();
  final audio = TestAudio();
  late final GoRouter router;
  ArtworkFlightIntent? received;
  int engineConstructions = 0;
  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) async => repository),
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(),
          ),
          audioEngineProvider.overrideWith((ref) {
            engineConstructions++;
            return audio;
          }),
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
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(ArtworkFlightSource));
    await tester.pump();
    expect(
      received,
      isNotNull,
      reason: 'This exercises the actual captured-art path.',
    );
    expect(repository.requests, hasLength(1));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );
  testWidgets(
    'delayed real read keeps source interactive, shows honest feedback and mounts first-frame Hero with actual loaded document',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.open(tester);
      expect(harness.router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(EditorWorkspace), findsNothing);
      expect(harness.engineConstructions, 0);
      await tester.pump(const Duration(milliseconds: 149));
      expect(
        find.byKey(const ValueKey('opening-drawing-feedback')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 2));
      expect(
        find.byKey(const ValueKey('opening-drawing-feedback')),
        findsOneWidget,
      );
      final document = _stored();
      harness.repository.requests.single.complete(ProjectLoad(document));
      await tester.pump();
      await tester.pump();
      // No settle/buffer delay: the real destination must have its Hero/canvas
      // available as the route's first animation frame is composed.
      expect(
        find.byKey(const ValueKey('opening-drawing-feedback')),
        findsNothing,
      );
      expect(find.byType(EditorWorkspace), findsOneWidget);
      expect(find.byType(DrawingCanvas), findsOneWidget);
      expect(
        identical(
          tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document,
          document,
        ),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('artwork-flight-shuttle')),
        findsOneWidget,
      );
      expect(harness.repository.openedIds, ['stored']);
      expect(harness.engineConstructions, 1);
      expect(
        harness.received!.cancelled,
        isFalse,
        reason: 'Own route push must not cancel its flight.',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        harness.repository.requests,
        hasLength(1),
        reason: 'Preloaded provider stays alive through route ownership.',
      );
      await harness.close(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navigation through input-transparent feedback cancels late read and observes its eventual error',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.open(tester);
      await tester.pump(const Duration(milliseconds: 151));
      final feedback = tester.getRect(
        find.byKey(const ValueKey('opening-drawing-feedback')),
      );
      expect(feedback.contains(tester.getCenter(find.text('Leave'))), isTrue);
      await tester.tap(find.text('Leave'));
      await tester.pump();
      expect(find.text('Elsewhere'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('opening-drawing-feedback')),
        findsNothing,
      );
      expect(harness.received!.cancelled, isTrue);
      harness.repository.requests.single.completeError(
        StateError('late unreadable file'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EditorPage), findsNothing);
      expect(harness.engineConstructions, 0);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'actual read failure uses existing error route without a flight and Retry reloads the preserved provider',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.open(tester);
      harness.repository.requests.single.completeError(
        StateError('unreadable file'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Drawing unavailable'), findsOneWidget);
      expect(find.byType(EditorWorkspace), findsNothing);
      expect(
        tester.widget<EditorPage>(find.byType(EditorPage)).flightIntent,
        isNull,
      );
      expect(harness.engineConstructions, 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EditorPage)),
        listen: false,
      );
      expect(
        container
            .read(
              editorLoadProvider(
                EditorLoadRequest(
                  projectId: 'stored',
                  sessionId: tester
                      .widget<EditorPage>(find.byType(EditorPage))
                      .loadSessionId!,
                ),
              ),
            )
            .hasError,
        isTrue,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(harness.repository.requests, hasLength(2));
      final document = _stored();
      harness.repository.requests.last.complete(ProjectLoad(document));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DrawingCanvas>(find.byType(DrawingCanvas)).document.id,
        'stored',
      );
      expect(harness.engineConstructions, 1);
      expect(
        find.byKey(const ValueKey('artwork-flight-shuttle')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'backgrounding during real read cancels presentation and prevents a later route push',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.open(tester);
      await tester.pump(const Duration(milliseconds: 151));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(harness.received!.cancelled, isTrue);
      expect(
        find.byKey(const ValueKey('opening-drawing-feedback')),
        findsNothing,
      );
      harness.repository.requests.single.complete(ProjectLoad(_stored()));
      await tester.pump();
      expect(find.byType(EditorPage), findsNothing);
      expect(harness.engineConstructions, 0);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );
  testWidgets(
    'rapid New callbacks stack one editor and pop/reopen during reverse creates a distinct real document',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      final context = tester.element(find.byType(ArtworkFlightSource));
      final firstOpen = openEditorWithArtworkFlight(context, 'new', null);
      await openEditorWithArtworkFlight(context, 'new', null);
      await tester.pumpAndSettle();
      expect(find.byType(EditorWorkspace, skipOffstage: false), findsOneWidget);
      final firstPage = tester.widget<EditorPage>(find.byType(EditorPage));
      final firstState = tester.state(find.byType(EditorWorkspace));
      final canvas = find.byType(DrawingCanvas);
      final firstId = tester.widget<DrawingCanvas>(canvas).document.id;
      expect(firstId, isNot('new'));
      expect(firstPage.loadSessionId, isNotNull);
      await tester.tap(find.byKey(const ValueKey('drawing-canvas')));
      await tester.pump();
      await tester.tap(find.byTooltip('Back to gallery'));
      for (var i = 0; i < 20 && harness.router.canPop(); i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(harness.router.canPop(), isFalse);
      await tester.pump(const Duration(milliseconds: 15));
      expect(firstState.mounted, isTrue);
      await firstOpen;
      final saved = harness.repository.documents[firstId]!;
      expect(saved.strokes, hasLength(1));
      final savedBytes = saved.encode();
      final newContext = tester.element(find.byType(ArtworkFlightSource));
      final secondOpen = openEditorWithArtworkFlight(
        newContext,
        'new',
        null,
        replayTips: true,
      );
      await openEditorWithArtworkFlight(newContext, 'new', null);
      await tester.pump();
      await tester.pump();
      expect(firstState.mounted, isTrue);
      final newWorkspace = find.byType(EditorWorkspace).last;
      final secondCanvas = find.descendant(
        of: newWorkspace,
        matching: find.byType(DrawingCanvas),
      );
      final secondDocument = tester
          .widget<DrawingCanvas>(secondCanvas)
          .document;
      final secondPage = tester.widget<EditorPage>(
        find.byType(EditorPage).last,
      );
      expect(secondDocument.id, isNot(firstId));
      expect(secondDocument.strokes, isEmpty);
      expect(secondPage.projectId, 'new');
      expect(secondPage.loadSessionId, isNot(firstPage.loadSessionId));
      expect(
        GoRouterState.of(tester.element(find.byType(EditorPage).last))
            .uri
            .queryParameters['tips'],
        '1',
      );
      expect(harness.repository.documents[firstId]!.encode(), savedBytes);
      expect(harness.engineConstructions, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EditorWorkspace, skipOffstage: false), findsOneWidget);
      await tester.tap(find.byTooltip('Back to gallery'));
      await tester.pumpAndSettle();
      await secondOpen;
      expect(harness.repository.documents[firstId]!.encode(), savedBytes);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'rapid saved-document reopen reads the actual newly saved revision while old load remains watched during reverse',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.open(tester);
      harness.repository.requests.single.complete(ProjectLoad(_stored()));
      await tester.pumpAndSettle();
      final firstPage = tester.widget<EditorPage>(find.byType(EditorPage));
      final oldState = tester.state(find.byType(EditorWorkspace));
      await tester.tap(find.byKey(const ValueKey('drawing-canvas')));
      await tester.pump();
      await tester.tap(find.byTooltip('Back to gallery'));
      for (var i = 0; i < 20 && harness.router.canPop(); i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(harness.router.canPop(), isFalse);
      await tester.pump(const Duration(milliseconds: 15));
      expect(oldState.mounted, isTrue);
      final saved = harness.repository.documents['stored']!;
      expect(saved.strokes, hasLength(2));
      expect(saved.revision, greaterThan(_stored().revision));
      await tester.tap(find.byType(ArtworkFlightSource));
      await tester.pump();
      expect(
        harness.repository.requests,
        hasLength(2),
        reason: 'A new navigation cannot reuse the still-watched old initial snapshot.',
      );
      harness.repository.requests.last.complete(ProjectLoad(saved));
      await tester.pump();
      await tester.pump();
      expect(oldState.mounted, isTrue);
      final newWorkspace = find.byType(EditorWorkspace).last;
      final currentCanvas = tester.widget<DrawingCanvas>(
        find.descendant(of: newWorkspace, matching: find.byType(DrawingCanvas)),
      );
      expect(currentCanvas.document.encode(), saved.encode());
      expect(
        tester.widget<EditorPage>(find.byType(EditorPage).last).loadSessionId,
        isNot(firstPage.loadSessionId),
      );
      expect(harness.repository.openedIds, ['stored', 'stored']);
      expect(harness.engineConstructions, 1);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Back to gallery'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );
}
