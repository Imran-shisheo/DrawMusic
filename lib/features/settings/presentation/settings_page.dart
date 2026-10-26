import '../../../l10n/operation_messages.dart';

import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../application/settings_controller.dart';
import 'language_page.dart';

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
      appBar: AppBar(title: Text(context.strings.settingsHelp)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.strings.language),
            subtitle: Text(
              nativeLanguageNames[preferences.languageCode] ??
                  nativeLanguageNames['en']!,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/language'),
          ),
          if (state.loading || state.saving) const LinearProgressIndicator(),
          if (state.error != null) ...[
            Text(settingsFailureMessage(context.strings, state.error!)),
            TextButton(
              onPressed: busy
                  ? null
                  : () => ref.read(settingsProvider.notifier).retry(),
              child: Text(context.strings.retryPreferences),
            ),
          ],
          if (state.recovered)
            Text(
              context
                  .strings
                  .recoveredYourPreviousPreferencesYourDrawingsAreUnchanged,
            ),
          ListTile(
            leading: Icon(Icons.volume_up_outlined),
            title: Text(context.strings.previewVolume),
            subtitle: Text(
              context
                  .strings
                  .onlyChangesPlaybackInTheAppExportedMusicKeepsItsOriginalLe,
            ),
          ),
          Slider(
            value: _volume ?? preferences.previewVolume,
            min: 0,
            max: 1,
            divisions: 20,
            label: context.strings.percentValue(
              context.formatNumber(
                ((_volume ?? preferences.previewVolume) * 100).round(),
              ),
            ),
            semanticFormatterCallback: (value) =>
                context.strings.previewVolumePercent(
                  context.formatNumber((value * 100).round()),
                ),
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
            Text(
              context
                  .strings
                  .previewIsMutedExportsStillContainMusicAlsoCheckYourDeviceM,
            ),
          SwitchListTile(
            title: Text(context.strings.darkTheme),
            value: preferences.darkTheme,
            onChanged: busy
                ? null
                : (value) => ref
                      .read(settingsProvider.notifier)
                      .save(preferences.copyWith(darkTheme: value)),
          ),
          SwitchListTile(
            title: Text(context.strings.hapticFeedback),
            subtitle: Text(
              context
                  .strings
                  .optionalFeedbackWhenChoosingAVoiceOrChangingTempoAvailabil,
            ),
            value: preferences.haptics,
            onChanged: busy
                ? null
                : (value) => ref
                      .read(settingsProvider.notifier)
                      .save(preferences.copyWith(haptics: value)),
          ),
          SwitchListTile(
            title: Text(context.strings.reduceNonessentialMotion),
            subtitle: Text(
              context
                  .strings
                  .turnOnToReducePageTransitionsWhenOffFollowsYourDevicePrefe,
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
            title: Text(context.strings.replayCreationGuide),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.touch_app_outlined),
            title: Text(context.strings.replayEditorTips),
            subtitle: Text(
              context.strings.opensANewBlankDrawingWithGuidedControls,
            ),
            onTap: () => context.push('/editor/new?tips=1'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text(context.strings.privacy),
            subtitle: Text(
              context
                  .strings
                  .drawingsPreferencesAndExportsStayOnThisDeviceCreationWorks,
            ),
          ),
          ref
              .watch(appInfoProvider)
              .when(
                data: (info) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.strings.scribblesong),
                  subtitle: Text(
                    context.strings.appVersion(info.version, info.buildNumber),
                  ),
                ),
                loading: () => ListTile(
                  title: Text(context.strings.scribblesong),
                  subtitle: Text(context.strings.readingBuildInformation),
                ),
                error: (_, _) => ListTile(
                  title: Text(context.strings.scribblesong),
                  subtitle: Text(context.strings.buildInformationUnavailable),
                ),
              ),
        ],
      ),
    );
  }
}
