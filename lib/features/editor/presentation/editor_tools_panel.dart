import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../design_system/creative_panel.dart';
import '../../../l10n/strings.dart';
import '../../../design_system/doodimo_icon.dart';
import 'studio_control.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/brand_colors.dart';

enum EditorToolAction { paper, style, mix, score, clear, tips }

Future<EditorToolAction?> showEditorToolsPanel(
  BuildContext context,
  ProjectDocument document,
) => showCreativePanel<EditorToolAction>(
  context: context,
  builder: (context) {
    final actions = [
      (EditorToolAction.paper, DoodimoGlyph.paper, context.strings.paperColor),
      (
        EditorToolAction.style,
        document.style == DrawingStyle.smooth
            ? DoodimoGlyph.draw
            : DoodimoGlyph.image,
        context.strings.drawingStyle,
      ),
      (EditorToolAction.mix, DoodimoGlyph.sound, context.strings.accompaniment),
      (
        EditorToolAction.score,
        DoodimoGlyph.notes,
        context.strings.describeScore,
      ),
      (
        EditorToolAction.clear,
        DoodimoGlyph.erase,
        context.strings.clearDrawing,
      ),
      (EditorToolAction.tips, DoodimoGlyph.help, context.strings.editorTips),
    ];
    return CreativePanel(
      title: context.strings.editorTools,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(14) > 21
              ? 1
              : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (action, icon, label) in actions)
                SizedBox(
                  width: width,
                  child: ImmersiveSurface(
                    padding: EdgeInsets.zero,
                    radius: 22,
                    accent: action == EditorToolAction.clear
                        ? DoodimoColors.pink
                        : DoodimoColors.violet,
                    child: StudioControl(
                      key: ValueKey('editor-tool-${action.name}'),
                      label: label,
                      fill: Colors.transparent,
                      foreground: Theme.of(context).colorScheme.onSurface,
                      onPressed:
                          action == EditorToolAction.clear &&
                              document.strokes.isEmpty
                          ? null
                          : () => Navigator.pop(context, action),
                      padding: const EdgeInsets.all(16),
                      radius: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DoodimoIcon(icon, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  },
);
