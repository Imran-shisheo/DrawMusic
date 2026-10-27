import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
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
