import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/creative_panel.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/l10n/strings.dart';

void main() {
  Future<FocusNode> mount(
    WidgetTester tester, {
    required GlobalKey<_PanelProbeState> probe,
    Size size = const Size(411, 850),
    bool reduced = false,
    bool compactKeyboard = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final triggerFocus = FocusNode();
    addTearDown(triggerFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(brightness: Brightness.dark),
        locale: compactKeyboard ? const Locale('ar') : const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(compactKeyboard ? 2 : 1),
            viewInsets: EdgeInsets.only(bottom: compactKeyboard ? 220 : 0),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              child: TextButton(
                focusNode: triggerFocus,
                onPressed: () => showCreativePanel<void>(
                  context: context,
                  sourceBounds: const Rect.fromLTWH(24, 48, 80, 48),
                  builder: (context) => CreativePanel(
                    title: 'Paper controls',
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Finish'),
                      ),
                    ],
                    child: _PanelProbe(key: probe),
                  ),
                ),
                child: const Text('Open controls'),
              ),
            ),
          ),
        ),
      ),
    );
    triggerFocus.requestFocus();
    await tester.pump();
    return triggerFocus;
  }

  for (final size in [const Size(411, 850), const Size(900, 900)]) {
    testWidgets(
      'panel Back during entrance keeps one child and restores trigger $size',
      (tester) async {
        final probe = GlobalKey<_PanelProbeState>();
        final focus = await mount(tester, probe: probe, size: size);
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.text('Open controls'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final state = probe.currentState!;
        await tester.pump(const Duration(milliseconds: 50));
        expect(identical(probe.currentState, state), isTrue);
        expect(state.mounts, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(probe.currentState, isNull);
        expect(state.disposals, 1);
        expect(focus.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('input during panel entrance retains edits and one live child', (
    tester,
  ) async {
    final probe = GlobalKey<_PanelProbeState>();
    await mount(tester, probe: probe, size: const Size(900, 900));
    await tester.tap(find.text('Open controls'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final state = probe.currentState!;
    final field = find.byType(TextField);
    expect(field.hitTestable(), findsOneWidget);
    await tester.tap(field);
    await tester.enterText(field, 'Ready while arriving');
    await tester.pumpAndSettle();
    expect(state.text.text, 'Ready while arriving');
    expect(identical(probe.currentState, state), isTrue);
    expect(state.mounts, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(state.disposals, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reduced panel remains full-sized and input publishes immediately',
    (tester) async {
      final probe = GlobalKey<_PanelProbeState>();
      await mount(tester, probe: probe, reduced: true);
      await tester.tap(find.text('Open controls'));
      await tester.pumpAndSettle();
      final state = probe.currentState!;
      final field = find.byType(TextField);
      final before = tester.getRect(field);
      await tester.tap(field);
      await tester.enterText(field, 'My local paper');
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getRect(field), before);
      expect(state.text.text, 'My local paper');
      expect(identical(probe.currentState, state), isTrue);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(probe.currentState, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'compact RTL 200 percent panel keeps keyboard-safe action and Back',
    (tester) async {
      final probe = GlobalKey<_PanelProbeState>();
      final focus = await mount(
        tester,
        probe: probe,
        size: const Size(320, 640),
        compactKeyboard: true,
        reduced: true,
      );
      await tester.tap(find.text('Open controls'));
      await tester.pumpAndSettle();
      final action = find.text('Finish');
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(420));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _PanelProbe extends StatefulWidget {
  const _PanelProbe({super.key});
  @override
  State<_PanelProbe> createState() => _PanelProbeState();
}

class _PanelProbeState extends State<_PanelProbe> {
  final text = TextEditingController();
  int mounts = 0, disposals = 0;
  @override
  void initState() {
    super.initState();
    mounts++;
  }

  @override
  void dispose() {
    disposals++;
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: text,
    decoration: const InputDecoration(labelText: 'Local memo'),
  );
}
