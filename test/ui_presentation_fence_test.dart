import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/ui_presentation_fence.dart';

FrameTiming raster(int number) => FrameTiming(
  vsyncStart: 100,
  buildStart: 110,
  buildFinish: 120,
  rasterStart: 130,
  rasterFinish: 200,
  rasterFinishWallTime: 10000,
  frameNumber: number,
);

class _DiagnosticNonlinearScaler extends TextScaler {
  const _DiagnosticNonlinearScaler();
  @override
  double get textScaleFactor => 2;
  @override
  double scale(double fontSize) => fontSize + 4;
}

void main() {
  testWidgets(
    'product imperative editor route differs from URL; hidden outgoing and modal canvases reject',
    (tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MemoryRepository();
      await repo.save(ProjectDocument(id: 'route-proof', title: 'Route proof'));
      await repo.save(ProjectDocument(id: 'other-route', title: 'Other route'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(reduceMotion: false),
              ),
            ),
            repositoryProvider.overrideWith((ref) async => repo),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      Future<void> frames() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await frames();
      final homeContext = tester.element(find.byType(HomePage));
      final router = GoRouter.of(homeContext);
      expect(GoRouter.optionURLReflectsImperativeAPIs, isFalse);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      // Use the production buildRouter mounted by ScribbleSongApp. The same
      // context.push API opens templates; no routing mock or URL override.
      homeContext.push('/editor/route-proof');
      await frames();
      final canvas = find.byKey(const ValueKey('drawing-canvas'));
      expect(canvas, findsOneWidget);
      final firstContext = tester.element(canvas);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(GoRouterState.of(firstContext).uri.path, '/editor/route-proof');
      expect(uiRenderedEditorAnchor(firstContext, hasPanel: false), isTrue);
      showDialog<void>(
        context: firstContext,
        builder: (_) => const AlertDialog(title: Text('Blocking route')),
      );
      await frames();
      expect(uiRenderedEditorAnchor(firstContext, hasPanel: true), isFalse);
      expect(
        uiRenderedEditorAnchor(firstContext, hasPanel: false),
        isFalse,
        reason: 'Actual canvas ModalRoute is not current below a root modal',
      );
      Navigator.of(firstContext, rootNavigator: true).pop();
      await frames();
      expect(uiRenderedEditorAnchor(firstContext, hasPanel: false), isTrue);
      firstContext.push('/editor/other-route');
      await frames();
      expect(
        uiRenderedEditorAnchor(firstContext, hasPanel: false),
        isFalse,
        reason: 'The retained hidden editor cannot qualify a screenshot',
      );
      final secondContext = tester.element(canvas);
      expect(GoRouterState.of(secondContext).uri.path, '/editor/other-route');
      expect(uiRenderedEditorAnchor(secondContext, hasPanel: false), isTrue);
      final outgoingRoute = ModalRoute.of(secondContext)!;
      router.pop();
      await tester.pump();
      expect(outgoingRoute.isCurrent, isFalse);
      expect(
        find.byElementPredicate((element) => identical(element, secondContext)),
        findsOneWidget,
        reason: 'A real reverse transition retains the outgoing canvas until its exit completes',
      );
      expect(
        find.byElementPredicate(
          (element) =>
              identical(element, secondContext) &&
              uiRenderedEditorAnchor(element, hasPanel: false),
        ),
        findsNothing,
        reason: 'The mounted outgoing canvas must not qualify as a current screenshot anchor',
      );
      await frames();
      expect(
        find.byElementPredicate((element) => identical(element, secondContext)),
        findsNothing,
        reason: 'The outgoing canvas is disposed after its finite reverse transition; never look up deactivated ancestors',
      );
      expect(uiRenderedEditorAnchor(firstContext, hasPanel: false), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  UiImeOcclusionWitness ime({
    double fieldBottom = 500,
    double cancelBottom = 550,
    bool hit = true,
    bool mock = false,
  }) => UiImeOcclusionWitness(
    physicalHeight: 2400,
    physicalInset: 900,
    dpr: 2.5,
    field: Rect.fromLTRB(20, 300, 380, fieldBottom),
    cancel: Rect.fromLTRB(20, 510, 120, cancelBottom),
    focused: true,
    cancelHitTestable: hit,
    mockInputRegistered: mock,
  );
  test('native inset alone is insufficient until actual field and Cancel layout fit', () {
    expect(ime(fieldBottom: 802).ready, isFalse);
    expect(ime(cancelBottom: 700).ready, isFalse);
    expect(ime(hit: false).ready, isFalse);
    expect(ime().ready, isTrue);
    expect(ime().visibleBottom, 600);
  });
  test(
    'diagnostic geometry preserves occlusion and never accepts mock keyboard',
    () {
      expect(ime(mock: true).ready, isFalse);
      final diagnostic = ime(fieldBottom: 802).toJson();
      expect(diagnostic['ready'], isFalse);
      expect(diagnostic['physicalInset'], 900);
      expect(diagnostic['fieldBounds'], [20, 300, 360, 502]);
    },
  );
  test(
    'native nominal200 accepts nonlinear font sizes without linear assumptions',
    () {
      final witness = UiTextScaleWitness(
        scaler: const _DiagnosticNonlinearScaler(),
        platformNominal: 2,
      );
      expect(witness.matches(2), isTrue);
      expect(witness.scaledFonts['10'], 14);
      expect(witness.scaledFonts['42'], 46);
      expect(witness.toJson()['mediaQuerySnapshotNominalTextScaleFactor'], 2);
    },
  );
  test(
    'stale platform or widget snapshot cannot qualify requested native scale',
    () {
      expect(
        UiTextScaleWitness(
          scaler: TextScaler.noScaling,
          platformNominal: 2,
        ).matches(2),
        isFalse,
      );
      expect(
        UiTextScaleWitness(
          scaler: const _DiagnosticNonlinearScaler(),
          platformNominal: 1,
        ).matches(2),
        isFalse,
      );
      expect(
        UiTextScaleWitness(
          scaler: TextScaler.noScaling,
          platformNominal: 1,
        ).matches(1),
        isTrue,
      );
    },
  );
  test('stale queued raster cannot qualify the new expected sheet', () {
    final ledger = UiRasterEvidenceLedger();
    ledger.rasterFrames([raster(1)]);
    ledger.frameworkFrame(number: 2, expected: true, systemTimestampUs: 9999);
    expect(ledger.evidence(), isNull);
    ledger.rasterFrames([raster(2)]);
    expect(ledger.evidence()!['matchedEngineFrameNumber'], 2);
    // The raw system-frame timestamp deliberately differs from vsyncStart:
    // identity, not an assumed clock equality, is the join.
  });

  test('delayed/out-of-order batches match only exact witnessed frame IDs', () {
    final ledger = UiRasterEvidenceLedger();
    ledger.rasterFrames([raster(8), raster(6)]);
    ledger.frameworkFrame(number: 7, expected: true, systemTimestampUs: 2000);
    expect(ledger.evidence(), isNull);
    ledger.rasterFrames([raster(7)]);
    expect(ledger.evidence()!['matchedEngineFrameNumber'], 7);
  });

  test('rapid route change invalidates an older expected-state witness', () {
    final ledger = UiRasterEvidenceLedger();
    ledger.frameworkFrame(number: 1, expected: true, systemTimestampUs: 1000);
    ledger.frameworkFrame(number: 2, expected: false, systemTimestampUs: 2000);
    ledger.rasterFrames([raster(1)]);
    expect(ledger.evidence(), isNull);
    ledger.frameworkFrame(number: 3, expected: true, systemTimestampUs: 3000);
    expect(ledger.evidence(), isNull);
    ledger.rasterFrames([raster(3)]);
    expect(ledger.evidence()!['matchedEngineFrameNumber'], 3);
  });

  test('unknown IDs and reset never fabricate raster proof', () {
    final ledger = UiRasterEvidenceLedger();
    ledger.frameworkFrame(number: -1, expected: true, systemTimestampUs: 1000);
    ledger.rasterFrames([raster(-1)]);
    expect(ledger.evidence(), isNull);
    ledger.frameworkFrame(number: 1, expected: true, systemTimestampUs: 1000);
    ledger.rasterFrames([raster(1)]);
    expect(ledger.evidence(), isNotNull);
    ledger.reset();
    expect(ledger.evidence(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets('static screenshot fence works with reducedMotion=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const SizedBox(key: ValueKey('target'), width: 40, height: 40),
        ),
      );
      var number = 1;
      final fence = UiPresentationFence(
        tester.binding,
        isExpected: () =>
            find.byKey(const ValueKey('target')).evaluate().isNotEmpty,
        frameNumberForTests: () => number++,
        screenshotSnapshot: () => {'nominal': 2, 'frameWitness': number - 1},
      )..start();
      // Exactly one deliberate screenshot-only frame; no artificial idle loop.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(fence.frameworkWitnessCount, 1);
      // Synthetic raster delivery tests matching/scheduling only. This does
      // not establish native compositor or Android screenshot correctness.
      fence.ledger.rasterFrames([raster(1)]);
      final result = await fence.waitForRaster();
      expect(result['matchedEngineFrameNumber'], 1);
      expect(result['matchedFrameworkSnapshot'], {
        'nominal': 2,
        'frameWitness': 1,
      });
      fence.stop();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await expectLater(
        fence.waitForRaster(),
        throwsA(isA<TimeoutException>()),
      );
    });
  }
}
