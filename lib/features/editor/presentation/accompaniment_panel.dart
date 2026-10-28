import 'package:flutter/material.dart';

import '../../../creative_document/accompaniment.dart';
import '../../../l10n/strings.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/doodimo_icon.dart';

String layerName(BuildContext context, AccompanimentLayer layer) =>
    switch (layer) {
      AccompanimentLayer.bass => context.strings.bass,
      AccompanimentLayer.drumKit => context.strings.drumKit,
      AccompanimentLayer.arpeggio => context.strings.arpeggio,
      AccompanimentLayer.kick => context.strings.kick,
      AccompanimentLayer.snare => context.strings.snare,
      AccompanimentLayer.clap => context.strings.clap,
      AccompanimentLayer.hiHat => context.strings.hiHat,
    };
Future<AccompanimentMix?> showAccompanimentPanel(
  BuildContext context,
  AccompanimentMix initial,
) => showCreativePanel<AccompanimentMix>(
  context: context,
  builder: (context) => _MixPanel(initial),
);

class _MixPanel extends StatefulWidget {
  const _MixPanel(this.initial);
  final AccompanimentMix initial;
  @override
  State<_MixPanel> createState() => _MixPanelState();
}

class _MixPanelState extends State<_MixPanel> {
  late AccompanimentMix mix = widget.initial;
  @override
  Widget build(BuildContext context) => CreativePanel(
    title: context.strings.accompaniment,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.cancel),
      ),
      PrismAction(
        label: context.strings.apply,
        icon: const DoodimoIcon(DoodimoGlyph.check),
        onPressed: () => Navigator.pop(context, mix),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final layer in AccompanimentLayer.values) ...[
          ImmersiveSurface(
            padding: const EdgeInsets.all(8),
            radius: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  secondary: const DoodimoIcon(DoodimoGlyph.sound),
                  title: Text(layerName(context, layer)),
                  value: mix[layer].enabled,
                  onChanged: (enabled) => setState(
                    () => mix = mix.withLayer(
                      layer,
                      mix[layer].copyWith(enabled: enabled),
                    ),
                  ),
                ),
                if (mix[layer].enabled)
                  Row(
                    children: [
                      IconButton(
                        tooltip: mix[layer].muted
                            ? context.strings.unmuteLayer
                            : context.strings.muteLayer,
                        isSelected: mix[layer].muted,
                        onPressed: () => setState(
                          () => mix = mix.withLayer(
                            layer,
                            mix[layer].copyWith(muted: !mix[layer].muted),
                          ),
                        ),
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            const DoodimoIcon(DoodimoGlyph.sound),
                            if (mix[layer].muted)
                              Transform.rotate(
                                angle: -.65,
                                child: Container(
                                  width: 28,
                                  height: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label:
                              '${layerName(context, layer)} ${context.strings.layerLevel}',
                          child: Slider(
                            value: mix[layer].level,
                            divisions: 20,
                            label: context.strings.percentValue(
                              context.formatNumber(
                                (mix[layer].level * 100).round(),
                              ),
                            ),
                            onChanged: (value) => setState(
                              () => mix = mix.withLayer(
                                layer,
                                mix[layer].copyWith(level: value),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}
