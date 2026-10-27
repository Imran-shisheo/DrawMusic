import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/repeating_icon_button.dart';
import '../../../l10n/strings.dart';
import 'accompaniment_panel.dart';
import 'canvas.dart' show scaleName;
import '../../../design_system/doodimo_icon.dart';
import 'studio_control.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/brand_colors.dart';

class EditorMusicSelection {
  const EditorMusicSelection(
    this.tempo,
    this.root,
    this.scale,
    this.expression,
    this.mix, {
    this.rootChanged = false,
    this.scaleChanged = false,
  });
  final int tempo;
  final RootKey root;
  final MusicalScale scale;
  final ExpressionMode expression;
  final AccompanimentMix mix;
  final bool rootChanged, scaleChanged;
}

Future<EditorMusicSelection?> showEditorMusicPanel(
  BuildContext context,
  ProjectDocument document,
) => showCreativePanel<EditorMusicSelection>(
  context: context,
  builder: (context) => _MusicPanel(document),
);

class _MusicPanel extends StatefulWidget {
  const _MusicPanel(this.document);
  final ProjectDocument document;
  @override
  State<_MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<_MusicPanel> {
  late int tempo = widget.document.tempo;
  late RootKey root = widget.document.root;
  late MusicalScale scale = widget.document.scale;
  late ExpressionMode expression = widget.document.expressionMode;
  late AccompanimentMix mix = widget.document.mix;
  bool rootChanged = false, scaleChanged = false;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: CreativePanel(
      title: context.strings.musicSettings,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.cancel),
        ),
        PrismAction(
          label: context.strings.apply,
          icon: const DoodimoIcon(DoodimoGlyph.check),
          onPressed: () => Navigator.pop(
            context,
            EditorMusicSelection(
              tempo,
              root,
              scale,
              expression,
              mix,
              rootChanged: rootChanged,
              scaleChanged: scaleChanged,
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ImmersiveSurface(
            accent: DoodimoColors.cyan,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DoodimoIcon(DoodimoGlyph.tempo, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  context.strings.loopTempo,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RepeatingIconButton(
                      tooltip: context.strings.slower,
                      onStep: tempo > 60 ? () => setState(() => tempo--) : null,
                      icon: Icons.remove_rounded,
                    ),
                    Flexible(
                      child: Text(
                        context.strings.tempoValue(context.formatNumber(tempo)),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    RepeatingIconButton(
                      tooltip: context.strings.faster,
                      onStep: tempo < 200
                          ? () => setState(() => tempo++)
                          : null,
                      icon: Icons.add_rounded,
                    ),
                  ],
                ),
                Slider(
                  min: 60,
                  max: 200,
                  divisions: 140,
                  value: tempo.toDouble(),
                  semanticFormatterCallback: (value) => context.strings
                      .tempoValue(context.formatNumber(value.round())),
                  onChanged: (value) => setState(() => tempo = value.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ImmersiveSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DoodimoIcon(DoodimoGlyph.music, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  context.strings.rootKey,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                DropdownButton<RootKey>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const DoodimoIcon(DoodimoGlyph.chevronDown, size: 20),
                  itemHeight: null,
                  value: root,
                  items: [
                    for (final value in RootKey.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        root = value;
                        rootChanged = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  context.strings.scaleFamily,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                DropdownButton<MusicalScale>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const DoodimoIcon(DoodimoGlyph.chevronDown, size: 20),
                  itemHeight: null,
                  value: scale,
                  selectedItemBuilder: (context) => [
                    for (final value in MusicalScale.values)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(scaleName(context, value)),
                      ),
                  ],
                  items: [
                    for (final value in MusicalScale.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(scaleName(context, value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        scale = value;
                        scaleChanged = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ImmersiveSurface(
            padding: EdgeInsets.zero,
            accent: DoodimoColors.cyan,
            child: StudioControl(
              label: context.strings.accompaniment,
              fill: Colors.transparent,
              foreground: Theme.of(context).colorScheme.onSurface,
              onPressed: () async {
                final chosen = await showAccompanimentPanel(context, mix);
                if (chosen != null && mounted) setState(() => mix = chosen);
              },
              child: Row(
                children: [
                  const DoodimoIcon(DoodimoGlyph.sound),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.strings.accompaniment)),
                  const DoodimoIcon(DoodimoGlyph.arrowUpRight, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ImmersiveSurface(
            padding: const EdgeInsets.all(16),
            accent: DoodimoColors.pink,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.expressiveMode),
              subtitle: Text(context.strings.expressiveModeHelp),
              value: expression == ExpressionMode.expressive,
              onChanged: (enabled) => setState(
                () => expression = enabled
                    ? ExpressionMode.expressive
                    : ExpressionMode.geometry,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
