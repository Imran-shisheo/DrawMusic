import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import '../../../design_system/motion.dart';

/// An original educational drawing-to-wave diagram, never an audio waveform,
/// meter or live visualizer. It cannot schedule notes or enter saved artwork.
class DrawToSoundIllustration extends StatelessWidget {
  const DrawToSoundIllustration({super.key});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AspectRatio(
          aspectRatio: 1.8,
          child: RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? 1 : 0, end: 1),
              duration: CreativeMotion.duration(
                context,
                CreativeMotion.forward,
              ),
              curve: CreativeMotion.curve,
              builder: (context, value, child) => CustomPaint(
                painter: _DrawingToWave(
                  value,
                  colors.primary,
                  colors.surfaceContainerHigh,
                  colors.surfaceContainerLow,
                  colors.outlineVariant,
                  colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingToWave extends CustomPainter {
  _DrawingToWave(
    this.reveal,
    this.primary,
    this.tint,
    this.warm,
    this.outline,
    this.ink,
  );
  final double reveal;
  final Color primary, tint, warm, outline, ink;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stage = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    canvas.drawRRect(
      stage,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), [tint, warm]),
    );
    canvas.drawRRect(
      stage.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline,
    );
    canvas.drawRRect(
      stage.deflate(5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: .07),
    );
    canvas.save();
    canvas.clipRRect(stage);
    canvas.drawCircle(
      Offset(w * .78, h * .3),
      w * .45,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * .78, h * .3), w * .45, [
          primary.withValues(alpha: .08),
          primary.withValues(alpha: 0),
        ]),
    );
    canvas.drawLine(
      Offset(w * .5, h * .16),
      Offset(w * .5, h * .84),
      Paint()
        ..color = primary.withValues(alpha: .12)
        ..strokeWidth = 1,
    );
    final drawing = Path()
      ..moveTo(w * .07, h * .67)
      ..cubicTo(w * .13, h * .68, w * .15, h * .25, w * .23, h * .32)
      ..cubicTo(w * .3, h * .39, w * .29, h * .72, w * .37, h * .47);
    final wave = Path()
      ..moveTo(w * .63, h * .5)
      ..cubicTo(w * .67, h * .5, w * .67, h * .22, w * .71, h * .22)
      ..cubicTo(w * .75, h * .22, w * .75, h * .78, w * .79, h * .78)
      ..cubicTo(w * .83, h * .78, w * .83, h * .29, w * .87, h * .29)
      ..cubicTo(w * .91, h * .29, w * .91, h * .5, w * .94, h * .5);
    final pen = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;
    void trace(Path path) {
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * reveal), pen);
      }
    }

    trace(drawing);
    pen.color = ink.withValues(alpha: .85);
    trace(wave);
    final connector = Paint()
      ..color = primary.withValues(alpha: .65 * reveal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * .46, h * .5),
      Offset(w * .54, h * .5),
      connector,
    );
    canvas.drawLine(
      Offset(w * .515, h * .45),
      Offset(w * .54, h * .5),
      connector,
    );
    canvas.drawLine(
      Offset(w * .515, h * .55),
      Offset(w * .54, h * .5),
      connector,
    );
    canvas.drawCircle(
      Offset(w * .23, h * .32),
      5,
      Paint()..color = primary.withValues(alpha: reveal),
    );
    canvas.drawCircle(
      Offset(w * .79, h * .78),
      5,
      Paint()..color = primary.withValues(alpha: reveal),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrawingToWave old) =>
      old.reveal != reveal ||
      old.primary != primary ||
      old.tint != tint ||
      old.warm != warm ||
      old.outline != outline ||
      old.ink != ink;
}
