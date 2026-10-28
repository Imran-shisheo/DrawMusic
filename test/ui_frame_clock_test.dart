import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/ui_frame_clock.dart';

void main() {
  testWidgets('passive clock is safely polled at idle without forcing frames', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final observer = UiFrameClockObserver(tester.binding);
    final scheduledBefore = tester.binding.hasScheduledFrame;
    observer.start();
    expect(tester.binding.hasScheduledFrame, scheduledBefore);
    expect(observer.latest, isNull);
    await tester.pump(const Duration(milliseconds: 16));
    expect(observer.latest, isNull); // The observer requests no frame itself.
    await tester.pumpWidget(
      const SizedBox(width: 1),
      duration: const Duration(milliseconds: 16),
    );
    final first = observer.latest!;
    expect(observer.observedPostFrames, 1);
    await tester.pumpWidget(
      const SizedBox(width: 2),
      duration: const Duration(milliseconds: 20),
    );
    expect(
      observer.latest!['currentFrameTimeStampUs'],
      greaterThan(first['currentFrameTimeStampUs']!),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      // This is the idle/async polling that crashed the actual profile run
      // when the harness accessed currentFrameTimeStamp directly.
      expect(() => tester.binding.currentFrameTimeStamp, throwsAssertionError);
      expect(observer.latest!['currentFrameTimeStampUs'], isNonNegative);
      expect(observer.latest!['currentSystemFrameTimeStampUs'], isNonNegative);
    });
    observer.stop();
    final stoppedCount = observer.observedPostFrames;
    await tester.pumpWidget(
      const SizedBox(width: 3),
      duration: const Duration(milliseconds: 16),
    );
    expect(observer.observedPostFrames, stoppedCount);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('restart invalidates an old queued callback generation', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final observer = UiFrameClockObserver(tester.binding);
    observer.start();
    observer.stop();
    observer.start();
    await tester.pumpWidget(const SizedBox(width: 1));
    expect(observer.observedPostFrames, 1);
    observer.stop();
    await tester.pumpWidget(const SizedBox(width: 2));
    expect(observer.observedPostFrames, 1);
  });
}
