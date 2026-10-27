import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original Doodimo line glyphs drawn on a shared 24-unit grid. These are vector
/// paths authored for this project, not wrappers around a third-party icon font.
enum DoodimoGlyph {
  home,
  library,
  settings,
  add,
  back,
  close,
  draw,
  erase,
  undo,
  redo,
  play,
  pause,
  replay,
  tempo,
  voice,
  music,
  paper,
  export,
  save,
  image,
  sound,
  video,
  notes,
  check,
  arrowUpRight,
  more,
  chevronDown,
  moon,
  sun,
  help,
  language,
}

class DoodimoIcon extends StatelessWidget {
  const DoodimoIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });
  final DoodimoGlyph glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final inherited = IconTheme.of(context);
    final ink =
        color ?? inherited.color ?? Theme.of(context).colorScheme.onSurface;
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DoodimoGlyphPainter(
          glyph,
          ink.withValues(alpha: ink.a * (inherited.opacity ?? 1)),
          Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: icon)
        : Semantics(
            label: semanticLabel,
            image: true,
            child: ExcludeSemantics(child: icon),
          );
  }
}

class _DoodimoGlyphPainter extends CustomPainter {
  const _DoodimoGlyphPainter(this.glyph, this.color, this.rtl);
  final DoodimoGlyph glyph;
  final Color color;
  final bool rtl;
  static const directional = {
    DoodimoGlyph.back,
    DoodimoGlyph.undo,
    DoodimoGlyph.redo,
    DoodimoGlyph.arrowUpRight,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    if (rtl && directional.contains(glyph)) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
    void path(Path p) => canvas.drawPath(p, stroke);
    void dot(double x, double y, [double radius = 1.5]) =>
        canvas.drawCircle(Offset(x, y), radius, fill);
    void rounded(
      double x,
      double y,
      double w,
      double h, [
      double radius = 2.5,
    ]) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      stroke,
    );
    switch (glyph) {
      case DoodimoGlyph.home:
        path(
          Path()
            ..moveTo(3.5, 11)
            ..quadraticBezierTo(12, 1, 20.5, 11)
            ..lineTo(20.5, 18.5)
            ..quadraticBezierTo(20.5, 21, 18, 21)
            ..lineTo(6, 21)
            ..quadraticBezierTo(3.5, 21, 3.5, 18.5)
            ..close(),
        );
        path(
          Path()
            ..moveTo(8, 21)
            ..lineTo(8, 15.5)
            ..cubicTo(8, 10, 12, 12, 12, 15)
            ..cubicTo(12, 18, 16, 18, 16, 14)
            ..lineTo(16, 21),
        );
      case DoodimoGlyph.library:
        path(
          Path()
            ..moveTo(6, 3)
            ..lineTo(14.5, 3)
            ..lineTo(20, 8.5)
            ..lineTo(20, 18.5)
            ..quadraticBezierTo(20, 21, 17.5, 21)
            ..lineTo(6, 21)
            ..quadraticBezierTo(3.5, 21, 3.5, 18.5)
            ..lineTo(3.5, 5.5)
            ..quadraticBezierTo(3.5, 3, 6, 3)
            ..close(),
        );
        path(
          Path()
            ..moveTo(14.5, 3.5)
            ..lineTo(14.5, 8.5)
            ..lineTo(19.5, 8.5),
        );
        path(
          Path()
            ..moveTo(7, 15)
            ..cubicTo(10, 11, 11, 20, 15, 15)
            ..quadraticBezierTo(17, 13, 17, 16),
        );
      case DoodimoGlyph.settings:
        for (final (x, y) in [(5.5, 8.0), (12.0, 16.0), (18.5, 7.0)]) {
          line(x, 3.5, x, y - 2.5);
          line(x, y + 2.5, x, 20.5);
          canvas.drawCircle(Offset(x, y), 2.5, stroke);
        }
      case DoodimoGlyph.add:
        line(12, 4.5, 12, 19.5);
        line(4.5, 12, 19.5, 12);
      case DoodimoGlyph.back:
        path(
          Path()
            ..moveTo(19.5, 12)
            ..lineTo(4.5, 12)
            ..moveTo(10.5, 5.5)
            ..lineTo(4, 12)
            ..lineTo(10.5, 18.5),
        );
      case DoodimoGlyph.close:
        line(5.5, 5.5, 18.5, 18.5);
        line(18.5, 5.5, 5.5, 18.5);
      case DoodimoGlyph.draw:
        path(
          Path()
            ..moveTo(3, 19)
            ..cubicTo(6, 12, 7, 21, 10, 15)
            ..quadraticBezierTo(12, 12, 14, 13),
        );
        path(
          Path()
            ..moveTo(11, 11)
            ..lineTo(17.5, 3.5)
            ..quadraticBezierTo(18.5, 2.5, 19.5, 3.5)
            ..lineTo(21, 5)
            ..quadraticBezierTo(22, 6, 21, 7)
            ..lineTo(14.5, 14.5)
            ..lineTo(10, 15.5)
            ..close()
            ..moveTo(16.5, 5)
            ..lineTo(20, 8),
        );
      case DoodimoGlyph.erase:
        path(
          Path()
            ..moveTo(4, 14)
            ..lineTo(12.5, 4.5)
            ..quadraticBezierTo(14, 3, 15.5, 4.5)
            ..lineTo(20.5, 9)
            ..quadraticBezierTo(22, 10.5, 20.5, 12)
            ..lineTo(13.5, 20)
            ..lineTo(8.5, 20)
            ..close()
            ..moveTo(8.5, 9)
            ..lineTo(17, 16.5),
        );
        line(8.5, 20.5, 21, 20.5);
      case DoodimoGlyph.undo:
      case DoodimoGlyph.redo:
        if (glyph == DoodimoGlyph.redo) {
          canvas.translate(24, 0);
          canvas.scale(-1, 1);
        }
        path(
          Path()
            ..moveTo(8, 5.5)
            ..lineTo(3, 10.5)
            ..lineTo(8, 15.5)
            ..moveTo(3.5, 10.5)
            ..cubicTo(16, 3, 23, 11, 19.5, 19),
        );
      case DoodimoGlyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 4.8)
            ..quadraticBezierTo(6.8, 4, 6.8, 5.7)
            ..lineTo(6.8, 18.3)
            ..quadraticBezierTo(6.8, 20, 8, 19.2)
            ..lineTo(19.2, 12.9)
            ..quadraticBezierTo(20.8, 12, 19.2, 11.1)
            ..close(),
          fill,
        );
      case DoodimoGlyph.pause:
        for (final x in [7.0, 14.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 5, 3.5, 14),
              const Radius.circular(1.3),
            ),
            fill,
          );
        }
      case DoodimoGlyph.replay:
        path(
          Path()
            ..moveTo(18, 6)
            ..cubicTo(13, 1, 5, 4, 3.5, 10.5)
            ..cubicTo(2, 18, 10.5, 23, 17, 18)
            ..cubicTo(21, 15, 21.5, 10, 18, 6)
            ..moveTo(18, 2.5)
            ..lineTo(18, 6.5)
            ..lineTo(14, 6.5),
        );
      case DoodimoGlyph.tempo:
        path(
          Path()
            ..moveTo(5, 20.5)
            ..lineTo(9, 4)
            ..lineTo(15, 4)
            ..lineTo(19, 20.5)
            ..close(),
        );
        line(12, 16, 18.5, 7);
        dot(12, 16, 1.4);
        line(8, 20.5, 16, 20.5);
      case DoodimoGlyph.voice:
        path(
          Path()
            ..moveTo(3, 15)
            ..cubicTo(4, 9, 7, 4, 10, 5)
            ..cubicTo(15, 7, 5, 21, 13, 19)
            ..cubicTo(18, 18, 17, 6, 21, 9),
        );
        dot(3, 15, 1.1);
        dot(21, 9, 1.1);
      case DoodimoGlyph.music:
        path(
          Path()
            ..moveTo(8, 17.5)
            ..lineTo(8, 6)
            ..lineTo(19, 3.5)
            ..lineTo(19, 15.5),
        );
        canvas.drawOval(const Rect.fromLTWH(2.5, 16, 5.5, 4), fill);
        canvas.drawOval(const Rect.fromLTWH(13.5, 14, 5.5, 4), fill);
      case DoodimoGlyph.paper:
        rounded(3, 4, 18, 16, 3);
        path(
          Path()
            ..moveTo(6, 14)
            ..cubicTo(8, 9, 10, 19, 13, 13)
            ..cubicTo(15, 9, 17, 16, 18, 12),
        );
      case DoodimoGlyph.export:
        path(
          Path()
            ..moveTo(4, 14)
            ..lineTo(4, 19)
            ..quadraticBezierTo(4, 21, 6, 21)
            ..lineTo(18, 21)
            ..quadraticBezierTo(20, 21, 20, 19)
            ..lineTo(20, 14),
        );
        path(
          Path()
            ..moveTo(12, 16)
            ..lineTo(12, 3)
            ..moveTo(7, 8)
            ..lineTo(12, 3)
            ..lineTo(17, 8),
        );
      case DoodimoGlyph.save:
        path(
          Path()
            ..moveTo(6, 3)
            ..lineTo(16, 3)
            ..lineTo(21, 8)
            ..lineTo(21, 18)
            ..quadraticBezierTo(21, 21, 18, 21)
            ..lineTo(6, 21)
            ..quadraticBezierTo(3, 21, 3, 18)
            ..lineTo(3, 6)
            ..quadraticBezierTo(3, 3, 6, 3)
            ..close(),
        );
        path(
          Path()
            ..moveTo(8, 3.5)
            ..lineTo(8, 10)
            ..lineTo(16, 10)
            ..lineTo(16, 3.5),
        );
        rounded(7, 14, 10, 7, 1.8);
      case DoodimoGlyph.image:
        rounded(3, 4, 18, 16, 3);
        dot(16.5, 8, 1.5);
        path(
          Path()
            ..moveTo(3.5, 17.5)
            ..lineTo(8.5, 12)
            ..quadraticBezierTo(9.5, 11, 10.5, 12)
            ..lineTo(14, 16)
            ..lineTo(17.5, 12.5)
            ..lineTo(20.5, 16),
        );
      case DoodimoGlyph.sound:
        for (final (x, y) in [
          (4.5, 9.0),
          (9.5, 5.5),
          (14.5, 3.5),
          (19.5, 7.0),
        ]) {
          line(x, y, x, 24 - y);
        }
      case DoodimoGlyph.video:
        rounded(2.5, 5.5, 14, 13, 3);
        path(
          Path()
            ..moveTo(16.5, 9)
            ..lineTo(21.5, 6.5)
            ..lineTo(21.5, 17.5)
            ..lineTo(16.5, 15),
        );
      case DoodimoGlyph.notes:
        rounded(4, 3, 16, 18, 3);
        line(8, 7.5, 16, 7.5);
        line(8, 11.5, 12, 11.5);
        path(
          Path()
            ..moveTo(15, 12)
            ..lineTo(15, 17)
            ..quadraticBezierTo(17, 17, 18, 15),
        );
        canvas.drawOval(const Rect.fromLTWH(10, 16, 5, 3.5), fill);
      case DoodimoGlyph.check:
        path(
          Path()
            ..moveTo(4.5, 12)
            ..lineTo(9.5, 17)
            ..lineTo(19.5, 6),
        );
      case DoodimoGlyph.arrowUpRight:
        path(
          Path()
            ..moveTo(5, 19)
            ..lineTo(19, 5)
            ..moveTo(9, 5)
            ..lineTo(19, 5)
            ..lineTo(19, 15),
        );
      case DoodimoGlyph.more:
        for (final x in [5.0, 12.0, 19.0]) {
          dot(x, 12, 1.6);
        }
      case DoodimoGlyph.chevronDown:
        path(
          Path()
            ..moveTo(5.5, 9)
            ..lineTo(12, 15.5)
            ..lineTo(18.5, 9),
        );
      case DoodimoGlyph.moon:
        path(
          Path()
            ..moveTo(16.5, 3.5)
            ..cubicTo(7.5, 2.5, 1.5, 12, 7, 18.5)
            ..cubicTo(12, 24, 20.5, 19, 21, 12.5)
            ..cubicTo(14, 17, 8, 9, 16.5, 3.5)
            ..close(),
        );
      case DoodimoGlyph.sun:
        canvas.drawCircle(const Offset(12, 12), 4, stroke);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          line(
            12 + 8 * math.cos(angle),
            12 + 8 * math.sin(angle),
            12 + 10 * math.cos(angle),
            12 + 10 * math.sin(angle),
          );
        }
      case DoodimoGlyph.help:
        rounded(3, 3, 18, 18, 7);
        path(
          Path()
            ..moveTo(9, 8.5)
            ..cubicTo(10, 5, 16, 6, 15, 9)
            ..cubicTo(14.5, 11, 12, 10.5, 12, 14),
        );
        dot(12, 17.5, 1);
      case DoodimoGlyph.language:
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawOval(const Rect.fromLTWH(8, 3, 8, 18), stroke);
        line(3.5, 12, 20.5, 12);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DoodimoGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.rtl != rtl;
}
