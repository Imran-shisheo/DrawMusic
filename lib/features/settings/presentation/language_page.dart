import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/operation_messages.dart';
import '../../../l10n/strings.dart';
import '../application/settings_controller.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.languageSelectorTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const LinearProgressIndicator(),
          Text(context.strings.languageExplanation),
          for (final language in nativeLanguageNames.entries)
            Semantics(
              selected: selected == language.key,
              child: ListTile(
                key: ValueKey('language-${language.key}'),
                title: Text(language.value),
                selected: selected == language.key,
                leading: const Icon(Icons.language),
                trailing: selected == language.key
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.circle_outlined),
                onTap: busy
                    ? null
                    : () => setState(() => _pending = language.key),
              ),
            ),
          if (state.error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                settingsFailureMessage(context.strings, state.error!),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            children: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: Text(context.strings.cancel),
              ),
              FilledButton(
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
                child: Text(context.strings.apply),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
