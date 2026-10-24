import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/file_preferences_store.dart';
import '../domain/preferences.dart';

final preferencesStoreProvider = FutureProvider<PreferencesStore>((ref) async {
  final root = await getApplicationSupportDirectory();
  return FilePreferencesStore(Directory('${root.path}/settings'));
});

class SettingsState {
  const SettingsState({
    this.preferences = const UserPreferences(),
    this.loading = false,
    this.saving = false,
    this.recovered = false,
    this.error,
  });
  final UserPreferences preferences;
  final bool loading, saving, recovered;
  final String? error;
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

class SettingsController extends Notifier<SettingsState> {
  bool _alive = true;
  UserPreferences? _failedSave;
  @override
  SettingsState build() {
    ref.onDispose(() => _alive = false);
    unawaited(Future<void>.microtask(load));
    return const SettingsState(loading: true);
  }

  Future<void> load() async {
    if (!_alive) return;
    state = SettingsState(preferences: state.preferences, loading: true);
    try {
      final loaded = await (await ref.read(preferencesStoreProvider.future))
          .load();
      if (_alive) {
        state = SettingsState(
          preferences: loaded.preferences,
          recovered: loaded.recovered,
        );
      }
    } catch (_) {
      if (_alive) {
        state = SettingsState(
          preferences: state.preferences,
          error: 'Could not load preferences. Your drawings are safe. Retry or continue for now.',
        );
      }
    }
  }

  Future<bool> save(UserPreferences candidate) async {
    if (state.loading || state.saving) return false;
    final previous = state.preferences;
    state = SettingsState(preferences: previous, saving: true);
    try {
      await (await ref.read(preferencesStoreProvider.future)).save(candidate);
      _failedSave = null;
      if (_alive) state = SettingsState(preferences: candidate);
      return true;
    } catch (_) {
      _failedSave = candidate;
      if (_alive) {
        state = SettingsState(
          preferences: previous,
          error: 'Could not save preferences. Check storage, then retry.',
        );
      }
      return false;
    }
  }

  Future<void> retry() async {
    final candidate = _failedSave;
    if (candidate != null) {
      await save(candidate);
    } else {
      ref.invalidate(preferencesStoreProvider);
      await load();
    }
  }
}
