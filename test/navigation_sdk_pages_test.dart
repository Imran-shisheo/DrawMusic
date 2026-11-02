import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/artwork_flight.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/design_system/motion.dart';
import 'package:scribblesong/features/library/presentation/drafts.dart';
import 'package:scribblesong/features/export_library/presentation/exports_page.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';
import 'package:scribblesong/features/settings/presentation/language_page.dart';
import 'package:scribblesong/features/onboarding/presentation/tutorial.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'widget_test.dart' show MemoryRepository, TestAudio;
import 'support/memory_preferences.dart';

void main() {
  testWidgets(
    'actual Home warm editor Back tabs and recorded-style reopen retains fresh flight',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      tester.view.physicalSize = const Size(411, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryRepository();
      repository.documents['capture-morning'] = ProjectDocument(
        id: 'capture-morning',
        title: 'Morning tide',
        strokes: [
          Stroke(
            id: 'owned-stroke',
            instrument: Instrument.guitar,
            points: [InkPoint(.2, .3), InkPoint(.8, .7)],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repository),
            exportListingProvider.overrideWith(
              (ref) async => const ExportListing([]),
            ),
            audioEngineProvider.overrideWithValue(TestAudio()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(
                  tutorialCompleted: true,
                  editorTipsCompleted: true,
                ),
              ),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      Finder key(String name) => find.byKey(ValueKey(name));
      Future<void> tapKey(String name) async {
        final target = name == 'editor-back'
            ? find.byTooltip('Back to gallery')
            : key(name);
        await tester.ensureVisible(target.first);
        await tester.tap(target.hitTestable().last);
        await tester.pumpAndSettle();
      }

      // Same warm source→editor→Back prerequisite as the unrecorded benchmark.
      await tapKey('nav-library');
      for (final name in ['Exports', 'Drafts', 'Exports', 'Drafts']) {
        await tester.tap(find.text(name).hitTestable().last);
        await tester.pumpAndSettle();
      }
      await tapKey('nav-home');
      await tapKey('home-artwork');
      final firstRoute = GoRouterState.of(
        tester.element(key('drawing-canvas')),
      );
      final firstSession = firstRoute.uri.queryParameters['session'];
      final first = firstRoute.extra as ArtworkFlightIntent?;
      expect(first, isNotNull);
      await tapKey('editor-back');
      // Same subsequent retained branches; real app layouts/controllers retained.
      await tapKey('nav-library');
      for (final name in ['Exports', 'Drafts', 'Exports', 'Drafts']) {
        await tester.tap(find.text(name).hitTestable().last);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.tap(
          find.text(i.isEven ? 'Exports' : 'Drafts').hitTestable().last,
        );
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pumpAndSettle();
      await tapKey('nav-settings');
      await tapKey('nav-home');
      await tapKey('nav-library');
      await tester.tap(find.text('Exports').hitTestable().last);
      await tester.pumpAndSettle();
      await tapKey('nav-settings');
      await tapKey('nav-home');
      var active = true;
      addTearDown(() => active = false);
      final samples = <({bool canvas, bool shuttle})>[];
      void observe(Duration _) {
        if (!active) return;
        samples.add((
          canvas: key('drawing-canvas').hitTestable().evaluate().isNotEmpty,
          shuttle: key('artwork-flight-shuttle').evaluate().isNotEmpty,
        ));
        tester.binding.addPostFrameCallback(observe);
      }

      tester.binding.addPostFrameCallback(observe);
      await tester.tap(key('home-artwork').hitTestable().last);
      var pointerExercised = false;
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (!pointerExercised &&
            key('drawing-canvas').hitTestable().evaluate().isNotEmpty &&
            key('artwork-flight-shuttle').evaluate().isNotEmpty) {
          final live = key('drawing-canvas').hitTestable().first;
          final rectangle = tester.getRect(live);
          final state = tester.state(find.byType(DrawingCanvas));
          final intent =
              GoRouterState.of(tester.element(live)).extra
                  as ArtworkFlightIntent;
          expect(intent.cancelled, isFalse);
          final gesture = await tester.startGesture(rectangle.center);
          expect(intent.cancelled, isTrue);
          for (var step = 1; step <= 4; step++) {
            await gesture.moveTo(
              rectangle.center + Offset(step * 4, -step * 3),
            );
            await tester.pump(const Duration(milliseconds: 20));
            expect(tester.getRect(live), rectangle);
            expect(
              identical(tester.state(find.byType(DrawingCanvas)), state),
              isTrue,
            );
          }
          await gesture.up();
          await tester.pump(const Duration(milliseconds: 150));
          expect(tester.getRect(live), rectangle);
          pointerExercised = true;
        }
      }
      expect(pointerExercised, isTrue);
      active = false;
      final canvas = key('drawing-canvas').hitTestable();
      expect(canvas, findsOneWidget);
      final second =
          GoRouterState.of(tester.element(canvas)).extra
              as ArtworkFlightIntent?;
      expect(second, isNotNull);
      expect(identical(first, second), isFalse);
      final reopenedRoute = GoRouterState.of(tester.element(canvas));
      expect(reopenedRoute.pathParameters['id'], 'capture-morning');
      expect(reopenedRoute.uri.queryParameters['session'], isNot(firstSession));
      expect(
        tester.widget<EditorPage>(find.byType(EditorPage)).loadSessionId,
        reopenedRoute.uri.queryParameters['session'],
      );
      expect(second!.cancelled, isTrue);
      expectSdkPage(tester, canvas);
      expect(samples.any((value) => value.canvas && value.shuttle), isTrue);
      expect(key('artwork-flight-shuttle'), findsNothing);
      // A finite flight was observed, yet a delayed current-state poll cannot see
      // it now. This is not proof that the emulator suffered the same delay.

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'every app route uses SDK pages and exact metadata without losing branches',
    (tester) async {
      await mountRoutes(tester);
      final homeState = tester.state(find.byType(HomePage));
      expectSdkPage(tester, find.byType(HomePage));
      expectSdkPage(
        tester,
        find.byKey(const ValueKey('nav-home')),
      ); // Root shell page.
      Future<void> tab(String key) async {
        await tester.tap(find.byKey(ValueKey(key)).hitTestable().last);
        await tester.pumpAndSettle();
      }

      await tab('nav-library');
      expectSdkPage(tester, find.byType(DraftsPage));
      await tester.tap(find.text('Exports').hitTestable().last);
      await tester.pumpAndSettle();
      expectSdkPage(tester, find.byType(ExportsPage));
      await tab('nav-settings');
      expectSdkPage(tester, find.byType(SettingsPage));
      await tab('nav-library');
      expectSdkPage(
        tester,
        find.byType(ExportsPage),
      ); // Retained section selection.
      await tab('nav-home');
      expect(identical(tester.state(find.byType(HomePage)), homeState), isTrue);
      final router = GoRouter.of(tester.element(find.byType(HomePage)));
      for (final entry in <(String, Type)>[
        ('/language', LanguagePage),
        ('/help', TutorialPage),
      ]) {
        unawaited(router.push<void>('${entry.$1}?from=route-regression'));
        await tester.pumpAndSettle();
        final target = find.byType(entry.$2);
        final route = expectSdkPage(tester, target);
        final context = tester.element(target);
        const child = SizedBox(key: ValueKey('route-transition-child'));
        final transition = Theme.of(context)
            .pageTransitionsTheme
            .builders[Theme.of(context).platform]!
            .buildTransitions<void>(
              route as PageRoute<void>,
              context,
              const AlwaysStoppedAnimation(.25),
              const AlwaysStoppedAnimation(0),
              child,
            );
        expect(transition, isA<FadeTransition>());
        expect((route.settings as MaterialPage<void>).arguments, {
          'from': 'route-regression',
        });
        router.pop();
        await tester.pumpAndSettle();
        expect(
          identical(tester.state(find.byType(HomePage)), homeState),
          isTrue,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion keeps SDK page metadata and stationary usable content',
    (tester) async {
      await mountRoutes(tester, reduce: true);
      final router = GoRouter.of(tester.element(find.byType(HomePage)));
      unawaited(router.push<void>('/language?from=reduced-regression'));
      await tester.pump();
      await tester.pump();
      final target = find.byType(LanguagePage);
      final route = expectSdkPage(tester, target);
      final context = tester.element(target);
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      const child = SizedBox(key: ValueKey('reduced-route-child'));
      expect(
        identical(
          Theme.of(context)
              .pageTransitionsTheme
              .builders[Theme.of(context).platform]!
              .buildTransitions<void>(
                route as PageRoute<void>,
                context,
                const AlwaysStoppedAnimation(.25),
                const AlwaysStoppedAnimation(0),
                child,
              ),
          child,
        ),
        isTrue,
      );
      final rectangle = tester.getRect(target);
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(tester.getRect(target), rectangle);
      }
      expect(
        find.byKey(const ValueKey('artwork-flight-shuttle')),
        findsNothing,
      );
      router.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> mountRoutes(WidgetTester tester, {bool reduce = false}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures();
  tester.view.physicalSize = const Size(411, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWith((ref) async => MemoryRepository()),
        exportListingProvider.overrideWith(
          (ref) async => const ExportListing([]),
        ),
        audioEngineProvider.overrideWithValue(TestAudio()),
        preferencesStoreProvider.overrideWith(
          (ref) async => MemoryPreferencesStore(
            UserPreferences(
              tutorialCompleted: true,
              editorTipsCompleted: true,
              reduceMotion: reduce,
            ),
          ),
        ),
      ],
      child: const ScribbleSongApp(),
    ),
  );
  await tester.pumpAndSettle();
}

PageRoute<dynamic> expectSdkPage(WidgetTester tester, Finder finder) {
  final context = tester.element(finder.first);
  final route = ModalRoute.of(context)! as PageRoute<dynamic>;
  final state = GoRouterState.of(context);
  expect(route.settings, isA<MaterialPage<void>>());
  final page = route.settings as MaterialPage<void>;
  expect(page.key, state.pageKey);
  expect(page.name, state.name ?? state.path);
  expect(page.arguments, <String, String>{
    ...state.pathParameters,
    ...state.uri.queryParameters,
  });
  expect(page.restorationId, state.pageKey.value);
  expect(route.transitionDuration, CreativeMotion.forward);
  expect(route.reverseTransitionDuration, CreativeMotion.reverse);
  return route;
}
