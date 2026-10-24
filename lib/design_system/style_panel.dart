import 'package:scribblesong/l10n/strings.dart';
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
              context.strings.drawingStyle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final style in DrawingStyle.values)
            ListTile(
              selected: style == current,
              leading: Icon(
                style == DrawingStyle.smooth ? Icons.gesture : Icons.grid_on,
              ),
              title: Text(
                style == DrawingStyle.smooth
                    ? context.strings.smooth
                    : context.strings.pixel,
              ),
              subtitle: Text(
                style == DrawingStyle.smooth
                    ? context.strings.originalFreehandLines
                    : context.strings.blockShapesOnGrid,
              ),
              trailing: style == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, style),
            ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              context
                  .strings
                  .stylesChangeHowYourMarksLookOriginalPointsAndMusicArePrese,
            ),
          ),
        ],
      ),
    ),
  ),
);
