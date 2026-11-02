// Debug paint-count regressions; these are not native frame-time/FPS evidence.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/l10n/strings.dart';

class _CountingPainter extends CustomPainter {
  _CountingPainter(this.delegate) : super(repaint: delegate);
  final DrawingPainter delegate;
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    delegate.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) =>
      oldDelegate.delegate != delegate;
}

Future<void> _fonts() async {
  for (final family in ['NunitoSans', 'SpaceGrotesk']) {
    final loader = FontLoader(family);
    for (final file
        in Directory('assets/fonts/$family')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.ttf'))) {
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}

ProjectDocument _document(int count) => ProjectDocument(
  id: 'home-paint-$count',
  title: 'Recent $count points',
  strokes: [
    for (var stroke = 0; stroke < (count / 1000).ceil(); stroke++)
      Stroke(
        id: 's$stroke',
        instrument: Instrument.keys,
        points: [
          for (var point = 0; point < (count < 1000 ? count : 1000); point++)
            InkPoint(
              point / (count < 1000 ? count - 1 : 999),
              ((point * 37 + stroke * 17) % 1000) / 999,
            ),
        ],
      ),
  ],
);
Finder _preview(String id) => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint &&
      widget.painter is DrawingPainter &&
      (widget.painter! as DrawingPainter).document.id == id,
);
Future<Uint8List> _pixels(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('home-artwork-paint')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        return Uint8List.fromList(
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
              .asUint8List(),
        );
      } finally {
        image.dispose();
      }
    }))!;

void main() {
  for (final count in [100, 100000]) {
    testWidgets(
      'actual Home isolates unchanged $count-point preview during visible scroll and refreshes real revisions',
      (tester) async {
        tester.view.physicalSize = const Size(411, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.runAsync(_fonts);
        var document = _document(count);
        final appearance = ValueNotifier((dark: true, scale: 1.0));
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomePage()),
            GoRoute(
              path: '/editor/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Paint isolation uses a deterministic actual-load fixture too;
              // source flights now wait on real destination readiness.
              editorLoadProvider.overrideWith(
                (ref, request) async => ProjectLoad(document),
              ),
              libraryProvider.overrideWith(
                (ref) async => ProjectListing([document], []),
              ),
            ],
            child: ValueListenableBuilder(
              valueListenable: appearance,
              builder: (context, value, _) => MaterialApp.router(
                theme: buildTheme(
                  brightness: value.dark ? Brightness.dark : Brightness.light,
                ),
                themeAnimationDuration: Duration.zero,
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(value.scale)),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        final preview = _preview(document.id);
        expect(preview, findsOneWidget);
        final render = tester.renderObject<RenderCustomPaint>(preview);
        final proxy = _CountingPainter(render.painter! as DrawingPainter);
        render.painter = proxy;
        await tester.pump();
        var baseline = proxy.paints;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          proxy.paints - baseline,
          0,
          reason: 'Idle Aurora ticks must not repaint artwork.',
        );
        baseline = proxy.paints;
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final before = scrollable.position.pixels;
        final gesture = await tester.startGesture(const Offset(190, 380));
        for (var i = 0; i < 16; i++) {
          await gesture.moveBy(const Offset(0, -8));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(scrollable.position.pixels - before, greaterThan(100));
        expect(
          tester.getRect(find.byKey(const ValueKey('home-artwork'))).bottom,
          greaterThan(100),
        );
        expect(render.painter, same(proxy));
        expect(
          proxy.paints - baseline,
          0,
          reason:
              'Scrolling must retain the unchanged dense drawing display list.',
        );
        await gesture.cancel();
        await tester.pump();
        if (count == 100) {
          final pixelsBefore = await _pixels(tester);
          document = document.copyWith(
            revision: document.revision + 1,
            title: 'Updated recent artwork',
            strokes: [
              Stroke(
                id: 'changed',
                instrument: Instrument.mallet,
                points: [InkPoint(.1, .1), InkPoint(.9, .9)],
              ),
            ],
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(HomePage)),
          );
          container.invalidate(libraryProvider);
          await tester.pump();
          await tester.pump();
          final refreshed = tester.renderObject<RenderCustomPaint>(
            _preview(document.id),
          );
          expect(refreshed.painter, isA<DrawingPainter>());
          expect(
            (refreshed.painter! as DrawingPainter).document,
            same(document),
          );
          final refreshedProxy = _CountingPainter(
            refreshed.painter! as DrawingPainter,
          );
          refreshed.painter = refreshedProxy;
          await tester.pump();
          expect(
            refreshedProxy.paints,
            greaterThan(0),
            reason: 'New drawing revision must repaint its bounded preview.',
          );
          expect(await _pixels(tester), isNot(orderedEquals(pixelsBefore)));
          appearance.value = (dark: false, scale: 1.4);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final semantics = tester.ensureSemantics();
          await tester.pump();
          expect(
            tester
                .getSemantics(find.byKey(const ValueKey('home-artwork')))
                .label,
            contains('Updated recent artwork'),
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('home-artwork')),
          );
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('home-artwork')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Opened ${document.id}'), findsOneWidget);
          semantics.dispose();
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        appearance.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
