import 'package:flutter/material.dart';

import '../creative_document/document.dart';

Future<int?> showPaperPanel(BuildContext context, int background) {
  var rgb = background & 0xffffff;
  var opacity = (background >>> 24) / 255;
  const colors = [
    (0xf7f5eb, 'Warm paper'),
    (0xeef5f1, 'Mint paper'),
    (0xf3eef9, 'Lilac paper'),
    (0xffeeee, 'Rose paper'),
  ];
  int selected() => (opacity * 255).round() << 24 | rgb;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Paper color'),
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
                label: 'Paper preview',
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
              Text('Opacity ${(opacity * 100).round()}%'),
              Slider(
                value: opacity,
                divisions: 100,
                label: '${(opacity * 100).round()}%',
                semanticFormatterCallback: (value) =>
                    'Paper opacity ${(value * 100).round()} percent',
                onChanged: (value) => update(() => opacity = value),
              ),
              const Text(
                'Opacity fades the paper color toward white. Your marks and music stay the same.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected()),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}
