import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/design_system/creative_components.dart';

void main() {
  testWidgets(
    'rapid transitions retain branches, exclude hidden semantics and pause their tickers',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue(),
      );
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      final keys = [
        GlobalKey<_BranchProbeState>(),
        GlobalKey<_BranchProbeState>(),
        GlobalKey<_BranchProbeState>(),
      ];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: selected,
            builder: (context, index, _) => RetainedBranchContainer(
              index: index,
              children: [
                for (var i = 0; i < 3; i++)
                  _BranchProbe(key: keys[i], label: 'branch-$i'),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final first = keys[0].currentState!;
      first.counter = 7;
      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final hiddenTicks = first.ticks;
      selected.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      selected.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(keys[0].currentState, same(first));
      expect(first.counter, 7);
      expect(first.ticks, hiddenTicks);
      expect(keys.every((key) => key.currentState!.mounted), isTrue);
      expect(find.text('branch-1'), findsOneWidget);
      expect(find.text('branch-0'), findsNothing);
      expect(find.bySemanticsLabel('branch-0'), findsNothing);
      selected.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(first.ticks, greaterThan(hiddenTicks));
      expect(first.counter, 7);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ambient pauses for hidden regions, app background and reduced motion',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue(),
      );
      final enabled = ValueNotifier(true);
      final reduce = ValueNotifier(false);
      addTearDown(enabled.dispose);
      addTearDown(reduce.dispose);
      final markKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: reduce,
            builder: (context, reduced, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (_, active, _) => TickerMode(
                  enabled: active,
                  child: SketchMark(key: markKey, animated: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      final state = markKey.currentState;
      expect(tester.hasRunningAnimations, isTrue);
      enabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.hasRunningAnimations, isFalse);
      enabled.value = true;
      await tester.pump();
      expect(markKey.currentState, same(state));
      expect(tester.hasRunningAnimations, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      reduce.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(SketchMark), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _BranchProbe extends StatefulWidget {
  const _BranchProbe({super.key, required this.label});
  final String label;
  @override
  State<_BranchProbe> createState() => _BranchProbeState();
}

class _BranchProbeState extends State<_BranchProbe>
    with SingleTickerProviderStateMixin {
  int ticks = 0, counter = 0;
  late final AnimationController ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addListener(() => ticks++)
        ..repeat();
  @override
  void initState() {
    super.initState();
    ticker;
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
