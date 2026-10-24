import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_controller.dart';

class TutorialGate extends ConsumerStatefulWidget {
  const TutorialGate({super.key, required this.child, required this.enabled});
  final Widget child;
  final bool enabled;
  @override
  ConsumerState<TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends ConsumerState<TutorialGate> {
  bool _continuedForNow = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    if (!widget.enabled ||
        _continuedForNow ||
        state.preferences.tutorialCompleted) {
      return widget.child;
    }
    if (state.loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return TutorialPage(
      firstUse: true,
      onContinueForNow: state.error == null
          ? null
          : () => setState(() => _continuedForNow = true),
    );
  }
}

class TutorialPage extends ConsumerWidget {
  const TutorialPage({super.key, this.firstUse = false, this.onContinueForNow});
  final bool firstUse;
  final VoidCallback? onContinueForNow;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    Future<void> complete() async {
      await ref
          .read(settingsProvider.notifier)
          .save(state.preferences.copyWith(tutorialCompleted: true));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          firstUse ? context.strings.welcome : context.strings.creationGuide,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.gesture, size: 72),
          const SizedBox(height: 24),
          Text(
            firstUse
                ? context.strings.welcomeToScribbleSong
                : context.strings.howToCreateALoop,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.draw),
            title: Text(context.strings.drawYourMelody),
            subtitle: Text(
              context
                  .strings
                  .leftToRightFollowsTimeHigherMarksMakeHigherNotesVerticalMa,
            ),
          ),
          ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text(context.strings.chooseAVoice),
            subtitle: Text(
              context
                  .strings
                  .eachNamedColorPlaysItsOwnOriginalInstrumentEraseUndoAndRed,
            ),
          ),
          ListTile(
            leading: Icon(Icons.play_arrow),
            title: Text(context.strings.playAndChangeIt),
            subtitle: Text(
              context
                  .strings
                  .tapPlayToHearTheLoopTempoChangesArriveOnABeatDrawingChange,
            ),
          ),
          ListTile(
            leading: Icon(Icons.save_outlined),
            title: Text(context.strings.keepAndShareYourWork),
            subtitle: Text(
              context
                  .strings
                  .drawingsSaveOnThisDeviceReopenThemFromDraftsOrExportMidiWa,
            ),
          ),
          Text(
            context
                .strings
                .noAccountIsNeededYouCanReplayThisGuideFromSettingsHelp,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (firstUse && state.error != null)
                Semantics(liveRegion: true, child: Text(state.error!)),
              if (firstUse) ...[
                FilledButton(
                  onPressed: state.saving ? null : complete,
                  child: Text(state.saving ? 'Saving…' : 'Start creating'),
                ),
                TextButton(
                  onPressed: state.saving ? null : complete,
                  child: Text(context.strings.skipGuide),
                ),
                if (onContinueForNow != null)
                  TextButton(
                    onPressed: onContinueForNow,
                    child: Text(context.strings.continueForNow),
                  ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.strings.backToSettings),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
