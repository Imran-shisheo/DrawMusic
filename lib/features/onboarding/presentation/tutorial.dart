import '../../../design_system/immersive_surface.dart';
import '../../../l10n/operation_messages.dart';

import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_controller.dart';
import 'draw_to_sound_illustration.dart';
import '../../../design_system/brand.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/layout.dart';

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
    final colors = Theme.of(context).colorScheme;
    Future<void> complete() async {
      await ref
          .read(settingsProvider.notifier)
          .save(state.preferences.copyWith(tutorialCompleted: true));
    }

    final steps = <(IconData, String, String)>[
      (
        Icons.draw_outlined,
        context.strings.drawYourMelody,
        context
            .strings
            .leftToRightFollowsTimeHigherMarksMakeHigherNotesVerticalMa,
      ),
      (
        Icons.palette_outlined,
        context.strings.chooseAVoice,
        context
            .strings
            .eachNamedColorPlaysItsOwnOriginalInstrumentEraseUndoAndRed,
      ),
      (
        Icons.play_arrow_rounded,
        context.strings.playAndChangeIt,
        context
            .strings
            .tapPlayToHearTheLoopTempoChangesArriveOnABeatDrawingChange,
      ),
      (
        Icons.bookmark_border_rounded,
        context.strings.keepAndShareYourWork,
        context
            .strings
            .drawingsSaveOnThisDeviceReopenThemFromDraftsOrExportMidiWa,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(22) * 2 + 24)
            .clamp(72, double.infinity),
        title: Text(
          firstUse ? context.strings.welcome : context.strings.creationGuide,
          maxLines: 2,
        ),
      ),
      body: SceneBackdrop(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              children: [
                if (firstUse && state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
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
                          settingsFailureMessage(context.strings, state.error!),
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    firstUse
                        ? context.strings.welcomeToBrand(AppBrand.displayName)
                        : context.strings.howToCreateALoop,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.strings.uiWelcomeSummary,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: DrawToSoundIllustration(),
                ),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      key: ValueKey('creation-guide-step-$i'),
                      initiallyExpanded: !firstUse && i == 0,
                      maintainState: true,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      shape: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                      collapsedShape: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                      leading: ExcludeSemantics(
                        child: SizedBox(
                          width: 36,
                          child: Text(
                            context.formatNumber(i + 1).padLeft(2, '0'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.primary,
                                ),
                          ),
                        ),
                      ),
                      title: Text(
                        steps[i].$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            steps[i].$3,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  context
                      .strings
                      .noAccountIsNeededYouCanReplayThisGuideFromSettingsHelp,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .45,
            ),
            child: SingleChildScrollView(
              child: Align(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 712),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (firstUse) ...[
                        PrismAction(
                          onPressed: state.saving ? null : complete,
                          busy: state.saving,
                          icon: const DoodimoIcon(DoodimoGlyph.arrowUpRight),
                          label: state.saving
                              ? context.strings.saving
                              : context.strings.startCreating,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: state.saving ? null : complete,
                          child: Text(
                            context.strings.skipGuide,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (onContinueForNow != null)
                          TextButton(
                            onPressed: onContinueForNow,
                            child: Text(
                              context.strings.continueForNow,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ] else
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            context.strings.backToSettings,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
