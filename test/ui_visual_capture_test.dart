// Explicit visual-evidence harness. Fixtures replace storage/audio platform ports;
// these PNGs are actual product widgets, not device/runtime acceptance.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/editor/presentation/instrument_glyph.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart'
    show instrumentName;
import 'package:scribblesong/features/editor/presentation/editor.dart';
import 'package:scribblesong/features/export/domain/export_port.dart';
import 'package:scribblesong/features/export_library/data/export_actions.dart';
import 'package:scribblesong/features/export_library/domain/export_library.dart';
import 'package:scribblesong/features/onboarding/presentation/tutorial.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/language_page.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';
import 'package:scribblesong/features/rating/presentation/rating_offer.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

const _verify = bool.fromEnvironment('UI_VISUAL_VERIFY');
const _enabled = bool.fromEnvironment('UI_VISUAL_CAPTURE') || _verify;
const _previewOnly = bool.fromEnvironment('UI_CAPTURE_PREVIEW_ONLY');
const _homeOnly = bool.fromEnvironment('UI_CAPTURE_HOME_ONLY');
const _immersive = bool.fromEnvironment('UI_CAPTURE_IMMERSIVE');
const _output = String.fromEnvironment(
  'UI_CAPTURE_DIR',
  defaultValue: 'work/ui-after',
);
const _boundary = ValueKey('visual-capture-root');

Future<void> _loadFont(String family, List<File> fonts) async {
  final loader = FontLoader(family);
  for (final font in fonts) {
    loader.addFont(
      font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}

ProjectDocument _drawing({bool empty = false}) => ProjectDocument(
  id: empty ? 'visual-empty' : 'visual-ribbons',
  title: empty ? 'Untitled drawing' : 'Sunday ribbons',
  createdAt: DateTime.utc(2026, 10, 26, 11),
  updatedAt: DateTime.utc(2026, 10, 27, 9),
  strokes: empty
      ? []
      : [
          Stroke(
            id: 'keys',
            instrument: Instrument.keys,
            points: [
              InkPoint(.12, .6),
              InkPoint(.22, .46),
              InkPoint(.36, .51),
              InkPoint(.49, .3),
              InkPoint(.63, .39),
              InkPoint(.83, .24),
            ],
          ),
          Stroke(
            id: 'mallet',
            instrument: Instrument.mallet,
            points: [
              InkPoint(.12, .78),
              InkPoint(.31, .63),
              InkPoint(.48, .74),
              InkPoint(.66, .57),
              InkPoint(.86, .65),
            ],
          ),
          for (var i = 0; i < 5; i++)
            Stroke(
              id: 'bell-$i',
              instrument: Instrument.bell,
              points: [InkPoint(.2 + i * .145, .18 + (i % 2) * .08)],
            ),
        ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!_enabled) return;
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) throw StateError('Source cloud/env.sh before capturing.');
    final material = '$sdk/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', [
      for (final face in ['Regular', 'Medium', 'Bold'])
        File('$material/Roboto-$face.ttf'),
    ]);
    await _loadFont('MaterialIcons', [
      File('$material/MaterialIcons-Regular.otf'),
    ]);
    // The baseline uses actual SDK Roboto/MaterialIcons, never flutter_test Ahem.
    // Native-script fallbacks are loaded when those files are available locally.
    for (final (family, path) in [
      (
        'Noto Sans Thai',
        '/usr/share/fonts/truetype/noto/NotoSansThai-Regular.ttf',
      ),
      (
        'Noto Sans Devanagari',
        '/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf',
      ),
      (
        'Noto Sans Arabic',
        '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
      ),
      (
        'Noto Sans CJK JP',
        '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      ),
    ]) {
      if (await File(path).exists()) await _loadFont(family, [File(path)]);
    }
    // The redesign uses the exact bundled font faces declared in pubspec.
    for (final family in [
      'NunitoSans',
      'SpaceGrotesk',
      'NotoSansDevanagari',
      'NotoSansThai',
      'NotoSansArabic',
      'NotoSansCJK',
    ]) {
      final files = Directory('assets/fonts/$family')
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.ttf') || file.path.endsWith('.ttc'),
          )
          .toList();
      if (files.isNotEmpty) await _loadFont(family, files);
    }
    PackageInfo.setMockInitialValues(
      appName: 'Doodimo',
      packageName: 'com.imranshisheo.scribblesong',
      version: '2.1.0',
      buildNumber: '24',
      buildSignature: 'visual-fixture',
    );
  });

  testWidgets(
    'capture actual product screens with real fonts and declared fixtures',
    (tester) async {
      if (_verify && !_immersive) {
        fail(
          'Visual verification must use the immersive fixtures; rejected references are historical only.',
        );
      }
      final directory = Directory(_output);
      if (_output.endsWith('/ui-before') &&
          File('$_output/manifest.json').existsSync()) {
        fail('Baseline is immutable. Choose a new capture directory.');
      }
      await tester.runAsync(() => directory.create(recursive: true));
      final manifest = <Map<String, dynamic>>[];
      var currentDark = false;
      var currentKeyboardInset = 0.0;
      debugDisableShadows = false;
      final priorFatalTaps = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() {
        debugDisableShadows = true;
        WidgetController.hitTestWarningShouldBeFatal = priorFatalTaps;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 80));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
      }

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pump();
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason: 'Capture actions must hit a visible product control.',
        );
        await tester.tap(finder.hitTestable());
      }

      Future<void> save(String name, {bool wait = true}) async {
        if (_immersive && currentDark && name.endsWith('-light-phone')) {
          name = name.replaceFirst('-light-phone', '-dark-phone');
        }
        if (wait) await settle();
        final rendered = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundary),
        );
        await tester.runAsync(() async {
          final image = await rendered.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('${directory.path}/$name.png').writeAsBytes(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
          } finally {
            image.dispose();
          }
        });
        if (_verify &&
            const [
              '01-home-immersive-dark-phone',
              '06-editor-immersive-dark-phone',
              '09-export-immersive-dark-phone',
              '10b-home-cool-light-phone',
              '13-editor-compact-fr-large',
              '21-editor-landscape',
              '04b-settings-cool-light-phone',
              '17c-language-compact-rtl-dark-large',
            ].contains(name)) {
          final baseline = File('test/goldens/$name.png');
          if (!autoUpdateGoldenFiles && !baseline.existsSync()) {
            fail(
              'Missing reviewed golden: ${baseline.path}. Generate only with an intentional --update-goldens visual review.',
            );
          }
          await expectLater(
            find.byKey(_boundary),
            matchesGoldenFile('goldens/$name.png'),
          );
        }
        final errors = <String>[];
        Object? error;
        while ((error = tester.takeException()) != null) {
          errors.add(error.toString());
        }
        manifest.add({
          'file': '$name.png',
          'size': [
            tester.view.physicalSize.width,
            tester.view.physicalSize.height,
          ],
          'textScale': tester.platformDispatcher.textScaleFactor,
          'brightness': currentDark ? 'dark' : 'light',
          'simulatedKeyboardInset': currentKeyboardInset,
          'renderExceptions': errors,
        });
      }

      Future<void> mount({
        Widget? page,
        bool root = false,
        bool? dark,
        String locale = 'en',
        Size size = const Size(411, 850),
        double scale = 1,
        bool rtl = false,
        bool failPreferenceWrites = false,
        double keyboardInset = 0,
        ProjectDocument? document,
      }) async {
        await tester.pumpWidget(const SizedBox());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final useDark = dark ?? _immersive;
        currentDark = useDark;
        currentKeyboardInset = keyboardInset;
        final doc = document ?? _drawing();
        final repo = MemoryRepository();
        repo.documents[doc.id] = doc;
        final another = doc.copyWith(
          id: 'visual-dots',
          title: 'Little morning',
          revision: 0,
        );
        repo.documents[another.id] = another;
        final exports = ExportListing([
          for (final format in ['mp4', 'wav', 'mid'])
            LibraryExport(
              id: 'fixture.$format',
              artifact: ExportArtifact(
                '/visual-fixture/exports/fixture.$format',
                format == 'mp4'
                    ? 'video/mp4'
                    : format == 'wav'
                    ? 'audio/wav'
                    : 'audio/midi',
                'Sunday ribbons.$format',
                doc.id,
                doc.revision,
              ),
              createdAt: DateTime.utc(2026, 10, 27, 9),
              bytes: format == 'mp4' ? 1400000 : 440000,
              available: true,
              preview: doc,
            ),
        ]);
        await tester.pumpWidget(
          RepaintBoundary(
            key: _boundary,
            child: ProviderScope(
              overrides: [
                initialDocumentProvider.overrideWithValue(doc),
                repositoryProvider.overrideWith((ref) async => repo),
                audioEngineProvider.overrideWithValue(TestAudio()),
                preferencesStoreProvider.overrideWith(
                  (ref) async => MemoryPreferencesStore(
                    UserPreferences(
                      tutorialCompleted: true,
                      editorTipsCompleted: true,
                      reduceMotion: true,
                      darkTheme: useDark,
                      languageCode: locale,
                    ),
                  )..fail = failPreferenceWrites,
                ),
                exportListingProvider.overrideWith((ref) async => exports),
              ],
              child: root
                  ? const ScribbleSongApp()
                  : MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: buildTheme(
                        brightness: useDark
                            ? Brightness.dark
                            : Brightness.light,
                      ),
                      locale: Locale(locale),
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: const EdgeInsets.only(top: 24, bottom: 24),
                          disableAnimations: true,
                        ),
                        child: rtl
                            ? Directionality(
                                textDirection: TextDirection.rtl,
                                child: child!,
                              )
                            : child!,
                      ),
                      home: page ?? const EditorWorkspace(),
                    ),
            ),
          ),
        );
        await settle();
      }

      await mount(root: true);
      await save(
        _immersive ? '01-home-immersive-dark-phone' : '01-home-light-phone',
      );
      if (!_homeOnly) {
        if (!_previewOnly) {
          await tapVisible(find.text('Library'));
          await save('02-drafts-light-phone');
          await tapVisible(find.text('Exports'));
          await save('03-exports-light-phone');
          await tapVisible(find.text('Settings'));
          await save('04-settings-light-phone');
          await mount(document: _drawing(empty: true));
          await save('05-editor-empty-phone');
        }
        await mount();
        await save(
          _immersive
              ? '06-editor-immersive-dark-phone'
              : '06-editor-drawn-phone',
        );
        if (!_previewOnly) {
          await tapVisible(find.byTooltip('Play'));
          await settle();
          await save('07-editor-playing-fixture-phone');
          await tapVisible(find.byTooltip('Pause'));
          await settle();
          await tapVisible(find.byKey(const ValueKey('editor-tools')));
          await settle();
          await tapVisible(find.byKey(const ValueKey('editor-tool-paper')));
          await save('08-background-panel-phone');
        }
        await mount();
        await tapVisible(find.byTooltip('Export loop'));
        await save(
          _immersive
              ? '09-export-immersive-dark-phone'
              : '09-export-panel-phone',
        );
        if (!_previewOnly) {
          await mount(root: true, dark: true);
          await save('10-home-dark-phone');
          await mount(dark: true);
          await save('11-editor-dark-phone');
          if (_immersive) {
            await mount(root: true, dark: false);
            await save('10b-home-cool-light-phone');
            await mount(dark: false);
            await save('11b-editor-cool-light-phone');
          }
          await mount(
            root: true,
            size: const Size(320, 640),
            scale: 2,
            locale: 'fr',
          );
          await save('12-home-compact-fr-large');
          await mount(size: const Size(320, 640), scale: 2, locale: 'fr');
          await save('13-editor-compact-fr-large');
          await mount(root: true, size: const Size(1024, 768));
          await save('14-home-tablet');
          await mount(size: const Size(1024, 768));
          await save('15-editor-tablet');
          await mount(page: const TutorialPage());
          await save('16-help-phone');
          await mount(page: const LanguagePage());
          await save('17-language-phone');
          await mount();
          await tapVisible(find.byKey(const ValueKey('current-voice')));
          await save('18-instrument-chooser-phone');
          await mount();
          await tapVisible(find.byKey(const ValueKey('music-settings')));
          await save('19-music-panel-phone');
          await mount();
          await tapVisible(find.byKey(const ValueKey('editor-tools')));
          await save('20-sketch-tools-phone');
          await mount(size: const Size(640, 360));
          await save('21-editor-landscape');
          await mount(
            size: const Size(411, 850),
            scale: 2,
            rtl: true,
            document: _drawing().copyWith(title: 'موسيقى هادئة'),
          );
          await save('22-editor-forced-rtl-arabic-title');
          await mount(size: const Size(320, 640), scale: 2, locale: 'fr');
          await tapVisible(find.byKey(const ValueKey('current-voice')));
          await save('23-voice-chooser-compact-fr-large');
          await mount(size: const Size(320, 640), scale: 2, locale: 'ja');
          await tapVisible(find.byKey(const ValueKey('music-settings')));
          await save('24-music-panel-compact-ja-large');
          final scratch = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('doodimo-visual-export-'),
          ))!;
          const paths = MethodChannel('plugins.flutter.io/path_provider');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          var exportRoot = scratch.path;
          messenger.setMockMethodCallHandler(paths, (_) async => exportRoot);
          addTearDown(() => messenger.setMockMethodCallHandler(paths, null));
          addTearDown(
            () => tester.runAsync(() => scratch.delete(recursive: true)),
          );
          Future<void> untilVisible(Finder finder) async {
            final timeout = Stopwatch()..start();
            while (finder.evaluate().isEmpty) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
              await tester.pump(const Duration(milliseconds: 80));
              if (timeout.elapsed > const Duration(seconds: 15)) {
                fail('Export visual state not reached.');
              }
            }
          }

          Future<void> exportPanel() async {
            await mount();
            await tapVisible(find.byTooltip('Export loop'));
            await settle();
          }

          await exportPanel();
          await tapVisible(find.byKey(const ValueKey('export-start')));
          await tester.pump();
          expect(find.byKey(const ValueKey('export-working')), findsOneWidget);
          await save('25-export-preparing-real-png', wait: false);
          await untilVisible(find.byKey(const ValueKey('export-ready')));
          final pngs = await tester.runAsync(
            () =>
                Directory('$exportRoot/exports')
                    .list()
                    .where((e) => e.path.endsWith('.png'))
                    .toList(),
          );
          expect(pngs, isNotEmpty);
          await save('26-export-ready-real-png');
          await tester.runAsync(
            () => Directory('${scratch.path}/blocked').create(),
          );
          exportRoot = '${scratch.path}/blocked';
          await tester.runAsync(
            () => File(
              '$exportRoot/exports',
            ).writeAsString('deliberate fixture blocking directory creation'),
          );
          await exportPanel();
          await tapVisible(find.byKey(const ValueKey('export-start')));
          await untilVisible(find.text('Try export again'));
          await save('27-export-error-real-write-failure');
          await mount(page: const TutorialPage(firstUse: true));
          await save('28-welcome-phone');
          await mount();
          showRatingOffer(tester.element(find.byType(EditorWorkspace)))
              .ignore();
          await save('29-optional-rating-offer-fixture');
          await mount(
            page: const SettingsPage(),
            dark: true,
            rtl: true,
            size: const Size(320, 640),
            scale: 2,
            failPreferenceWrites: true,
          );
          final settingsContainer = ProviderScope.containerOf(
            tester.element(find.byType(SettingsPage)),
          );
          final oldPreferences = settingsContainer
              .read(settingsProvider)
              .preferences;
          await settingsContainer
              .read(settingsProvider.notifier)
              .save(oldPreferences.copyWith(haptics: !oldPreferences.haptics));
          await save('30-settings-error-compact-rtl-dark-large');
          if (_immersive) {
            await mount(root: true, dark: false);
            await tapVisible(find.byKey(const ValueKey('nav-library')));
            await save('02b-drafts-cool-light-phone');
            await tapVisible(find.text('Exports'));
            await save('03b-exports-cool-light-phone');
            await mount(page: const SettingsPage(), dark: false);
            await save('04b-settings-cool-light-phone');
            await mount(page: const TutorialPage(), dark: false);
            await save('16b-help-cool-light-phone');
            await mount(page: const LanguagePage(), dark: false);
            await save('17b-language-cool-light-phone');
            await mount(
              page: const LanguagePage(),
              rtl: true,
              size: const Size(320, 640),
              scale: 2,
            );
            await save('17c-language-compact-rtl-dark-large');
            await mount(dark: false);
            showRatingOffer(tester.element(find.byType(EditorWorkspace)))
                .ignore();
            await save('29b-optional-rating-cool-light-phone');
            await mount(size: const Size(320, 640), scale: 2, locale: 'fr');
            showRatingOffer(tester.element(find.byType(EditorWorkspace)))
                .ignore();
            await save('29c-optional-rating-compact-fr-dark-large');
            await mount(dark: false);
            await tapVisible(find.byTooltip('Export loop'));
            await save('09b-export-cool-light-phone');
            await exportPanel();
            final transparent = find.byKey(
              const ValueKey('png-transparent-background'),
            );
            await tester.ensureVisible(transparent);
            await tapVisible(transparent);
            await save('34-export-transparency-setting');
            expect(tester.widget<SwitchListTile>(transparent).value, isTrue);
            await tester.ensureVisible(
              find.byKey(const ValueKey('export-intent-png')),
            );
            await save('34b-export-transparent-preview');
            for (final (action, file) in [
              ('score', '35-score-panel'),
              ('mix', '36-accompaniment-panel'),
              ('clear', '37-clear-confirmation'),
            ]) {
              await mount();
              await tapVisible(find.byKey(const ValueKey('editor-tools')));
              await settle();
              await tapVisible(find.byKey(ValueKey('editor-tool-$action')));
              await save(file);
            }
            await mount();
            await tapVisible(find.byKey(const ValueKey('editor-tools')));
            await settle();
            await tapVisible(find.byKey(const ValueKey('editor-tool-tips')));
            await settle();
            expect(
              find.byKey(const ValueKey('editor-tip-spotlight')),
              findsOneWidget,
            );
            await save('38-coach-canvas-actual-target');
            await tapVisible(find.text('Next tip'));
            await save('38b-coach-play-actual-target');
            await mount(size: const Size(320, 640), scale: 2, locale: 'fr');
            await tapVisible(find.byKey(const ValueKey('editor-tools')));
            await settle();
            await tapVisible(find.byKey(const ValueKey('editor-tool-tips')));
            await settle();
            expect(
              find.byKey(const ValueKey('editor-tip-spotlight')),
              findsOneWidget,
            );
            await save('38c-coach-compact-fr-large-actual-target');
            await mount(keyboardInset: 300);
            await tapVisible(find.text('Sunday ribbons').first);
            await save('31-editor-rename-keyboard-inset');
            await mount(
              size: const Size(320, 640),
              scale: 2,
              locale: 'fr',
              keyboardInset: 220,
            );
            await tapVisible(find.text('Sunday ribbons').first);
            await save('32-editor-rename-compact-fr-large-keyboard-inset');
            await mount(
              size: const Size(800, 840),
              page: Builder(
                builder: (context) => Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original instrument objects · optical study',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            for (final voice in Instrument.values)
                              SizedBox(
                                width: 170,
                                height: 150,
                                child: Column(
                                  children: [
                                    InstrumentGlyph(voice, size: 56),
                                    const SizedBox(height: 16),
                                    Text(instrumentName(context, voice)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await save('33-instrument-objects-optical-study');
          }
          for (final locale in nativeLanguageNames.keys) {
            await mount(
              root: true,
              size: const Size(320, 640),
              scale: 2,
              locale: locale,
            );
            await save('locale-$locale-home-compact-large');
            if (_immersive) {
              await mount(size: const Size(320, 640), scale: 2, locale: locale);
              await save('locale-$locale-editor-compact-large');
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDisableShadows = true;
      await tester.runAsync(
        () => File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'scope': 'Actual Flutter product widgets with fixture repository/preferences/audio/export metadata. Not Android emulator screenshots, native audio proof or physical acceptance.',
            'font': 'Bundled Space Grotesk display, Nunito Sans body weights and Noto script fallbacks loaded explicitly, plus MaterialIcons for legacy controls. Original Doodimo glyphs are CustomPaint geometry. SDK Roboto is also loaded for legacy comparison. No Ahem screenshots.',
            'keyboard': 'Keyboard variants simulate viewInsets; the native system IME is not rendered by this widget harness.',
            'motion': 'Reduced motion enabled for deterministic still evidence; playback position is test audio fixture, not measured native timing.',
            'designStatus': _immersive
                ? 'Immersive replacement proposal; neither prior rejected iteration is acceptance. Motion evidence remains separate.'
                : 'Historical second-iteration proposal; rejected by the owner. Both earlier directions remain rejected evidence.',
            'theme': _immersive
                ? 'First three fixtures explicitly dark; cool-light variants are separately named in the full matrix.'
                : 'Historical light-first fixtures.',
            'screens': manifest,
          }),
        ),
      );
      expect(
        manifest.expand((screen) => screen['renderExceptions'] as List),
        isEmpty,
        reason: 'Rendered product screens must not hide layout errors; inspect manifest and PNGs.',
      );
    },
    skip: !_enabled,
  );
}
