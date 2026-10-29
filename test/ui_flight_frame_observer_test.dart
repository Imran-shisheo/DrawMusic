import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/ui_flight_frame_observer.dart';

void main() {
  testWidgets(
    'observes a one-frame transient before it disappears without scheduling frames',
    (tester) async {
      var stage = 'home';
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.hasScheduledFrame, isFalse);
      final observer = UiFlightFrameObserver(
        tester.binding,
        () => {'stage': stage},
      );
      observer.start();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.scheduleFrame(); // The fixture, never the observer, schedules frames.
      await tester.pump();
      stage = 'canvas-and-shuttle';
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
      stage = 'settled-canvas';
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
      final report = observer.stop();
      final samples = report['samples']! as List<Map<String, Object?>>;
      expect(samples.map((sample) => sample['stage']), [
        'home',
        'canvas-and-shuttle',
        'settled-canvas',
      ]);
      expect(report['naturalFramesObserved'], 3);
      expect(report['acceptanceEligible'], isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      stage = 'later-route';
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
      expect(observer.stop()['naturalFramesObserved'], 3);
    },
  );

  testWidgets(
    'bounds changed-state evidence while retaining first and last actual frames',
    (tester) async {
      var stage = 0;
      final observer = UiFlightFrameObserver(
        tester.binding,
        () => {'stage': stage},
      );
      observer.start();
      for (stage = 0; stage < 100; stage++) {
        tester.binding.scheduleFrame();
        await tester.pump(const Duration(milliseconds: 16));
      }
      final report = observer.stop();
      final samples = report['samples']! as List<Map<String, Object?>>;
      expect(samples, hasLength(80));
      expect(samples.first['stage'], 0);
      expect(samples[63]['stage'], 63);
      expect(samples[64]['stage'], 84);
      expect(samples.last['stage'], 99);
      expect(report['stateChangesDroppedForBound'], 20);
      expect(
        samples.last['systemFrameTimestampUs'],
        greaterThan(samples.first['systemFrameTimestampUs']! as int),
      );
    },
  );
}
