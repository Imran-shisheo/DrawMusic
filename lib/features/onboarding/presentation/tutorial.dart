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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      appBar: AppBar(title: Text(firstUse ? 'Welcome' : 'Creation guide')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.gesture, size: 72),
          const SizedBox(height: 24),
          Text(
            firstUse ? 'Welcome to ScribbleSong' : 'How to create a loop',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.draw),
            title: Text('Draw your melody'),
            subtitle: Text(
              'Left to right follows time. Higher marks make higher notes. Vertical marks can form chords.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Choose a voice'),
            subtitle: Text(
              'Each named color plays its own original instrument. Erase, Undo and Redo to explore.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.play_arrow),
            title: Text('Play and change it'),
            subtitle: Text(
              'Tap Play to hear the loop. Tempo changes arrive on a beat; drawing changes arrive on a loop. Pause and Replay keep you in control.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.save_outlined),
            title: Text('Keep and share your work'),
            subtitle: Text(
              'Drawings save on this device. Reopen them from Drafts, or export MIDI, WAV and MP4. Sharing starts only when you choose it.',
            ),
          ),
          const Text(
            'No account is needed. You can replay this guide from Settings & help.',
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
                  child: const Text('Skip guide'),
                ),
                if (onContinueForNow != null)
                  TextButton(
                    onPressed: onContinueForNow,
                    child: const Text('Continue for now'),
                  ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to settings'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
