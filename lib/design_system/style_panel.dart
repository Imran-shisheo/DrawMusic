import 'package:flutter/material.dart';

import '../creative_document/document.dart';

Future<DrawingStyle?> showStylePanel(
  BuildContext context,
  DrawingStyle current,
) => showModalBottomSheet<DrawingStyle>(
  context: context,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Drawing style',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final style in DrawingStyle.values)
            ListTile(
              selected: style == current,
              leading: Icon(
                style == DrawingStyle.smooth ? Icons.gesture : Icons.grid_on,
              ),
              title: Text(style == DrawingStyle.smooth ? 'Smooth' : 'Pixel'),
              subtitle: Text(
                style == DrawingStyle.smooth
                    ? 'Original freehand lines'
                    : 'Block shapes on a 40 × 50 grid',
              ),
              trailing: style == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, style),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Styles change how your marks look. Original points and music are preserved.',
            ),
          ),
        ],
      ),
    ),
  ),
);
