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
    final dark = Theme.of(context).brightness == Brightness.dark;
    void choose() => Navigator.pop(context, instrument);
    return Semantics(
      selected: selected,
      button: true,
      label: name,
      onTap: choose,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: CreativeMotion.duration(context, CreativeMotion.selection),
          constraints: const BoxConstraints(minHeight: 136),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      selected
                          ? const Color(0xff37315d)
                          : const Color(0xff202746),
                      const Color(0xff11172c),
                    ]
                  : [
                      Colors.white,
                      selected
                          ? const Color(0xffe3ddff)
                          : const Color(0xffe9edff),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (dark ? DoodimoColors.cyan : scheme.primary)
                  : DoodimoColors.violet.withValues(alpha: .35),
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InstrumentGlyph(instrument, size: 56),
                            const SizedBox(height: 6),
                            Container(
                              width: 30,
                              height: 3,
                              decoration: BoxDecoration(
                                color: instrumentColors[instrument.index],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (selected)
                          const DoodimoIcon(
                            DoodimoGlyph.check,
                            color: DoodimoColors.cyan,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: scheme.onSurface),
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
