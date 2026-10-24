import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../application/settings_controller.dart';

final appInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  double? _volume;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final preferences = state.preferences;
    final busy = state.loading || state.saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          if (state.loading || state.saving) const LinearProgressIndicator(),
          if (state.error != null) ...[
            Text(state.error!, semanticsLabel: state.error),
            TextButton(
              onPressed: busy
                  ? null
                  : () => ref.read(settingsProvider.notifier).retry(),
              child: const Text('Retry preferences'),
            ),
          ],
          if (state.recovered)
            const Text(
              'Recovered your previous preferences. Your drawings are unchanged.',
            ),
          const ListTile(
            leading: Icon(Icons.volume_up_outlined),
            title: Text('Preview volume'),
            subtitle: Text(
              'Only changes playback in the app. Exported music keeps its original level.',
            ),
          ),
          Slider(
            value: _volume ?? preferences.previewVolume,
            min: 0,
            max: 1,
            divisions: 20,
            label:
                '${(((_volume ?? preferences.previewVolume)) * 100).round()}%',
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} percent preview volume',
            onChanged: busy ? null : (value) => setState(() => _volume = value),
            onChangeEnd: busy
                ? null
                : (value) async {
                    await ref
                        .read(settingsProvider.notifier)
                        .save(preferences.copyWith(previewVolume: value));
                    if (mounted) setState(() => _volume = null);
                  },
          ),
          if (preferences.previewVolume == 0)
            const Text(
              'Preview is muted. Exports still contain music. Also check your device media volume if playback is quiet.',
            ),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            subtitle: const Text(
              'Optional feedback when choosing a voice or changing tempo. Availability depends on your device.',
            ),
            value: preferences.haptics,
            onChanged: busy
                ? null
                : (value) => ref
                      .read(settingsProvider.notifier)
                      .save(preferences.copyWith(haptics: value)),
          ),
          SwitchListTile(
            title: const Text('Reduce nonessential motion'),
            subtitle: const Text(
              'Turn on to reduce page transitions. When off, follows your device preference. The music cursor remains available.',
            ),
            value: preferences.reduceMotion,
            onChanged: busy
                ? null
                : (value) => ref
                      .read(settingsProvider.notifier)
                      .save(preferences.copyWith(reduceMotion: value)),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Replay creation guide'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.touch_app_outlined),
            title: const Text('Replay editor tips'),
            subtitle: const Text(
              'Opens a new blank drawing with guided controls.',
            ),
            onTap: () => context.push('/editor/new?tips=1'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy'),
            subtitle: Text(
              'Drawings, preferences and exports stay on this device. Creation works offline without an account. Files leave the app only when you explicitly share them. Uninstalling removes app-private data.',
            ),
          ),
          ref
              .watch(appInfoProvider)
              .when(
                data: (info) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('ScribbleSong'),
                  subtitle: Text(
                    'Version ${info.version} (${info.buildNumber})',
                  ),
                ),
                loading: () => const ListTile(
                  title: Text('ScribbleSong'),
                  subtitle: Text('Reading build information…'),
                ),
                error: (_, _) => const ListTile(
                  title: Text('ScribbleSong'),
                  subtitle: Text('Build information unavailable'),
                ),
              ),
        ],
      ),
    );
  }
}
