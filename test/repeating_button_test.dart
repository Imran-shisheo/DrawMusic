import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/repeating_icon_button.dart';

void main() {
  testWidgets(
    'tempo hold repeats, release stops, and the limit disables repetition',
    (tester) async {
      var tempo = 198;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: RepeatingIconButton(
                tooltip: 'Faster',
                icon: Icons.add,
                onStep: tempo >= 200 ? null : () => setState(() => tempo++),
              ),
            ),
          ),
        ),
      );
      final hold = await tester.startGesture(
        tester.getCenter(find.byTooltip('Faster')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tempo, 200);
      await hold.up();
      await tester.pump(const Duration(seconds: 2));
      expect(tempo, 200);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'release, cancellation, lifecycle loss and disposal stop active repetition',
    (tester) async {
      var steps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepeatingIconButton(
              tooltip: 'Slower',
              icon: Icons.remove,
              onStep: () => steps++,
            ),
          ),
        ),
      );
      final hold = await tester.startGesture(
        tester.getCenter(find.byTooltip('Slower')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 360));
      expect(steps, greaterThan(1));
      await hold.up();
      final released = steps;
      await tester.pump(const Duration(seconds: 1));
      expect(steps, released);
      final again = await tester.startGesture(
        tester.getCenter(find.byTooltip('Slower')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final stopped = steps;
      await tester.pump(const Duration(seconds: 1));
      expect(steps, stopped);
      await again.cancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final finalHold = await tester.startGesture(
        tester.getCenter(find.byTooltip('Slower')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(const SizedBox());
      await finalHold.cancel();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('a modal stops an already held tempo control', (tester) async {
    var steps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                RepeatingIconButton(
                  tooltip: 'Faster',
                  icon: Icons.add,
                  onStep: () => steps++,
                ),
                TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Tempo panel'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open panel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final hold = await tester.startGesture(
      tester.getCenter(find.byTooltip('Faster')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 240));
    expect(steps, greaterThan(1));
    await tester.tap(find.text('Open panel'));
    await tester.pump(const Duration(milliseconds: 240));
    final stopped = steps;
    await tester.pump(const Duration(seconds: 1));
    expect(steps, stopped);
    await hold.cancel();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
