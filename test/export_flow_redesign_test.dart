import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export/presentation/export_sheet.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/data/file_export_library.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

ProjectDocument _drawing() => ProjectDocument(
  id: 'export-flow',
  title: 'Quiet circles',
  strokes: [
    Stroke(
      id: 'line',
      instrument: Instrument.keys,
      points: [InkPoint(.2, .5), InkPoint(.8, .5)],
    ),
  ],
);

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final timeout = Stopwatch()..start();
  while (!ready()) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    if (timeout.elapsed > const Duration(seconds: 15)) {
      fail(
        'Export state not reached. Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
      );
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
}

class _GatedLibrary implements ExportLibrary {
  _GatedLibrary(this.delegate);
  final ExportLibrary delegate;
  final finish = Completer<void>();
  bool recording = false;
  @override
  Future<void> record(ExportArtifact artifact, ProjectDocument document) async {
    recording = true;
    await finish.future;
    await delegate.record(artifact, document);
  }

  @override
  Future<ExportListing> list() => delegate.list();
  @override
  Future<void> remove(String id) => delegate.remove(id);
  @override
  Future<void> restore(String id) => delegate.restore(id);
  @override
  Future<void> rename(String id, String title) => delegate.rename(id, title);
}

void main() {
  for (final (size, textScale, direction, brightness) in [
    (const Size(390, 844), 1.0, TextDirection.ltr, Brightness.light),
    (const Size(320, 640), 2.0, TextDirection.rtl, Brightness.dark),
    (const Size(640, 320), 2.0, TextDirection.ltr, Brightness.light),
  ]) {
    testWidgets(
      'intent-led export shows only selected settings at $size scale$textScale $direction',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final snapshot = _drawing();
        final before = snapshot.encode();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildTheme(brightness: brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Directionality(
                textDirection: direction,
                child: Scaffold(body: ExportSheet(snapshot: snapshot)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('png-output-width')), findsOneWidget);
        expect(find.byKey(const ValueKey('video-output-fps')), findsNothing);
        for (final (format, label) in [
          ('mp4', 'Export MP4'),
          ('wav', 'Export WAV'),
          ('midi', 'Export MIDI'),
          ('png', 'Export PNG'),
        ]) {
          final intent = find.byKey(ValueKey('export-intent-$format'));
          await tester.ensureVisible(intent);
          await tester.pumpAndSettle();
          await tester.tap(intent);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('export-start')).hitTestable(),
            findsOneWidget,
          );
          expect(find.text(label), findsOneWidget);
          expect(
            find.byKey(const ValueKey('video-output-fps')),
            format == 'mp4' ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('png-output-width')),
            format == 'png' ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
        expect(snapshot.encode(), before);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'rapid format changes with motion enabled preserve one settings subtree and snapshot',
    (tester) async {
      final snapshot = _drawing(), before = _drawing().strokes.single.toJson();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: false),
              child: child!,
            ),
            home: Scaffold(body: ExportSheet(snapshot: snapshot)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      for (final format in ['wav', 'mp4', 'png', 'midi', 'wav', 'png']) {
        final target = find.byKey(ValueKey('export-intent-$format'));
        await tester.ensureVisible(target);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 35));
        expect(find.byKey(ValueKey('export-settings-$format')), findsOneWidget);
        expect(find.byKey(const ValueKey('export-start')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(snapshot.strokes.single.toJson(), before);
      await tester.pumpWidget(const SizedBox());
    },
  );

  Future<Directory> storage(WidgetTester tester) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('export-ui-flow-'),
    ))!;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => root.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
    return root;
  }

  Future<void> open(
    WidgetTester tester,
    ExportLibrary library, {
    ProjectDocument? snapshot,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exportLibraryProvider.overrideWith((ref) async => library)],
        child: MaterialApp(
          theme: buildTheme(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showExportSheet(context, snapshot ?? _drawing()),
                child: const Text('Open export'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'real PNG publication drives preparing/finalizing/ready and finalizing blocks Back without losing the job',
    (tester) async {
      final root = await storage(tester);
      final real = FileExportLibrary(Directory('${root.path}/exports'));
      final gated = _GatedLibrary(real);
      await open(tester, gated);
      await tester.tap(find.byKey(const ValueKey('export-start')));
      await tester.pump();
      expect(find.byKey(const ValueKey('export-working')), findsOneWidget);
      await _until(tester, () => gated.recording);
      expect(find.byKey(const ValueKey('export-finalizing')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Close',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExportSheet), findsOneWidget);
      expect(
        (await tester.runAsync(
          () =>
              Directory('${root.path}/exports')
                  .list()
                  .where((f) => f.path.endsWith('.png'))
                  .toList(),
        ))!.length,
        1,
      );
      gated.finish.complete();
      await _until(
        tester,
        () => find.byKey(const ValueKey('export-ready')).evaluate().isNotEmpty,
      );
      final listing = (await tester.runAsync(real.list))!;
      expect(listing.entries.single.available, isTrue);
      expect(listing.entries.single.artifact.name, 'Quiet circles.png');
      expect(find.text('Share exported file'), findsOneWidget);
      expect(find.text('Save a public copy'), findsOneWidget);
      expect(find.text('Open with another app'), findsOneWidget);
      expect(find.text('Export ready on this device.'), findsOneWidget);
      await tester.ensureVisible(find.text('Choose another format'));
      await tester.tap(find.text('Choose another format'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('export-selection')), findsOneWidget);
      expect((await tester.runAsync(real.list))!.entries.length, 1);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ExportSheet), findsNothing);
    },
  );
  testWidgets(
    'real output failure shows retry; successful retry publishes once; cancellation preserves the document and leaves no new artifact',
    (tester) async {
      final root = await storage(tester);
      final blocker = File('${root.path}/exports');
      await tester.runAsync(
        () => blocker.writeAsString('preserve until retry'),
      );
      final library = FileExportLibrary(Directory(blocker.path));
      await open(tester, library);
      await tester.tap(find.byKey(const ValueKey('export-start')));
      await tester.pump();
      await _until(
        tester,
        () => find.text('Try export again').evaluate().isNotEmpty,
      );
      expect(find.byKey(const ValueKey('export-ready')), findsNothing);
      expect(
        await tester.runAsync(blocker.readAsString),
        'preserve until retry',
      );
      await tester.runAsync(blocker.delete);
      await tester.tap(find.byKey(const ValueKey('export-start')));
      await tester.pump();
      await _until(
        tester,
        () => find.byKey(const ValueKey('export-ready')).evaluate().isNotEmpty,
      );
      expect((await tester.runAsync(library.list))!.entries.length, 1);
      await tester.ensureVisible(find.text('Choose another format'));
      await tester.tap(find.text('Choose another format'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-start')));
      await tester.pump();
      expect(find.text('Cancel export'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('export-start')));
      await tester.pump();
      await _until(
        tester,
        () => find
            .text('Export canceled. Your drawing is safe.')
            .evaluate()
            .isNotEmpty,
      );
      expect((await tester.runAsync(library.list))!.entries.length, 1);
      expect(
        await tester.runAsync(
          () =>
              Directory(blocker.path)
                  .list()
                  .where((f) => f.path.endsWith('.tmp'))
                  .toList(),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final transparent in [false, true]) {
    testWidgets(
      'real PNG UI publishes ${transparent ? 'transparent' : 'paper'} pixels after reaching scrolled settings',
      (tester) async {
        tester.view.physicalSize = const Size(411, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = await storage(tester);
        final library = FileExportLibrary(Directory('${root.path}/exports'));
        final snapshot = _drawing().copyWith(background: 0xff123456);
        final before = snapshot.encode();
        await open(
          tester,
          library,
          snapshot: snapshot,
          brightness: Brightness.dark,
        );
        final switchTile = find.byKey(
          const ValueKey('png-transparent-background'),
        );
        await tester.ensureVisible(switchTile);
        await tester.pumpAndSettle();
        expect(switchTile.hitTestable(), findsOneWidget);
        expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
        if (transparent) {
          await tester.tap(switchTile);
          await tester.pumpAndSettle();
        }
        expect(tester.widget<SwitchListTile>(switchTile).value, transparent);
        await tester.ensureVisible(find.byKey(const ValueKey('png-width-640')));
        await tester.tap(find.byKey(const ValueKey('png-width-640')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('export-start')));
        await tester.pump();
        await _until(
          tester,
          () =>
              find.byKey(const ValueKey('export-ready')).evaluate().isNotEmpty,
        );
        final listing = (await tester.runAsync(library.list))!;
        expect(listing.entries, hasLength(1));
        final artifact = listing.entries.single.artifact;
        final pixels = (await tester.runAsync(() async {
          final bytes = await File(artifact.path).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          try {
            final image = (await codec.getNextFrame()).image;
            try {
              expect(image.width, 640);
              expect(image.height, 800);
              return (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          } finally {
            codec.dispose();
          }
        }))!;
        List<int> pixel(int x, int y) =>
            pixels.sublist((y * 640 + x) * 4, (y * 640 + x) * 4 + 4);
        for (final point in [
          const Offset(0, 0),
          const Offset(639, 0),
          const Offset(0, 799),
          const Offset(639, 799),
        ]) {
          expect(
            pixel(point.dx.toInt(), point.dy.toInt()),
            transparent ? [0, 0, 0, 0] : [18, 52, 86, 255],
          );
        }
        expect(
          pixel(320, 400)[3],
          255,
          reason: 'Real ink stays opaque with or without paper.',
        );
        expect(pixel(320, 400).take(3), isNot([18, 52, 86]));
        expect(snapshot.encode(), before);
        expect(listing.entries.single.preview!.background, 0xff123456);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
