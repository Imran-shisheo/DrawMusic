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
import '../../../design_system/creative_components.dart';
import '../../../design_system/motion.dart';

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
      return Scaffold(
        body: SceneBackdrop(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SketchMark(size: 64),
                    const SizedBox(height: 20),
                    Text(
                      AppBrand.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: 16, top: 3),
                      child: SketchMark(size: 44),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          firstUse
                              ? context.strings.welcomeToBrand(
                                  AppBrand.displayName,
                                )
                              : context.strings.howToCreateALoop,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ],
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
                  _GuideStep(
                    index: i,
                    title: steps[i].$2,
                    detail: steps[i].$3,
                    initiallyExpanded: !firstUse && i == 0,
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

class _GuideStep extends StatefulWidget {
  const _GuideStep({
    required this.index,
    required this.title,
    required this.detail,
    required this.initiallyExpanded,
  });
  final int index;
  final String title, detail;
  final bool initiallyExpanded;
  @override
  State<_GuideStep> createState() => _GuideStepState();
}

class _GuideStepState extends State<_GuideStep> {
  late bool _expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final numberSize = MediaQuery.textScalerOf(context)
        .scale(type.titleLarge?.fontSize ?? 22);
    final numberExtent = (numberSize * 1.6).clamp(36.0, double.infinity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ImmersiveSurface(
        padding: EdgeInsets.zero,
        radius: 20,
        accent: colors.outlineVariant,
        child: ExpansionTile(
          key: ValueKey('creation-guide-step-${widget.index}'),
          initiallyExpanded: widget.initiallyExpanded,
          maintainState: true,
          onExpansionChanged: (value) => setState(() => _expanded = value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: const Border(),
          collapsedShape: const Border(),
          trailing: AnimatedRotation(
            turns: _expanded ? .5 : 0,
            duration: CreativeMotion.duration(
              context,
              CreativeMotion.selection,
            ),
            curve: CreativeMotion.curve,
            child: const DoodimoIcon(DoodimoGlyph.chevronDown, size: 20),
          ),
          leading: ExcludeSemantics(
            child: SizedBox.square(
              dimension: numberExtent,
              child: Center(
                child: Text(
                  context.formatNumber(widget.index + 1).padLeft(2, '0'),
                  style: type.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ),
          title: Text(widget.title, style: type.titleMedium),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(widget.detail, style: type.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}
