import 'package:flutter/material.dart';

import '../creative_document/document.dart';
import '../l10n/strings.dart';
import 'creative_panel.dart';
import 'doodimo_icon.dart';
import 'immersive_surface.dart';

Future<DrawingStyle?> showStylePanel(
  BuildContext context,
  DrawingStyle current, {
  Rect? sourceBounds,
}) => showCreativePanel<DrawingStyle>(
  context: context,
  sourceBounds: sourceBounds,
  builder: (context) => CreativePanel(
    title: context.strings.drawingStyle,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final style in DrawingStyle.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _StyleMaterial(style: style, selected: style == current),
            ),
          Text(
            context
                .strings
                .stylesChangeHowYourMarksLookOriginalPointsAndMusicArePrese,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  ),
);

class _StyleMaterial extends StatelessWidget {
  const _StyleMaterial({required this.style, required this.selected});
  final DrawingStyle style;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = style == DrawingStyle.smooth
        ? context.strings.smooth
        : context.strings.pixel;
    return Semantics(
      label:
          '$title. ${style == DrawingStyle.smooth ? context.strings.originalFreehandLines : context.strings.blockShapesOnGrid}',
      excludeSemantics: true,
      button: true,
      selected: selected,
      onTap: () => Navigator.pop(context, style),
      child: ImmersiveSurface(
        padding: EdgeInsets.zero,
        radius: 16,
        glow: selected,
        accent: selected ? scheme.primary : scheme.outline,
        child: InkWell(
          onTap: () => Navigator.pop(context, style),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DoodimoIcon(
                      style == DrawingStyle.smooth
                          ? DoodimoGlyph.draw
                          : DoodimoGlyph.image,
                      size: 28,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (selected)
                      DoodimoIcon(DoodimoGlyph.check, color: scheme.secondary),
                  ],
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(
                  child: SizedBox(
                    height: 62,
                    child: CustomPaint(
                      painter: _StyleSample(
                        style,
                        scheme.primary,
                        scheme.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  style == DrawingStyle.smooth
                      ? context.strings.originalFreehandLines
                      : context.strings.blockShapesOnGrid,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Original display illustration, not an audio meter or saved document layer.
class _StyleSample extends CustomPainter {
  const _StyleSample(this.style, this.primary, this.secondary);
  final DrawingStyle style;
  final Color primary, secondary;
  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()
      ..moveTo(6, size.height * .72)
      ..cubicTo(
        size.width * .22,
        -8,
        size.width * .33,
        size.height * 1.15,
        size.width * .51,
        size.height * .4,
      )
      ..cubicTo(
        size.width * .72,
        -8,
        size.width * .76,
        size.height * .95,
        size.width - 6,
        size.height * .25,
      );
    final paint = Paint()
      ..shader = LinearGradient(colors: [primary, secondary])
          .createShader(Offset.zero & size)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (style == DrawingStyle.smooth) {
      canvas.drawPath(line, paint);
      return;
    }
    for (final metric in line.computeMetrics()) {
      final cells = <int>{};
      for (var distance = 0.0; distance < metric.length; distance += 2) {
        final position = metric.getTangentForOffset(distance)!.position;
        final x = (position.dx / 10).floor(), y = (position.dy / 10).floor();
        cells.add(y * 1000 + x);
      }
      paint.style = PaintingStyle.fill;
      for (final cell in cells) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH((cell % 1000) * 10.0, (cell ~/ 1000) * 10.0, 8, 8),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StyleSample oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
