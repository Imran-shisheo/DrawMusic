import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/export/presentation/export_preview_stage.dart';

void main() {
  final document = ProjectDocument(
    id: 'preview-lifecycle',
    title: 'A saved drawing',
    strokes: [
      Stroke(
        id: 'stroke',
        instrument: Instrument.keys,
        points: [InkPoint(.1, .2), InkPoint(.8, .7)],
      ),
    ],
  );
  const stageKey = ValueKey('preview-stage');
  const artworkKey = ValueKey('export-frozen-artwork');
  const sealKey = ValueKey('export-finalized-seal');

  void normalPlatformMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  final theme = buildTheme(brightness: Brightness.dark);

  Widget scene({
    bool ready = false,
    bool reduce = false,
    bool visible = true,
  }) => MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: TickerMode(
        enabled: visible,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ExportPreviewStage(
                key: stageKey,
                document: document,
                accent: const Color(0xffef7a35),
                extension: 'PNG',
                ready: ready,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('success ink is finite and leaves the actual artwork anchored', (
    tester,
  ) async {
    normalPlatformMotion(tester);
    await tester.pumpWidget(scene());
    await tester.pumpAndSettle();
    final artwork = tester.element(find.byKey(artworkKey));
    final bounds = tester.getRect(find.byKey(artworkKey));
    expect(bounds.width / bounds.height, closeTo(4 / 5, .00001));
    expect(find.byKey(sealKey), findsNothing);
    await tester.pumpWidget(scene(ready: true));
    expect(find.byKey(sealKey), findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.element(find.byKey(artworkKey)), same(artwork));
    expect(tester.getRect(find.byKey(artworkKey)), bounds);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced and hidden success use static ink without late replay', (
    tester,
  ) async {
    normalPlatformMotion(tester);
    for (final reduced in [true, false]) {
      await tester.pumpWidget(scene(reduce: reduced, visible: reduced));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        scene(ready: true, reduce: reduced, visible: reduced),
      );
      await tester.pump();
      expect(find.byKey(sealKey), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(scene(ready: true));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'backgrounding ends success decoration and resume never replays',
    (tester) async {
      normalPlatformMotion(tester);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      await tester.pumpWidget(scene(ready: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byKey(sealKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
