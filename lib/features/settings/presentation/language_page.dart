import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/strings.dart';
import '../application/settings_controller.dart';

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final busy = state.loading || state.saving;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.languageSelectorTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const LinearProgressIndicator(),
          ListTile(
            title: Text(context.strings.english),
            selected: true,
            leading: const Icon(Icons.language),
            trailing: const Icon(Icons.check),
          ),
          Text(context.strings.languageExplanation),
          if (state.error != null)
            Semantics(liveRegion: true, child: Text(state.error!)),
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
                              state.preferences.copyWith(languageCode: 'en'),
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
