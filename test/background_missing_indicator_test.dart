import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/backgrounds/data/background_assets.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/presentation/background_surface.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

const capture = ValueKey('missing-paper-capture');

void main() {
  for (final brightness in Brightness.values) {
    for (final color in [0xfff8f5e9, 0xff000000, 0xffff0000, 0xffffffff]) {
      testWidgets(
        'missing photo indicator pixels/semantics $brightness ${color.toRadixString(16)}',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final root = (await tester.runAsync(
              () => Directory.systemTemp.createTemp('missing-paper-contrast-'),
            ))!;
            addTearDown(
              () => tester.runAsync(() => root.delete(recursive: true)),
            );
            var taps = 0;
            final paper = BackgroundDefinition(
              kind: BackgroundKind.photo,
              assetId: 'f' * 64,
              colors: [color],
            );
            Future<void> mount(bool show) => tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  iconTheme: IconThemeData(
                    color: brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: capture,
                      child: SizedBox(
                        width: 112,
                        height: 140,
                        child: GestureDetector(
                          onTap: () => taps++,
                          child: BackgroundSurface(
                            paper: paper,
                            assets: BackgroundAssets(root),
                            showMissingIndicator: show,
                            child: const Center(
                              child: SizedBox(
                                width: 40,
                                height: 2,
                                child: ColoredBox(color: Color(0xff7961c6)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await mount(true);
            final indicator = find.bySemanticsLabel(
              'This photo is unavailable. Replace or remove it.',
            );
            // Wait on actual missing-file completion, not an assumed fixed delay.
            for (var i = 0; i < 100 && indicator.evaluate().isEmpty; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
              await tester.pumpAndSettle();
            }
            expect(indicator, findsOneWidget);
            final indicatorWidget = find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label ==
                      'This photo is unavailable. Replace or remove it.',
            );
            final indicatorRect = tester.getRect(indicatorWidget);
            final boundaryRect = tester.getRect(find.byKey(capture));
            final pixels = (await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(capture),
              );
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                return (
                  bytes.buffer.asUint8List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes,
                  ),
                  image.width,
                );
              } finally {
                image.dispose();
              }
            }))!;
            Color at(int x, int y) {
              final i = (y * pixels.$2 + x) * 4;
              return Color.fromARGB(
                pixels.$1[i + 3],
                pixels.$1[i],
                pixels.$1[i + 1],
                pixels.$1[i + 2],
              );
            }

            final left = (indicatorRect.left - boundaryRect.left).round();
            final top = (indicatorRect.top - boundaryRect.top).round();
            final backing = at(left + 1, top + indicatorRect.height ~/ 2);
            var lo = 1.0, hi = 0.0;
            for (var y = top; y < top + indicatorRect.height.floor(); y++) {
              for (var x = left; x < left + indicatorRect.width.floor(); x++) {
                final l = at(x, y).computeLuminance();
                if (l < lo) lo = l;
                if (l > hi) hi = l;
              }
            }
            debugPrint(
              'ACTUAL $brightness paper=${color.toRadixString(16)} indicator maximum contrast=${(hi + .05) / (lo + .05)} backing=${backing.toARGB32().toRadixString(16)}',
            );
            expect(
              backing.toARGB32(),
              0xff151b35,
              reason:
                  'Opaque semantic backing must ignore paper and chrome theme',
            );
            var accessibleSilhouettePixels = 0;
            for (var y = top; y < top + indicatorRect.height.floor(); y++) {
              for (var x = left; x < left + indicatorRect.width.floor(); x++) {
                final pixel = at(x, y);
                if (pixel.r > .95 && pixel.g > .95 && pixel.b > .95) {
                  final ratio =
                      (pixel.computeLuminance() + .05) /
                      (backing.computeLuminance() + .05);
                  expect(ratio, greaterThanOrEqualTo(3));
                  accessibleSilhouettePixels++;
                }
              }
            }
            expect(
              accessibleSilhouettePixels,
              greaterThan(30),
              reason: 'Actual painted essential image silhouette, not just declared widget colors',
            );
            expect(
              at(56, 70).toARGB32(),
              0xff7961c6,
              reason: 'Drawing ink remains visible',
            );
            expect(
              at(2, 100).toARGB32(),
              color,
              reason: 'Fallback paper pixels are not rewritten',
            );
            await tester.tapAt(indicatorRect.center);
            expect(
              taps,
              1,
              reason: 'Missing indicator must IgnorePointer so file-open/editor gestures still reach the surface',
            );
            await mount(false);
            await tester.pumpAndSettle();
            expect(
              indicator,
              findsNothing,
              reason:
                  'Caller opt-out must suppress both icon and its semantics',
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
