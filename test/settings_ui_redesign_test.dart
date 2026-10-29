import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/onboarding/presentation/editor_tips.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';
import 'package:scribblesong/l10n/strings.dart';

import 'support/memory_preferences.dart';

void main() {
  for (final (size, dark, rtl) in [
    (const Size(320, 640), false, false),
    (const Size(640, 320), true, true),
    (const Size(1024, 768), true, false),
  ]) {
    testWidgets(
      'grouped settings remain operable at ${size.width}×${size.height}, 200% text, dark=$dark RTL=$rtl',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryPreferencesStore(
          UserPreferences(
            darkTheme: dark,
            previewVolume: .7,
            tutorialCompleted: true,
            reduceMotion: true,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesStoreProvider.overrideWith((ref) async => store),
              appInfoProvider.overrideWith(
                (ref) async => PackageInfo(
                  appName: 'ScribbleSong',
                  packageName: 'com.devwithdelta.doodimo',
                  version: '2.1.0',
                  buildNumber: '24',
                ),
              ),
            ],
            child: MaterialApp(
              theme: buildTheme(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: child!,
                ),
              ),
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Haptic feedback'), 140);
        await Scrollable.ensureVisible(
          tester.element(find.text('Haptic feedback')),
          alignment: .2,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Haptic feedback'));
        await tester.pumpAndSettle();
        expect(store.preferences.haptics, isTrue);
        await tester.scrollUntilVisible(
          find.text('Reduce nonessential motion'),
          140,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Reduce nonessential motion')),
          alignment: .2,
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(SwitchListTile, 'Reduce nonessential motion'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(find.text('Privacy'), 140);
        await Scrollable.ensureVisible(
          tester.element(find.text('Privacy')),
          alignment: .2,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Privacy'));
        await tester.pumpAndSettle();
        // Read the actual localized resource; an expansion must expose its detail.
        final strings = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        )!;
        expect(
          find.text(
            strings.drawingsPreferencesAndExportsStayOnThisDeviceCreationWorks,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
        expect(store.preferences.previewVolume, .7);
        // Ensure every state is disposed before the next size, including folds.
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'coach marks follow the real target after resize, block ink taps and restore focus',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final target = GlobalKey();
      final boundary = GlobalKey();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var inkTaps = 0;
      bool? completed;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Stack(
                  children: [
                    Positioned(
                      left: MediaQuery.sizeOf(context).width * .1,
                      top: 56,
                      child: GestureDetector(
                        key: target,
                        onTap: () => inkTaps++,
                        child: const SizedBox(
                          width: 96,
                          height: 56,
                          child: ColoredBox(color: Color(0xffff0000)),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: TextButton(
                        focusNode: focus,
                        onPressed: () async {
                          completed = await showEditorTips(context, [
                            EditorTip(
                              'Try this control',
                              'The spotlight follows its actual position.',
                              target,
                            ),
                          ]);
                        },
                        child: const Text('Learn controls'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Learn controls'));
      await tester.pumpAndSettle();
      Future<void> unshadedTarget() async {
        final center = tester.getCenter(find.byKey(target));
        final rgba = await tester.runAsync(() async {
          final box =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await box.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final at = (center.dy.floor() * image.width + center.dx.floor()) * 4;
          final pixel = bytes.sublist(at, at + 4);
          image.dispose();
          return pixel;
        });
        expect(rgba, [255, 0, 0, 255]);
        await tester.tapAt(center);
        await tester.pump();
        expect(inkTaps, 0);
      }

      await unshadedTarget();
      tester.view.physicalSize = const Size(640, 480);
      await tester.pumpAndSettle();
      await unshadedTarget();
      await tester.tap(find.text('Skip tips'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(focus.hasFocus, isTrue);
      expect(inkTaps, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
