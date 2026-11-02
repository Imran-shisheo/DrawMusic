import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/settings/application/more_apps.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';

import 'support/memory_preferences.dart';
import 'support/root_navigation.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  test('Android routes to the verified public developer storefront', () {
    expect(
      developerStorefrontUri(TargetPlatform.android),
      Uri.parse(androidDeveloperStorefrontUrl),
    );
    for (final url in [
      'http://play.google.com/store/apps/developer?id=DevWithDelta',
      'https://play.google.com.evil.invalid/store/apps/developer?id=DevWithDelta',
      'https://play.google.com/console/developers/123',
      'https://play.google.com/store/apps/details?id=com.example.app',
      'https://play.google.com/store/apps/developer',
      'https://play.google.com/store/apps/developer?id=',
      'https://user@play.google.com/store/apps/developer?id=DevWithDelta',
    ]) {
      expect(
        developerStorefrontUri(TargetPlatform.android, androidUrl: url),
        isNull,
        reason: url,
      );
    }
  });

  test(
    'iOS and unsupported platforms never fall back to the Android store',
    () {
      expect(
        developerStorefrontUri(TargetPlatform.iOS),
        Uri.parse(iosDeveloperStorefrontUrl),
      );
      const appleFixture =
          'https://apps.apple.com/developer/test-fixture/id123456789';
      expect(
        developerStorefrontUri(TargetPlatform.iOS, iosUrl: appleFixture),
        Uri.parse(appleFixture),
      );
      expect(developerStorefrontUri(TargetPlatform.iOS, iosUrl: null), isNull);
      for (final url in [
        androidDeveloperStorefrontUrl,
        'https://appstoreconnect.apple.com/apps',
        'https://apps.apple.com/app/id123456789',
        'https://apps.apple.com/developer/test-fixture/idno-number',
      ]) {
        expect(developerStorefrontUri(TargetPlatform.iOS, iosUrl: url), isNull);
      }
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(developerStorefrontUri(platform), isNull);
      }
    },
  );

  Future<Finder> settings(
    WidgetTester tester, {
    required Future<bool> Function(Uri) launch,
    bool unavailable = false,
    String languageCode = 'en',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) async => MemoryRepository()),
          audioEngineProvider.overrideWithValue(TestAudio()),
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(
              UserPreferences(
                languageCode: languageCode,
                reduceMotion: true,
                tutorialCompleted: true,
                editorTipsCompleted: true,
              ),
            ),
          ),
          appInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Doodimo',
              packageName: 'com.devwithdelta.doodimo',
              version: '2.1.0',
              buildNumber: '24',
            ),
          ),
          if (unavailable) moreAppsUriProvider.overrideWithValue(null),
          moreAppsLauncherProvider.overrideWithValue(launch),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tapRootNavigation(tester, 'nav-settings');
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('more-apps-link'));
    if (!unavailable) {
      await tester.scrollUntilVisible(link, 200);
      await Scrollable.ensureVisible(tester.element(link), alignment: .3);
      await tester.pumpAndSettle();
      expect(link.hitTestable(), findsOneWidget);
      expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
    }
    return link;
  }

  testWidgets(
    'More apps uses the configured Android URL and retries failures',
    (tester) async {
      var calls = 0;
      final link = await settings(
        tester,
        launch: (uri) async {
          expect(uri, Uri.parse(androidDeveloperStorefrontUrl));
          calls++;
          if (calls == 1) return false;
          if (calls == 2) throw StateError('test-only private provider detail');
          return true;
        },
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(link).enabled, isTrue);
        expect(find.textContaining('private provider detail'), findsNothing);
        if (i < 2) {
          expect(
            find.text('Could not open the app store. Please try again.'),
            findsOneWidget,
          );
          ScaffoldMessenger.of(tester.element(link)).clearSnackBars();
          await tester.pumpAndSettle();
        }
      }
      expect(calls, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending launch suppresses repeated taps and tolerates disposal', (
    tester,
  ) async {
    final completion = Completer<bool>();
    var calls = 0;
    final link = await settings(
      tester,
      launch: (_) {
        calls++;
        return completion.future;
      },
    );
    final onTap = tester.widget<ListTile>(link).onTap!;
    onTap();
    onTap(); // A second callback before the disabling rebuild is also guarded.
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<ListTile>(link).enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing storefront never presents a broken link', (
    tester,
  ) async {
    final link = await settings(
      tester,
      unavailable: true,
      launch: (_) async => throw StateError('must not launch'),
    );
    expect(link, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS Settings launches only the verified Apple storefront', (
    tester,
  ) async {
    Uri? opened;
    final link = await settings(
      tester,
      launch: (uri) async {
        opened = uri;
        return true;
      },
    );
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(opened, Uri.parse(iosDeveloperStorefrontUrl));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('compact French large-text row is reachable and labelled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    var calls = 0;
    final link = await settings(
      tester,
      languageCode: 'fr',
      launch: (_) async {
        calls++;
        return true;
      },
    );
    expect(
      find.descendant(of: link, matching: find.text('Plus d’apps')),
      findsOneWidget,
    );
    expect(tester.getSemantics(link).label, contains('Plus d’apps'));
    await tester.tap(link.hitTestable());
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
