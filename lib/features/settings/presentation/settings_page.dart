import '../../../design_system/immersive_surface.dart';
import '../../../l10n/operation_messages.dart';

import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../design_system/brand_colors.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/brand.dart';
import '../../../design_system/layout.dart';
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
    final colors = Theme.of(context).colorScheme;
    final volume = _volume ?? preferences.previewVolume;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: settingsHeaderHeight(context),
        title: Text(context.strings.settingsHelp, maxLines: 2),
      ),
      body: SceneBackdrop(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                if (state.error != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .35,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _PreferenceNotice(
                        icon: Icons.error_outline,
                        color: colors.errorContainer,
                        foreground: colors.onErrorContainer,
                        bounded: true,
                        message: settingsFailureMessage(
                          context.strings,
                          state.error!,
                        ),
                        action: TextButton(
                          onPressed: busy
                              ? null
                              : () =>
                                    ref.read(settingsProvider.notifier).retry(),
                          child: Text(context.strings.retryPreferences),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                        child: Row(
                          children: [
                            const DoodimoIcon(DoodimoGlyph.settings, size: 40),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                context.strings.uiComfortPreferences,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.recovered)
                        _PreferenceNotice(
                          icon: Icons.history,
                          message: context
                              .strings
                              .recoveredYourPreviousPreferencesYourDrawingsAreUnchanged,
                        ),
                      _SettingsSection(
                        title: context.strings.uiAppearance,
                        featured: true,
                        icon: Icons.palette_outlined,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(context.strings.darkTheme),
                            value: preferences.darkTheme,
                            onChanged: busy
                                ? null
                                : (value) => ref
                                      .read(settingsProvider.notifier)
                                      .save(
                                        preferences.copyWith(darkTheme: value),
                                      ),
                          ),
                        ],
                      ),
                      _SettingsSection(
                        title: context.strings.uiSoundFeedback,
                        icon: Icons.volume_up_outlined,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(context.strings.previewVolume),
                            trailing: Text(
                              context.strings.percentValue(
                                context.formatNumber((volume * 100).round()),
                              ),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: colors.primary),
                            ),
                          ),
                          Slider(
                            value: volume,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            label: context.strings.percentValue(
                              context.formatNumber((volume * 100).round()),
                            ),
                            semanticFormatterCallback: (value) =>
                                context.strings.previewVolumePercent(
                                  context.formatNumber((value * 100).round()),
                                ),
                            onChanged: busy
                                ? null
                                : (value) => setState(() => _volume = value),
                            onChangeEnd: busy
                                ? null
                                : (value) async {
                                    await ref
                                        .read(settingsProvider.notifier)
                                        .save(
                                          preferences.copyWith(
                                            previewVolume: value,
                                          ),
                                        );
                                    if (mounted) setState(() => _volume = null);
                                  },
                          ),
                          if (preferences.previewVolume == 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                              child: Text(
                                context
                                    .strings
                                    .previewIsMutedExportsStillContainMusicAlsoCheckYourDeviceM,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(context.strings.hapticFeedback),
                            value: preferences.haptics,
                            onChanged: busy
                                ? null
                                : (value) => ref
                                      .read(settingsProvider.notifier)
                                      .save(
                                        preferences.copyWith(haptics: value),
                                      ),
                          ),
                          _PreferenceDetails(
                            title: context.strings.uiSoundDetails,
                            children: [
                              Text(
                                context
                                    .strings
                                    .onlyChangesPlaybackInTheAppExportedMusicKeepsItsOriginalLe,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context
                                    .strings
                                    .optionalFeedbackWhenChoosingAVoiceOrChangingTempoAvailabil,
                              ),
                            ],
                          ),
                        ],
                      ),
                      _SettingsSection(
                        title: context.strings.uiAccessibilityMotion,
                        icon: Icons.accessibility_new,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(
                              context.strings.reduceNonessentialMotion,
                            ),
                            value: preferences.reduceMotion,
                            onChanged: busy
                                ? null
                                : (value) => ref
                                      .read(settingsProvider.notifier)
                                      .save(
                                        preferences.copyWith(
                                          reduceMotion: value,
                                        ),
                                      ),
                          ),
                          _PreferenceDetails(
                            title: context.strings.uiMotionDetails,
                            children: [
                              Text(
                                context
                                    .strings
                                    .turnOnToReducePageTransitionsWhenOffFollowsYourDevicePrefe,
                              ),
                            ],
                          ),
                        ],
                      ),
                      _SettingsSection(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const _SettingIcon(Icons.language),
                            title: Text(context.strings.language),
                            subtitle: Text(
                              nativeLanguageNames[preferences.languageCode] ??
                                  nativeLanguageNames['en']!,
                            ),
                            trailing: const DoodimoIcon(
                              DoodimoGlyph.arrowUpRight,
                            ),
                            onTap: () => context.push('/language'),
                          ),
                        ],
                      ),
                      _SettingsSection(
                        title: context.strings.uiHelpInfo,
                        icon: Icons.help_outline,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const DoodimoIcon(DoodimoGlyph.paper),
                            title: Text(context.strings.replayCreationGuide),
                            trailing: const DoodimoIcon(
                              DoodimoGlyph.arrowUpRight,
                            ),
                            onTap: () => context.push('/help'),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const DoodimoIcon(DoodimoGlyph.draw),
                            title: Text(context.strings.replayEditorTips),
                            subtitle: Text(
                              context
                                  .strings
                                  .opensANewBlankDrawingWithGuidedControls,
                            ),
                            trailing: const DoodimoIcon(
                              DoodimoGlyph.arrowUpRight,
                            ),
                            onTap: () => context.push('/editor/new?tips=1'),
                          ),
                          _PreferenceDetails(
                            title: context.strings.privacy,
                            icon: Icons.privacy_tip_outlined,
                            children: [
                              Text(
                                context
                                    .strings
                                    .drawingsPreferencesAndExportsStayOnThisDeviceCreationWorks,
                              ),
                            ],
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const DoodimoIcon(DoodimoGlyph.notes),
                            title: Text(context.strings.uiOpenSourceLicenses),
                            trailing: const DoodimoIcon(
                              DoodimoGlyph.arrowUpRight,
                            ),
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: AppBrand.displayName,
                            ),
                          ),
                          ref
                              .watch(appInfoProvider)
                              .when(
                                data: (info) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  leading: const DoodimoIcon(DoodimoGlyph.help),
                                  title: Text(AppBrand.displayName),
                                  subtitle: Text(
                                    context.strings.appVersion(
                                      info.version,
                                      info.buildNumber,
                                    ),
                                  ),
                                ),
                                loading: () => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(AppBrand.displayName),
                                  subtitle: Text(
                                    context.strings.readingBuildInformation,
                                  ),
                                ),
                                error: (_, _) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(AppBrand.displayName),
                                  subtitle: Text(
                                    context.strings.buildInformationUnavailable,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two title lines can grow with text scaling instead of clipping in a toolbar.
double settingsHeaderHeight(BuildContext context) {
  final style = Theme.of(context).textTheme.titleLarge;
  return (MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 22) *
              (style?.height ?? 1.3) *
              2 +
          16)
      .clamp(72, double.infinity);
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    this.title,
    this.icon,
    this.featured = false,
    required this.children,
  });
  final bool featured;
  final String? title;
  final IconData? icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: featured ? 20 : 4,
        vertical: featured ? 16 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    _SettingIcon(icon!),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!featured) Divider(height: 1, color: colors.outlineVariant),
          ],
          ...children,
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: featured
          ? ImmersiveSurface(
              padding: EdgeInsets.zero,
              accent: DoodimoColors.cyan,
              glow: true,
              child: content,
            )
          : Material(type: MaterialType.transparency, child: content),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DoodimoIcon(
      icon == Icons.language
          ? DoodimoGlyph.language
          : icon == Icons.palette_outlined
          ? DoodimoGlyph.sun
          : icon == Icons.volume_up_outlined
          ? DoodimoGlyph.sound
          : icon == Icons.accessibility_new
          ? DoodimoGlyph.settings
          : DoodimoGlyph.help,
      size: 26,
    ),
  );
}

class _PreferenceDetails extends StatelessWidget {
  const _PreferenceDetails({
    required this.title,
    required this.children,
    this.icon = Icons.info_outline,
  });
  final String title;
  final List<Widget> children;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
    leading: const DoodimoIcon(DoodimoGlyph.help, size: 20),
    title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
    shape: const Border(),
    collapsedShape: const Border(),
    children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ],
  );
}

class _PreferenceNotice extends StatelessWidget {
  const _PreferenceNotice({
    required this.icon,
    required this.message,
    this.action,
    this.color,
    this.foreground,
    this.bounded = false,
  });
  final IconData icon;
  final String message;
  final Widget? action;
  final Color? color, foreground;
  final bool bounded;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DoodimoIcon(
          icon == Icons.history ? DoodimoGlyph.replay : DoodimoGlyph.help,
          color: foreground ?? colors.onSecondaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: foreground ?? colors.onSecondaryContainer),
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? colors.secondaryContainer,
            borderRadius: BorderRadius.circular(CreativeRadius.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bounded)
                Flexible(child: SingleChildScrollView(child: body))
              else
                body,
              if (action != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: action!),
            ],
          ),
        ),
      ),
    );
  }
}
