import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/operation_messages.dart';
import '../../../l10n/strings.dart';
import '../application/settings_controller.dart';
import '../../../design_system/motion.dart';
import '../../../design_system/brand_colors.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/layout.dart';

// Native names remain identifiable before and after changing the UI language.
const nativeLanguageNames = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'ko': '한국어',
  'ja': '日本語',
  'vi': 'Tiếng Việt',
  'hi': 'हिन्दी',
  'pt': 'Português',
  'th': 'ไทย',
  'fil': 'Filipino',
  'id': 'Bahasa Indonesia',
};

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});
  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  String? _pending;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final busy = state.loading || state.saving;
    final selected = _pending ?? state.preferences.languageCode;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(22) * 2 + 24)
            .clamp(72, double.infinity),
        title: Text(context.strings.languageSelectorTitle, maxLines: 2),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 680 &&
                      MediaQuery.textScalerOf(context).scale(16) < 25
                  ? 2
                  : 1;
              final tileWidth =
                  (constraints.maxWidth - 40 - (columns - 1) * 12) / columns;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(CreativeRadius.card),
                    ),
                    child: Text(
                      context.strings.languageExplanation,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final language in nativeLanguageNames.entries)
                        SizedBox(
                          width: tileWidth,
                          child: Semantics(
                            selected: selected == language.key,
                            child: AnimatedContainer(
                              duration: CreativeMotion.duration(
                                context,
                                CreativeMotion.selection,
                              ),
                              curve: CreativeMotion.curve,
                              decoration: BoxDecoration(
                                color: selected == language.key
                                    ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? colors.primaryContainer
                                          : DoodimoColors.ink)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  bottom: BorderSide(
                                    color: selected == language.key
                                        ? Colors.transparent
                                        : colors.outlineVariant,
                                  ),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  CreativeRadius.card,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  key: ValueKey('language-${language.key}'),
                                  minVerticalPadding: 18,
                                  title: Text(
                                    language.value,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: selected == language.key
                                              ? (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? colors.onPrimaryContainer
                                                    : DoodimoColors.paper)
                                              : colors.onSurface,
                                        ),
                                  ),
                                  selected: selected == language.key,
                                  textColor: colors.onSurface,
                                  selectedColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? colors.onPrimaryContainer
                                      : DoodimoColors.paper,
                                  trailing: selected == language.key
                                      ? DoodimoIcon(
                                          DoodimoGlyph.check,
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? colors.onPrimaryContainer
                                              : DoodimoColors.lime,
                                        )
                                      : const SizedBox.square(dimension: 24),
                                  onTap: busy
                                      ? null
                                      : () => setState(
                                          () => _pending = language.key,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(
                              CreativeRadius.card,
                            ),
                          ),
                          child: Text(
                            settingsFailureMessage(
                              context.strings,
                              state.error!,
                            ),
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: Text(context.strings.cancel),
                  ),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await ref
                                .read(settingsProvider.notifier)
                                .save(
                                  state.preferences.copyWith(
                                    languageCode: selected,
                                  ),
                                );
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                    icon: const DoodimoIcon(DoodimoGlyph.check),
                    label: Text(context.strings.apply),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
