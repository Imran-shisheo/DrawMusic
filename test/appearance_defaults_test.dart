import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/settings/data/file_preferences_store.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

void main() {
  test('a fresh install opens the immersive dark theme while saved light choice survives reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'doodimo-appearance-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FilePreferencesStore(directory);
    final fresh = (await store.load()).preferences;
    expect(fresh.darkTheme, isTrue);
    await store.save(
      fresh.copyWith(darkTheme: false, previewVolume: .42, reduceMotion: true),
    );
    final reopened = (await FilePreferencesStore(directory).load()).preferences;
    expect(reopened.darkTheme, isFalse);
    expect(reopened.previewVolume, .42);
    expect(reopened.reduceMotion, isTrue);
  });

  test('legacy settings without a theme retain the historical light interpretation', () {
    final legacy = const UserPreferences(
      previewVolume: .42,
      reduceMotion: true,
    ).toJson()..remove('darkTheme');
    final loaded = UserPreferences.fromJson(legacy);
    expect(loaded.darkTheme, isFalse);
    expect(loaded.previewVolume, .42);
    expect(loaded.reduceMotion, isTrue);
  });
}
