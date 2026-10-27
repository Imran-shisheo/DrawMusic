// Explicit actual-widget design evidence. These captures use real local PNG
// publication for Ready; they are not Android-native or physical-device proof.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/export/presentation/export_sheet.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

const _enabled = bool.fromEnvironment('EXPORT_DESIGN_CAPTURE');
void main() {
  testWidgets(
    'render immersive output stage, focused settings and real published file',
    (tester) async {
      await tester.runAsync(() async {
        final sdk = Platform.environment['FLUTTER_ROOT'];
        if (sdk == null) {
          throw StateError('Source cloud/env.sh before capturing.');
        }
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await icons.load();

        for (final family in [
          'SpaceGrotesk',
          'NunitoSans',
          'NotoSansDevanagari',
          'NotoSansThai',
          'NotoSansArabic',
          'NotoSansCJK',
        ]) {
          final font = FontLoader(family);
          for (final file
              in Directory('assets/fonts/$family')
                  .listSync()
                  .whereType<File>()
                  .where(
                    (f) => f.path.endsWith('.ttf') || f.path.endsWith('.ttc'),
                  )) {
            font.addFont(file.readAsBytes().then(ByteData.sublistView));
          }
          await font.load();
        }
      });
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory('work/export-immersive-03');
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('export-design-ready-'),
      ))!;
      addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => root.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final document = ProjectDocument(
        id: 'design-export',
        title: 'Sunday ribbons',
        paper: BackgroundDefinition(
          kind: BackgroundKind.solid,
          colors: [0xfffbf6e9],
        ),
        strokes: [
          Stroke(
            id: 'ribbons',
            instrument: Instrument.keys,
            points: [
              InkPoint(.1, .7),
              InkPoint(.25, .3),
              InkPoint(.5, .55),
              InkPoint(.7, .25),
              InkPoint(.9, .4),
            ],
          ),
          Stroke(
            id: 'mallet',
            instrument: Instrument.mallet,
            points: [
              InkPoint(.15, .85),
              InkPoint(.4, .6),
              InkPoint(.6, .8),
              InkPoint(.85, .55),
            ],
          ),
        ],
      );
      const boundaryKey = ValueKey('export-design-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ProviderScope(
            child: MaterialApp(
              theme: buildTheme(brightness: Brightness.dark),
              debugShowCheckedModeBanner: false,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => showExportSheet(context, document),
                      child: const Text('Open export fixture'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> save(String name) async {
        await tester.pump(const Duration(milliseconds: 400));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        await tester.runAsync(() async {
          await directory.create(recursive: true);
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('${directory.path}/$name.png')
                .writeAsBytes(bytes.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      await tester.tap(find.text('Open export fixture'));
      await tester.pumpAndSettle();
      await save('09-export-image');
      await tester.ensureVisible(
        find.byKey(const ValueKey('export-intent-mp4')),
      );
      await tester.tap(find.byKey(const ValueKey('export-intent-mp4')));
      await tester.pumpAndSettle();
      await save('09b-export-video');
      await tester.ensureVisible(
        find.byKey(const ValueKey('export-intent-png')),
      );
      await tester.tap(find.byKey(const ValueKey('export-intent-png')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-start')));
      await tester.pump();
      final deadline = Stopwatch()..start();
      while (find.byKey(const ValueKey('export-ready')).evaluate().isEmpty) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (deadline.elapsed > const Duration(seconds: 15)) {
          fail('Real PNG export did not reach Ready');
        }
      }
      await save('26-export-ready-object');
      expect(
        await tester.runAsync(
          () =>
              Directory('${root.path}/exports')
                  .list()
                  .where((f) => f.path.endsWith('.png'))
                  .length,
        ),
        1,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !_enabled,
  );
}
