import 'package:scribblesong/features/settings/domain/preferences.dart';

class MemoryPreferencesStore implements PreferencesStore {
  MemoryPreferencesStore([this.preferences = const UserPreferences()]);
  UserPreferences preferences;
  bool fail = false;
  @override
  Future<PreferencesLoad> load() async => PreferencesLoad(preferences);
  @override
  Future<void> save(UserPreferences value) async {
    if (fail) throw StateError('Storage unavailable');
    preferences = value;
  }
}
