import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/paper_panel.dart';
import 'package:scribblesong/design_system/style_panel.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/backgrounds/data/background_assets.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';
import 'package:scribblesong/features/backgrounds/presentation/photo_crop_workspace.dart';
import 'package:scribblesong/l10n/strings.dart';

const capture = bool.fromEnvironment('UI_VISUAL_CAPTURE');
const rootKey = ValueKey('background-redesign-root');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('scribblesong/backgrounds');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  setUpAll(() async {
    if (!capture) return;
    for (final family in [
      'NunitoSans',
      'SpaceGrotesk',
      'NotoSansDevanagari',
      'NotoSansThai',
      'NotoSansArabic',
      'NotoSansCJK',
    ]) {
      final loader = FontLoader(family);
      for (final file
          in Directory('assets/fonts/$family')
              .listSync()
              .whereType<File>()
              .where(
                (file) =>
                    file.path.endsWith('.ttf') || file.path.endsWith('.ttc'),
              )) {
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await icons.load();
  });

  test('crop gestures preserve source, orientation and bounded valid windows through every transform', () {
    for (final size in [
      const Size(100, 100),
      const Size(100, 200),
      const Size(200, 100),
      const Size(1, 2048),
      const Size(2048, 1),
    ]) {
      for (var turn = 0; turn < 4; turn++) {
        for (final mirror in [false, true]) {
          final paper = BackgroundDefinition(
            kind: BackgroundKind.photo,
            assetId: 'a' * 64,
            quarterTurns: turn,
            mirror: mirror,
          );
          final before = paper.toJson();
          final gesture = PhotoCropGesture(
            paper: paper,
            imageSize: size,
            viewport: const Size(200, 250),
            focalPoint: const Offset(70, 110),
          );
          for (final scale in [.1, 1.0, 2.0, 20.0, double.nan, -1.0]) {
            final changed = gesture.update(const Offset(86, 98), scale);
            expect(
              changed.valid,
              isTrue,
              reason: 'source $size turn$turn mirror$mirror scale$scale',
            );
            expect(paper.copyWith(crop: changed).assetId, paper.assetId);
          }
          expect(paper.toJson(), before);
        }
      }
    }
  });

  Future<({BackgroundAssets assets, BackgroundDefinition paper})> fixture(
    WidgetTester tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('redesign-photo-'),
    );
    addTearDown(() => directory!.delete(recursive: true));
    final assets = BackgroundAssets(directory!);
    final recorder = ui.PictureRecorder(), size = const Size(320, 400);
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(320, 400), [
          const Color(0xfff3e1ba),
          const Color(0xffc8ded0),
        ]),
    );
    canvas.drawCircle(
      const Offset(236, 100),
      44,
      Paint()..color = const Color(0xffd3a14b),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 280)
        ..cubicTo(90, 160, 170, 350, 320, 210)
        ..lineTo(320, 400)
        ..lineTo(0, 400)
        ..close(),
      Paint()..color = const Color(0xffb9a8cf),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 350)
        ..cubicTo(80, 270, 230, 360, 320, 270)
        ..lineTo(320, 400)
        ..lineTo(0, 400)
        ..close(),
      Paint()..color = const Color(0xff5d8a77),
    );
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(320, 400));
    final bytes = (await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    ))!.buffer.asUint8List();
    picture.dispose();
    image!.dispose();
    final id = sha256.convert(bytes).toString();
    await tester.runAsync(
      () => assets.file(id).writeAsBytes(bytes, flush: true),
    );
    return (
      assets: assets,
      paper: BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: id,
        crop: const CropWindow(left: .2, top: .2, width: .6, height: .6),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester,
    BackgroundDefinition paper, {
    BackgroundAssets? assets,
    ValueChanged<BackgroundDefinition?>? result,
    Brightness brightness = Brightness.light,
    TextDirection direction = TextDirection.ltr,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(brightness: brightness),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final selected = await showBackgroundPanel(
                    context,
                    paper,
                    assets: assets,
                  );
                  result?.call(selected);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    if (paper.kind == BackgroundKind.photo) {
      for (
        var i = 0;
        i < 100 &&
            find
                .byKey(const ValueKey('background-crop-workspace'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('background-crop-workspace')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'direct crop pan, pinch and keyboard edit only the pending image until Apply',
    (tester) async {
      final photo = await fixture(tester), before = photo.paper.toJson();
      BackgroundDefinition? result;
      await open(
        tester,
        photo.paper,
        assets: photo.assets,
        result: (value) => result = value,
      );
      final workspace = find.byKey(const ValueKey('background-crop-workspace'));
      await tester.ensureVisible(workspace);
      await tester.pumpAndSettle();
      final initialVisible = PhotoCropGesture(
        paper: photo.paper,
        imageSize: const Size(320, 400),
        viewport: tester.getSize(workspace),
        focalPoint: tester.getSize(workspace).center(Offset.zero),
      ).visible;
      await tester.drag(workspace, const Offset(28, 0));
      await tester.pumpAndSettle();
      expect(photo.paper.toJson(), before);
      expect(result, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final center = tester.getCenter(workspace),
          a = await tester.startGesture(
            center - const Offset(25, 0),
            pointer: 1,
          ),
          b = await tester.startGesture(
            center + const Offset(25, 0),
            pointer: 2,
          );
      for (final distance in [40.0, 55.0, 70.0, 85.0]) {
        await a.moveTo(center - Offset(distance, 0));
        await b.moveTo(center + Offset(distance, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.assetId, photo.paper.assetId);
      expect(result!.crop.valid, isTrue);
      expect(result!.crop.width, lessThan(initialVisible.width));
      expect(result!.crop.left, isNot(photo.paper.crop.left));
      expect(photo.paper.toJson(), before);
    },
  );

  testWidgets(
    'RTL custom hex editing stays keyboard-safe, validated and transactional',
    (tester) async {
      tester.view.physicalSize = const Size(411, 850);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetViewInsets);
      final original = BackgroundDefinition.solid(0xfff7f5eb);
      BackgroundDefinition? result;
      await open(
        tester,
        original,
        direction: TextDirection.rtl,
        result: (value) => result = value,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      final form = find.byKey(const ValueKey('background-first-color'));
      await tester.ensureVisible(form);
      final field = find.descendant(of: form, matching: find.byType(TextField));
      expect(tester.widget<TextField>(field).textDirection, TextDirection.ltr);
      await tester.enterText(field, '12ZZZZ');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      expect(result, isNull);
      await tester.enterText(field, '12ABEF');
      await tester.pumpAndSettle();
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.colors.first, 0xff12abef);
      expect(original.colors.first, 0xfff7f5eb);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, size, brightness, direction, locale, scale) in [
    (
      'phone-light',
      const Size(411, 850),
      Brightness.light,
      TextDirection.ltr,
      const Locale('en'),
      1.0,
    ),
    (
      'phone-dark',
      const Size(411, 850),
      Brightness.dark,
      TextDirection.ltr,
      const Locale('en'),
      1.0,
    ),
    (
      'tablet-rtl',
      const Size(1000, 900),
      Brightness.dark,
      TextDirection.rtl,
      const Locale('en'),
      1.0,
    ),
    (
      'compact-hindi',
      const Size(320, 740),
      Brightness.light,
      TextDirection.ltr,
      const Locale('hi'),
      2.0,
    ),
    (
      'phone-french-large',
      const Size(411, 850),
      Brightness.dark,
      TextDirection.ltr,
      const Locale('fr'),
      2.0,
    ),
    (
      'landscape-large',
      const Size(640, 360),
      Brightness.dark,
      TextDirection.rtl,
      const Locale('en'),
      2.0,
    ),
  ]) {
    testWidgets(
      'branded photo workspace $name preserves aspect and reachable actions',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final photo = await fixture(tester);
        await open(
          tester,
          photo.paper,
          assets: photo.assets,
          brightness: brightness,
          direction: direction,
          locale: locale,
        );
        final workspace = find.byKey(
          const ValueKey('background-crop-workspace'),
        );
        expect(tester.getSize(workspace).aspectRatio, closeTo(.8, .0001));
        final scroller = find
            .ancestor(
              of: workspace,
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        final frameRect = tester.getRect(workspace),
            viewportRect = tester.getRect(scroller);
        expect(frameRect.top, greaterThanOrEqualTo(viewportRect.top - 1));
        expect(
          frameRect.bottom,
          lessThanOrEqualTo(viewportRect.bottom + 1),
          reason:
              'The complete photo frame must fit the visible editing viewport.',
        );

        expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (capture) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(rootKey),
          );
          final image = await tester.runAsync(
            () => boundary.toImage(pixelRatio: 1),
          );
          final data = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.png),
          );
          final output = Directory('work/ui-backgrounds-after');
          await tester.runAsync(() => output.create(recursive: true));
          await tester.runAsync(
            () =>
                File('${output.path}/$name.png')
                    .writeAsBytes(data!.buffer.asUint8List(), flush: true),
          );
          image!.dispose();
        }
      },
    );
  }
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'immersive style choices remain named, selected and usable in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(411, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        DrawingStyle? selected;
        await tester.pumpWidget(
          RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(brightness: brightness),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      selected = await showStylePanel(
                        context,
                        DrawingStyle.smooth,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Smooth'), findsOneWidget);
        expect(find.text('Pixel'), findsOneWidget);
        if (capture) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(rootKey),
              ),
              image = await tester.runAsync(
                () => boundary.toImage(pixelRatio: 1),
              );
          final data = await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.png),
          );
          await tester.runAsync(
            () =>
                File('work/ui-backgrounds-after/style-${brightness.name}.png')
                    .writeAsBytes(data!.buffer.asUint8List(), flush: true),
          );
          image!.dispose();
        }
        await tester.ensureVisible(find.text('Pixel'));
        await tester.tap(find.text('Pixel'));
        await tester.pumpAndSettle();
        expect(selected, DrawingStyle.pixel);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
