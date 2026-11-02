import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/features/settings/application/privacy_policy.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';

import 'support/memory_preferences.dart';
import 'widget_test.dart' show MemoryRepository, TestAudio;

void main() {
  test('a missing or non-HTTPS policy cannot become a browser link', () {
    expect(httpsPrivacyPolicyUri(null), isNull);
    expect(httpsPrivacyPolicyUri(''), isNull);
    expect(
      httpsPrivacyPolicyUri(Uri.https('app.notion.com', '').toString()),
      isNull,
    );
    expect(httpsPrivacyPolicyUri('http://example.invalid/privacy'), isNull);
    expect(
      httpsPrivacyPolicyUri(
        Uri(
          scheme: 'https',
          host: 'example.invalid',
          userInfo: 'test-only',
        ).toString(),
      ),
      isNull,
    );
    expect(
      httpsPrivacyPolicyUri('https://example.invalid/privacy'),
      Uri.https('example.invalid', '/privacy'),
    );
  });

  Future<void> settings(
    WidgetTester tester, {
    bool unpublished = false,
    Future<bool> Function(Uri)? launch,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWith((ref) async => MemoryRepository()),
          audioEngineProvider.overrideWithValue(TestAudio()),
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(
              const UserPreferences(
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
          if (unpublished) privacyPolicyUriProvider.overrideWithValue(null),
          if (launch != null)
            privacyPolicyLauncherProvider.overrideWithValue(launch),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Privacy'), 200);
    await Scrollable.ensureVisible(
      tester.element(find.text('Privacy')),
      alignment: .2,
    );
    await tester.pumpAndSettle();
    expect(find.text('Privacy').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Privacy').hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'privacy explains providers, backups and recovery without a guessed link',
    (tester) async {
      await settings(tester, unpublished: true);
      expect(find.byKey(const ValueKey('privacy-policy-link')), findsNothing);
      final text = find.textContaining('Sharing or saving an export');
      expect(text, findsOneWidget);
      final copy = tester.widget<Text>(text).data!;
      expect(copy, contains('cloud provider'));
      expect(copy, contains('backups'));
      expect(copy, contains('recovery copies'));
      expect(copy, contains('after deletion or uninstalling'));
      expect(copy, isNot(contains('only when you explicitly share')));
    },
  );

  testWidgets('policy launch false/exception remains honest and retryable', (
    tester,
  ) async {
    // Exercise the configured public URL; the fake launcher never opens a browser.
    final uri = Uri.parse(publishedPrivacyPolicyUrl);
    var calls = 0;
    await settings(
      tester,
      launch: (actual) async {
        expect(actual, uri);
        calls++;
        if (calls == 1) return false;
        if (calls == 2) {
          throw const FileSystemException('test-only private provider detail');
        }
        return true;
      },
    );
    final link = find.byKey(const ValueKey('privacy-policy-link'));
    for (var i = 0; i < 3; i++) {
      await Scrollable.ensureVisible(tester.element(link), alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(link).enabled, isTrue);
      expect(find.textContaining('private provider detail'), findsNothing);
      if (i < 2) {
        expect(
          find.text('Could not open the privacy policy. Please try again.'),
          findsOneWidget,
        );
        ScaffoldMessenger.of(tester.element(link)).clearSnackBars();
        await tester.pumpAndSettle();
      }
    }
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });
}
