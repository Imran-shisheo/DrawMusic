import 'package:flutter/material.dart';

import '../../../creative_document/accompaniment.dart';
import '../../../l10n/strings.dart';

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
) => showModalBottomSheet<AccompanimentMix>(
  context: context,
  isScrollControlled: true,
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
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.strings.accompaniment,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final layer in AccompanimentLayer.values)
                    Column(
                      children: [
                        SwitchListTile(
                          title: Text(layerName(context, layer)),
                          value: mix[layer].enabled,
                          onChanged: (v) => setState(
                            () => mix = mix.withLayer(
                              layer,
                              mix[layer].copyWith(enabled: v),
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
                                    mix[layer].copyWith(
                                      muted: !mix[layer].muted,
                                    ),
                                  ),
                                ),
                                icon: Icon(
                                  mix[layer].muted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
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
                                    onChanged: (v) => setState(
                                      () => mix = mix.withLayer(
                                        layer,
                                        mix[layer].copyWith(level: v),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, mix),
                  child: Text(context.strings.apply),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
