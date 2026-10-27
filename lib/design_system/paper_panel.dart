import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';

import '../creative_document/document.dart';

export '../features/backgrounds/presentation/background_panel.dart';

Future<int?> showPaperPanel(BuildContext context, int background) {
  var rgb = background & 0xffffff;
  var opacity = (background >>> 24) / 255;
  final colors = [
    (0xf7f5eb, context.strings.warmPaper),
    (0xeef5f1, context.strings.mintPaper),
    (0xf3eef9, context.strings.lilacPaper),
    (0xffeeee, context.strings.rosePaper),
  ];
  int selected() => (opacity * 255).round() << 24 | rgb;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(context.strings.paperColor),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final (color, name) in colors)
                    IconButton(
                      tooltip: name,
                      isSelected: rgb == color,
                      onPressed: () => update(() => rgb = color),
                      style: IconButton.styleFrom(
                        backgroundColor: Color(0xff000000 | color),
                      ),
                      icon: Icon(
                        rgb == color ? Icons.check : Icons.circle_outlined,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: context.strings.paperPreview,
                child: Container(
                  key: const ValueKey('paper-preview'),
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(opaquePaperColor(selected())),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.strings.paperOpacity(
                  context.formatNumber((opacity * 100).round()),
                ),
              ),
              Slider(
                value: opacity,
                divisions: 100,
                label: context.strings.percentValue(
                  context.formatNumber((opacity * 100).round()),
                ),
                semanticFormatterCallback: (value) =>
                    context.strings.paperOpacitySemantics(
                      context.formatNumber((value * 100).round()),
                    ),
                onChanged: (value) => update(() => opacity = value),
              ),
              Text(
                context
                    .strings
                    .opacityFadesThePaperColorTowardWhiteYourMarksAndMusicStayT,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected()),
            child: Text(context.strings.apply),
          ),
        ],
      ),
    ),
  );
}
