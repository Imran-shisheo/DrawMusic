import 'dart:convert';
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
import 'package:scribblesong/design_system/creative_dock.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/l10n/generated/app_localizations.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

const _pixelsKey = ValueKey('home-content-pixels');
const _capture = bool.fromEnvironment('HOME_CONTENT_CAPTURE');

// A nonlinear size mapping whose 12/14 samples sit exactly at the old strict
// breakpoints. Larger display text grows at a different rate. Layout must use
// its actual content geometry, not assume a linear scale from either sample.
class _BoundaryScaler extends TextScaler {
  const _BoundaryScaler();
  @override
  double scale(double fontSize) =>
      fontSize <= 14 ? fontSize * 1.5 : 21 + (fontSize - 14) * 1.2;
  @override
  double get textScaleFactor => 1.5;
}

Future<void> _fonts() async {
  for (final family in [
    'NunitoSans',
    'SpaceGrotesk',
    'NotoSansArabic',
    'NotoSansDevanagari',
    'NotoSansThai',
    'NotoSansCJK',
  ]) {
    final loader = FontLoader(family);
    for (final file in Directory(
      'assets/fonts/$family',
    ).listSync().whereType<File>()) {
      if (file.path.endsWith('.ttf') || file.path.endsWith('.ttc')) {
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      }
    }
    await loader.load();
  }
}

MemoryRepository _repository() {
  final repo = MemoryRepository();
  repo.documents['saved-art'] = ProjectDocument(
    id: 'saved-art',
    title: 'Session ribbon',
    strokes: [
      Stroke(
        id: 'ribbon',
        instrument: Instrument.keys,
        points: [
          InkPoint(.12, .7),
          InkPoint(.38, .24),
          InkPoint(.62, .64),
          InkPoint(.87, .3),
        ],
      ),
    ],
  );
  return repo;
}

Future<GoRouter> _mount(
  WidgetTester tester, {
  required TextScaler scaler,
  bool dark = false,
  String locale = 'en',
  bool rtl = false,
  Size size = const Size(320, 640),
}) async {
  if (_capture) debugDisableShadows = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final router = buildRouter();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _pixelsKey,
      child: ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) async => _repository()),
          exportListingProvider.overrideWith(
            (ref) async => const ExportListing([]),
          ),
          audioEngineProvider.overrideWithValue(TestAudio()),
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(
              UserPreferences(
                tutorialCompleted: true,
                editorTipsCompleted: true,
                reduceMotion: true,
                darkTheme: dark,
                languageCode: locale,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: scaler, disableAnimations: true),
            child: rtl
                ? Directionality(
                    textDirection: TextDirection.rtl,
                    child: child!,
                  )
                : child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void _wholeWords(WidgetTester tester, Finder scope) {
  for (final element
      in find
          .descendant(of: scope, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final span = paragraph.text as TextSpan;
    for (final word in span.toPlainText().split(RegExp(r'\s+'))) {
      final measure = TextPainter(
        text: TextSpan(text: word, style: span.style),
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout();
      expect(
        measure.width,
        lessThanOrEqualTo(paragraph.size.width + .01),
        reason: 'The whole word "$word" must fit its real assigned text width.',
      );
      measure.dispose();
    }
  }
}

void _geometry(WidgetTester tester) {
  final headline = tester.getRect(find.byKey(const ValueKey('home-headline')));
  final artwork = tester.getRect(find.byKey(const ValueKey('home-artwork')));
  final continuation = tester.getRect(
    find.byKey(const ValueKey('home-continue')),
  );
  expect(headline.bottom + 12, lessThanOrEqualTo(artwork.top));
  expect(artwork.bottom, lessThanOrEqualTo(continuation.top));
  final dock = find.byType(CreativeDock);
  final dockRect = tester.getRect(dock);
  final scrollRect = tester.getRect(
    find.byKey(const PageStorageKey('home-scroll')),
  );
  expect(scrollRect.bottom, lessThanOrEqualTo(dockRect.top));
  for (final role in [
    'nav-home',
    'nav-library',
    'nav-settings',
    'root-new-drawing',
  ]) {
    final key = find.byKey(ValueKey(role));
    final rect = tester.getRect(key);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.top, greaterThanOrEqualTo(dockRect.top));
    expect(rect.bottom, lessThanOrEqualTo(dockRect.bottom));
    expect(key.hitTestable(), findsOneWidget);
    _wholeWords(tester, key);
  }
  _wholeWords(tester, find.byKey(const ValueKey('home-start')));
}

Future<void> _save(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final dir = Directory('work/home-content-fix');
    await dir.create(recursive: true);
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_pixelsKey))
        .toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('${dir.path}/$name.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(_fonts);
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearTextScaleFactorTestValue();
  });
  for (final testCase in [
    (
      name: '320-100-light-en',
      scaler: const TextScaler.linear(1),
      dark: false,
      locale: 'en',
      rtl: false,
    ),
    (
      name: '320-150-light-en',
      scaler: const TextScaler.linear(1.5),
      dark: false,
      locale: 'en',
      rtl: false,
    ),
    (
      name: '320-200-light-en',
      scaler: const TextScaler.linear(2),
      dark: false,
      locale: 'en',
      rtl: false,
    ),
    (
      name: '320-200-dark-en',
      scaler: const TextScaler.linear(2),
      dark: true,
      locale: 'en',
      rtl: false,
    ),
    (
      name: '320-200-light-fr-rtl',
      scaler: const TextScaler.linear(2),
      dark: false,
      locale: 'fr',
      rtl: true,
    ),
    (
      name: '320-200-dark-fr-rtl',
      scaler: const TextScaler.linear(2),
      dark: true,
      locale: 'fr',
      rtl: true,
    ),
    (
      name: '320-nonlinear-light-fr',
      scaler: const _BoundaryScaler(),
      dark: false,
      locale: 'fr',
      rtl: false,
    ),
  ]) {
    testWidgets(
      '${testCase.name} real fonts keep headline/art separate and whole navigation words',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final router = await _mount(
          tester,
          scaler: testCase.scaler,
          dark: testCase.dark,
          locale: testCase.locale,
          rtl: testCase.rtl,
        );
        try {
          _geometry(tester);
          final strings = AppLocalizations.of(
            tester.element(find.byType(HomePage)),
          )!;
          for (final label in [
            strings.home,
            strings.library,
            strings.settings,
            strings.newDrawing,
          ]) {
            expect(find.bySemanticsLabel(label), findsOneWidget);
          }
          await _save(tester, testCase.name);
          // Foreground artwork/Continue are real actions and remain reachable in
          // the natural flow; the dock always leaves the scroll viewport clear.
          await tester.ensureVisible(
            find.byKey(const ValueKey('home-artwork')),
          );
          await tester.pumpAndSettle();
          await _save(tester, '${testCase.name}-artwork');
          await tester.ensureVisible(
            find.byKey(const ValueKey('home-continue')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('home-continue')).hitTestable(),
            findsOneWidget,
          );
          await _save(tester, '${testCase.name}-continue');
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          debugDisableShadows = true;
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      '411 normal ${dark ? 'dark' : 'light'} keeps graphite artwork framing, safe gaps and immediate creation',
      (tester) async {
        final router = await _mount(
          tester,
          scaler: const TextScaler.linear(1),
          dark: dark,
          size: const Size(411, 850),
        );
        try {
          final strings = AppLocalizations.of(
            tester.element(find.byType(HomePage)),
          )!;
          expect(find.text(strings.drawYourMelody), findsOneWidget);
          final paper = tester.getRect(
            find.byKey(const ValueKey('home-artwork-paint')),
          );
          expect(paper.width / paper.height, closeTo(4 / 5, .001));
          final headline = tester.getRect(
            find.byKey(const ValueKey('home-headline')),
          );
          final artwork = tester.getRect(
            find.byKey(const ValueKey('home-artwork')),
          );
          expect(artwork.top - headline.bottom, greaterThanOrEqualTo(4));
          expect(
            find.byKey(const ValueKey('home-start')).hitTestable(),
            findsOneWidget,
          );
          await _save(tester, '411-100-${dark ? 'dark' : 'light'}-en');
          if (_capture) {
            await tester.runAsync(
              () =>
                  File(
                    'work/home-content-fix/411-100-${dark ? 'dark' : 'light'}-geometry.json',
                  ).writeAsString(
                    jsonEncode({
                      'headline': [
                        headline.left,
                        headline.top,
                        headline.right,
                        headline.bottom,
                      ],
                      'artwork': [
                        artwork.left,
                        artwork.top,
                        artwork.right,
                        artwork.bottom,
                      ],
                      'foregroundGapDp': artwork.top - headline.bottom,
                    }),
                  ),
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          debugDisableShadows = true;
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
    );
  }

  testWidgets(
    'all twelve actual-font locales fit complete dock words at 200 percent',
    (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final router = await _mount(
          tester,
          scaler: const TextScaler.linear(2),
          locale: locale.languageCode,
        );
        _geometry(tester);
        expect(tester.takeException(), isNull);
        debugDisableShadows = true;
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'theme chrome updates without losing current library branch, scroll or project',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final repo = _repository();
      for (var i = 0; i < 20; i++) {
        repo.documents['row-$i'] = ProjectDocument(
          id: 'row-$i',
          title: 'Saved $i',
        );
      }
      final original = repo.documents['saved-art'];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) async => repo),
            exportListingProvider.overrideWith(
              (ref) async => const ExportListing([]),
            ),
            audioEngineProvider.overrideWithValue(TestAudio()),
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(
                  darkTheme: false,
                  reduceMotion: true,
                  tutorialCompleted: true,
                  editorTipsCompleted: true,
                ),
              ),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      // This full app uses the real SystemTextScaler path from the test view,
      // independently of the explicit linear/nonlinear MediaQuery fixtures.
      _geometry(tester);
      await tester.tap(find.byKey(const ValueKey('nav-library')));
      await tester.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scroll).position.pixels;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CreativeDock)),
      );
      SystemUiOverlayStyle rootStyle() => tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first
          .value;
      expect(rootStyle().statusBarIconBrightness, Brightness.dark);
      expect(
        rootStyle().statusBarBrightness,
        Brightness.light,
      ); // iOS background convention.
      expect(rootStyle().systemNavigationBarIconBrightness, Brightness.dark);
      final settings = container.read(settingsProvider.notifier);
      await settings.save(
        container.read(settingsProvider).preferences.copyWith(darkTheme: true),
      );
      await tester.pumpAndSettle();
      expect(rootStyle().statusBarIconBrightness, Brightness.light);
      expect(rootStyle().statusBarBrightness, Brightness.dark);
      expect(rootStyle().systemNavigationBarColor, Colors.transparent);
      expect(
        GoRouter.of(tester.element(find.byType(CreativeDock)))
            .routeInformationProvider
            .value
            .uri
            .path,
        '/drafts',
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        position,
      );
      expect(repo.documents['saved-art'], same(original));
      final appBarContext = tester.element(find.byType(CreativeDock));
      final darkAppBar = Theme.of(appBarContext)
          .appBarTheme
          .systemOverlayStyle!;
      expect(darkAppBar.statusBarIconBrightness, Brightness.light);
      await tester.tap(find.byKey(const ValueKey('root-new-drawing')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDisableShadows = true;
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  if (_capture) {
    tearDownAll(() async {
      await File('work/home-content-fix/manifest.json').writeAsString(
        jsonEncode({
          'scope': 'Actual Home/root dock widgets with real bundled fonts and fixture repository/audio/preferences. Static reduced motion, not native OS-icon or motion proof.',
          'cases': '320dp 100/150/200 percent plus nonlinear boundary mapping; light/dark; long French/forced RTL. Artwork variants use actual vertical scroll.',
        }),
      );
    });
  }
}
