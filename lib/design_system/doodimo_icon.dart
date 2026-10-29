import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original consistent24-unit outline glyphs, authored for the graphite studio.
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
  camera,
  rotate,
  mirror,
  crop,
  delete,
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
    final opacity = (ink.a * (inherited.opacity ?? 1)).clamp(0.0, 1.0);
    Widget paint = CustomPaint(
      painter: _OutlineGlyph(
        glyph,
        ink.withValues(alpha: 1),
        Directionality.of(context) == TextDirection.rtl,
      ),
    );
    // Disabled alpha belongs to the complete glyph: crossing strokes must not
    // accumulate into a deceptively enabled center.
    if (opacity < 1) paint = Opacity(opacity: opacity, child: paint);
    final icon = SizedBox.square(dimension: size, child: paint);
    return semanticLabel == null
        ? ExcludeSemantics(child: icon)
        : Semantics(
            label: semanticLabel,
            image: true,
            child: ExcludeSemantics(child: icon),
          );
  }
}

class _OutlineGlyph extends CustomPainter {
  const _OutlineGlyph(this.glyph, this.color, this.rtl);
  final DoodimoGlyph glyph;
  final Color color;
  final bool rtl;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 24, size.height / 24);
    if (rtl &&
        {
          DoodimoGlyph.back,
          DoodimoGlyph.undo,
          DoodimoGlyph.redo,
          DoodimoGlyph.arrowUpRight,
        }.contains(glyph)) {
      c.translate(24, 0);
      c.scale(-1, 1);
    }
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double a, double b) =>
        c.drawLine(Offset(x, y), Offset(a, b), p);
    void circle(double x, double y, double r) =>
        c.drawCircle(Offset(x, y), r, p);
    void box(double x, double y, double w, double h, [double r = 2]) =>
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
          p,
        );
    void path(Path v) => c.drawPath(v, p);
    switch (glyph) {
      case DoodimoGlyph.home:
        for (final x in [3.5, 13.5]) {
          for (final y in [3.5, 13.5]) {
            box(x, y, 7, 7, 1.4);
          }
        }
      case DoodimoGlyph.library:
        path(
          Path()
            ..moveTo(3, 8)
            ..lineTo(3, 5)
            ..quadraticBezierTo(3, 3, 5, 3)
            ..lineTo(9, 3)
            ..lineTo(12, 6)
            ..lineTo(19, 6)
            ..quadraticBezierTo(21, 6, 21, 8)
            ..lineTo(21, 19)
            ..quadraticBezierTo(21, 21, 19, 21)
            ..lineTo(5, 21)
            ..quadraticBezierTo(3, 21, 3, 19)
            ..close(),
        );
        line(3, 9, 21, 9);
      case DoodimoGlyph.settings:
        circle(12, 12, 3);
        path(
          Path()
            ..moveTo(9, 3)
            ..lineTo(15, 3)
            ..lineTo(16, 6)
            ..lineTo(19, 6)
            ..lineTo(21, 10)
            ..lineTo(19, 12)
            ..lineTo(21, 14)
            ..lineTo(19, 18)
            ..lineTo(16, 18)
            ..lineTo(15, 21)
            ..lineTo(9, 21)
            ..lineTo(8, 18)
            ..lineTo(5, 18)
            ..lineTo(3, 14)
            ..lineTo(5, 12)
            ..lineTo(3, 10)
            ..lineTo(5, 6)
            ..lineTo(8, 6)
            ..close(),
        );
      case DoodimoGlyph.add:
        line(12, 4, 12, 20);
        line(4, 12, 20, 12);
      case DoodimoGlyph.back:
        path(
          Path()
            ..moveTo(15, 4)
            ..lineTo(7, 12)
            ..lineTo(15, 20),
        );
      case DoodimoGlyph.close:
        line(5, 5, 19, 19);
        line(19, 5, 5, 19);
      case DoodimoGlyph.draw:
        path(
          Path()
            ..moveTo(6, 16)
            ..lineTo(17, 3)
            ..quadraticBezierTo(18, 2, 20, 4)
            ..quadraticBezierTo(22, 6, 21, 7)
            ..lineTo(9, 18)
            ..close(),
        );
        path(
          Path()
            ..moveTo(9, 18)
            ..quadraticBezierTo(10, 22, 3, 21)
            ..quadraticBezierTo(5, 19, 4, 18)
            ..quadraticBezierTo(4, 15, 6, 16),
        );
      case DoodimoGlyph.erase:
        path(
          Path()
            ..moveTo(3, 15)
            ..lineTo(13, 4)
            ..quadraticBezierTo(14, 3, 15, 4)
            ..lineTo(21, 10)
            ..quadraticBezierTo(22, 11, 21, 12)
            ..lineTo(12, 21)
            ..lineTo(9, 21)
            ..close(),
        );
        line(8, 10, 16, 17);
        line(12, 21, 21, 21);
      case DoodimoGlyph.undo:
        path(
          Path()
            ..moveTo(4, 10)
            ..lineTo(13, 10)
            ..cubicTo(23, 10, 23, 21, 13, 21),
        );
        path(
          Path()
            ..moveTo(9, 5)
            ..lineTo(4, 10)
            ..lineTo(9, 15),
        );
      case DoodimoGlyph.redo:
        path(
          Path()
            ..moveTo(20, 10)
            ..lineTo(11, 10)
            ..cubicTo(1, 10, 1, 21, 11, 21),
        );
        path(
          Path()
            ..moveTo(15, 5)
            ..lineTo(20, 10)
            ..lineTo(15, 15),
        );
      case DoodimoGlyph.play:
        path(
          Path()
            ..moveTo(7, 4)
            ..lineTo(20, 12)
            ..lineTo(7, 20)
            ..close(),
        );
      case DoodimoGlyph.pause:
        box(5, 4, 4, 16, 1);
        box(15, 4, 4, 16, 1);
      case DoodimoGlyph.replay:
        c.drawArc(
          const Rect.fromLTWH(4, 4, 16, 16),
          -.5,
          math.pi * 1.75,
          false,
          p,
        );
        path(
          Path()
            ..moveTo(21, 3)
            ..lineTo(21, 9)
            ..lineTo(15, 9),
        );
      case DoodimoGlyph.tempo:
        circle(12, 13, 8);
        line(12, 13, 15, 8);
        line(9, 2, 15, 2);
      case DoodimoGlyph.voice:
        for (final y in [6.0, 12.0, 18.0]) {
          path(
            Path()
              ..moveTo(3, y)
              ..cubicTo(8, y - 5, 12, y + 5, 17, y)
              ..quadraticBezierTo(20, y - 3, 22, y),
          );
        }
      case DoodimoGlyph.music:
      case DoodimoGlyph.notes:
        path(
          Path()
            ..moveTo(9, 17)
            ..lineTo(9, 5)
            ..lineTo(20, 3)
            ..lineTo(20, 15),
        );
        c.drawOval(const Rect.fromLTWH(3, 16, 6, 5), p);
        c.drawOval(const Rect.fromLTWH(14, 14, 6, 5), p);
      case DoodimoGlyph.paper:
        box(4, 3, 16, 18);
        line(8, 8, 16, 8);
        line(8, 12, 16, 12);
        line(8, 16, 13, 16);
      case DoodimoGlyph.export:
        path(
          Path()
            ..moveTo(5, 10)
            ..lineTo(5, 21)
            ..lineTo(19, 21)
            ..lineTo(19, 10),
        );
        line(12, 16, 12, 3);
        path(
          Path()
            ..moveTo(7, 8)
            ..lineTo(12, 3)
            ..lineTo(17, 8),
        );
      case DoodimoGlyph.save:
        path(
          Path()
            ..moveTo(3, 3)
            ..lineTo(17, 3)
            ..lineTo(21, 7)
            ..lineTo(21, 21)
            ..lineTo(3, 21)
            ..close(),
        );
        box(7, 3, 9, 6, 0);
        box(7, 14, 10, 7, 1);
      case DoodimoGlyph.image:
        box(3, 3, 18, 18);
        circle(8, 8, 1.5);
        path(
          Path()
            ..moveTo(3, 17)
            ..lineTo(9, 11)
            ..lineTo(13, 15)
            ..lineTo(17, 10)
            ..lineTo(21, 14),
        );
      case DoodimoGlyph.sound:
        for (final (x, h) in [
          (4.0, 5.0),
          (8.0, 11.0),
          (12.0, 18.0),
          (16.0, 9.0),
          (20.0, 4.0),
        ]) {
          line(x, 12 - h / 2, x, 12 + h / 2);
        }
      case DoodimoGlyph.video:
        box(3, 4, 18, 16);
        path(
          Path()
            ..moveTo(10, 8)
            ..lineTo(16, 12)
            ..lineTo(10, 16)
            ..close(),
        );
      case DoodimoGlyph.check:
        path(
          Path()
            ..moveTo(4, 12)
            ..lineTo(9, 17)
            ..lineTo(20, 6),
        );
      case DoodimoGlyph.arrowUpRight:
        path(
          Path()
            ..moveTo(5, 19)
            ..lineTo(19, 5)
            ..moveTo(8, 5)
            ..lineTo(19, 5)
            ..lineTo(19, 16),
        );
      case DoodimoGlyph.more:
        for (final x in [5.0, 12.0, 19.0]) {
          c.drawCircle(Offset(x, 12), 1.75, Paint()..color = color);
        }
      case DoodimoGlyph.chevronDown:
        path(
          Path()
            ..moveTo(5, 9)
            ..lineTo(12, 16)
            ..lineTo(19, 9),
        );
      case DoodimoGlyph.moon:
        path(
          Path()
            ..moveTo(20, 15)
            ..cubicTo(6, 20, 3, 7, 11, 3)
            ..cubicTo(-1, 4, 1, 22, 13, 21)
            ..quadraticBezierTo(18, 21, 20, 15),
        );
      case DoodimoGlyph.sun:
        circle(12, 12, 4);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          line(
            12 + 7 * math.cos(a),
            12 + 7 * math.sin(a),
            12 + 10 * math.cos(a),
            12 + 10 * math.sin(a),
          );
        }
      case DoodimoGlyph.help:
        circle(12, 12, 9);
        path(
          Path()
            ..moveTo(9, 8)
            ..cubicTo(9, 4, 17, 5, 15, 10)
            ..quadraticBezierTo(14, 11, 12, 12)
            ..lineTo(12, 14),
        );
        line(12, 17, 12, 17.1);
      case DoodimoGlyph.language:
        circle(12, 12, 9);
        c.drawOval(const Rect.fromLTWH(8, 3, 8, 18), p);
        line(3, 12, 21, 12);
        line(5, 7, 19, 7);
        line(5, 17, 19, 17);
      case DoodimoGlyph.camera:
        path(
          Path()
            ..moveTo(3, 7)
            ..lineTo(7, 7)
            ..lineTo(9, 4)
            ..lineTo(15, 4)
            ..lineTo(17, 7)
            ..lineTo(21, 7)
            ..lineTo(21, 20)
            ..lineTo(3, 20)
            ..close(),
        );
        circle(12, 13, 4);
      case DoodimoGlyph.rotate:
        c.drawArc(
          const Rect.fromLTWH(4, 4, 16, 16),
          .1,
          math.pi * 1.6,
          false,
          p,
        );
        path(
          Path()
            ..moveTo(4, 3)
            ..lineTo(4, 9)
            ..lineTo(10, 9),
        );
      case DoodimoGlyph.mirror:
        line(12, 2, 12, 22);
        path(
          Path()
            ..moveTo(3, 18)
            ..lineTo(9, 6)
            ..lineTo(9, 18)
            ..close(),
        );
        path(
          Path()
            ..moveTo(21, 18)
            ..lineTo(15, 6)
            ..lineTo(15, 18)
            ..close(),
        );
      case DoodimoGlyph.crop:
        path(
          Path()
            ..moveTo(7, 2)
            ..lineTo(7, 17)
            ..lineTo(22, 17)
            ..moveTo(2, 7)
            ..lineTo(17, 7)
            ..lineTo(17, 22),
        );
      case DoodimoGlyph.delete:
        box(6, 7, 12, 14, 1);
        line(4, 7, 20, 7);
        box(9, 3, 6, 4, 1);
        line(10, 11, 10, 17);
        line(14, 11, 14, 17);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_OutlineGlyph old) =>
      old.glyph != glyph || old.color != color || old.rtl != rtl;
}
