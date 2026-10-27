import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/motion.dart';
import '../../../l10n/strings.dart';
import 'canvas.dart';
import 'instrument_glyph.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/brand_colors.dart';

Future<Instrument?> showEditorVoicePanel(
  BuildContext context,
  Instrument selected,
) => showCreativePanel<Instrument>(
  context: context,
  builder: (context) => CreativePanel(
    title: context.strings.chooseAVoice,
    subtitle: MediaQuery.textScalerOf(context).scale(14) > 21
        ? null
        : context.strings.voiceChooserHint,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final large = MediaQuery.textScalerOf(context).scale(14) > 21;
        final columns = large
            ? 1
            : constraints.maxWidth >= 430
            ? 3
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final instrument in Instrument.values)
              SizedBox(
                width: width,
                child: _VoiceTile(
                  instrument: instrument,
                  selected: selected == instrument,
                ),
              ),
          ],
        );
      },
    ),
  ),
);

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({required this.instrument, required this.selected});
  final Instrument instrument;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = instrumentName(context, instrument);
    void choose() => Navigator.pop(context, instrument);
    return Semantics(
      selected: selected,
      button: true,
      label: name,
      onTap: choose,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: CreativeMotion.duration(context, CreativeMotion.selection),
          constraints: const BoxConstraints(minHeight: 112),
          decoration: BoxDecoration(
            color: selected ? DoodimoColors.ink : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? DoodimoColors.ink
                  : scheme.outlineVariant.withValues(alpha: .45),
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('voice-${instrument.name}'),
              onTap: choose,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: DoodimoColors.paper,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InstrumentGlyph(
                            instrument,
                            color: instrumentColors[instrument.index],
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const DoodimoIcon(
                            DoodimoGlyph.check,
                            color: DoodimoColors.lime,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? DoodimoColors.paper
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
