import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/graphite_launch.dart';

const _decoration = ValueKey('graphite-launch-decoration');

class _LiveChild extends StatefulWidget {
  const _LiveChild({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  State<_LiveChild> createState() => _LiveChildState();
}

class _LiveChildState extends State<_LiveChild> {
  var builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    return Scaffold(
      body: Center(
        child: TextButton(onPressed: widget.onTap, child: const Text('Ready')),
      ),
    );
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
    'stored setting gates decoration, never ready input or child tree',
    (tester) async {
      var ready = false;
      var reduce = false;
      var taps = 0;
      late StateSetter change;
      final childKey = GlobalKey<_LiveChildState>();
      final child = _LiveChild(key: childKey, onTap: () => taps++);
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return GraphiteLaunch(
                preferencesReady: ready,
                reduceMotion: reduce,
                child: child,
              );
            },
          ),
        ),
      );
      expect(find.byKey(_decoration), findsNothing);
      expect(find.text('Ready'), findsOneWidget);
      change(() => ready = true);
      await tester.pump();
      expect(find.byKey(_decoration), findsOneWidget);
      final state = childKey.currentState!;
      final builds = state.builds;
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump(const Duration(milliseconds: 240));
      expect(identical(state, childKey.currentState), isTrue);
      expect(state.builds, builds);
      await tester.tap(find.text('Ready'));
      await tester.pump();
      expect(taps, 1);
      expect(find.byKey(_decoration), findsNothing);
      change(() => reduce = true);
      await tester.pump();
      change(() => reduce = false);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_decoration), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'persisted/system reduce, hidden tickers and warm resume consume',
    (tester) async {
      for (final mode in [
        'stored',
        'system',
        'hidden',
        'background',
        'stored-later',
        'system-later',
        'hidden-later',
      ]) {
        var ready = mode != 'stored';
        var reduce = mode == 'stored';
        var hidden = mode == 'hidden';
        var system = mode == 'system';
        late StateSetter change;
        await tester.pumpWidget(const SizedBox());
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: system),
                  child: TickerMode(
                    enabled: !hidden,
                    child: GraphiteLaunch(
                      preferencesReady: ready,
                      reduceMotion: reduce,
                      child: const Scaffold(body: Text('Ready workspace')),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        if (mode == 'background') {
          expect(find.byKey(_decoration), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 300));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        if (mode.endsWith('-later')) {
          expect(find.byKey(_decoration), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 180));
          change(() {
            reduce = mode == 'stored-later';
            system = mode == 'system-later';
            hidden = mode == 'hidden-later';
          });
          await tester.pump();
          expect(find.byKey(_decoration), findsNothing, reason: mode);
        }
        change(() {
          ready = true;
          reduce = false;
          hidden = false;
          system = false;
        });
        await tester.pump();
        expect(find.byKey(_decoration), findsNothing, reason: mode);
        expect(find.text('Ready workspace'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(_decoration), findsNothing, reason: mode);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('finite opening settles and does not replay on rebuilt theme', (
    tester,
  ) async {
    var dark = false;
    late StateSetter change;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          change = setState;
          return MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: const GraphiteLaunch(
              preferencesReady: true,
              reduceMotion: false,
              child: Scaffold(body: Text('Ready')),
            ),
          );
        },
      ),
    );
    expect(find.byKey(_decoration), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(_decoration), findsNothing);
    change(() => dark = true);
    await tester.pumpAndSettle();
    expect(find.byKey(_decoration), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
