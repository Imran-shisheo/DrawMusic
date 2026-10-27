import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original filled duotone symbols. Geometry is authored for Doodimo; no icon
/// font, stock SVG or former hand-drawn line composition is used.
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
    final scheme = Theme.of(context).colorScheme;
    final ink = color ?? inherited.color ?? scheme.onSurface;
    final opacity = (ink.a * (inherited.opacity ?? 1)).clamp(0.0, 1.0);
    final opaque = ink.withValues(alpha: 1);
    Widget painted = CustomPaint(
      painter: _DoodimoGlyphPainter(
        glyph,
        opaque,
        Color.lerp(opaque, scheme.secondary, .32)!.withValues(alpha: 1),
        Directionality.of(context) == TextDirection.rtl,
      ),
    );
    // Apply disabled/explicit alpha to the whole material, once. Overlapping
    // faces must not accumulate alpha and make disabled symbols look enabled.
    if (opacity < 1) painted = Opacity(opacity: opacity, child: painted);
    final icon = SizedBox.square(dimension: size, child: painted);
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
  const _DoodimoGlyphPainter(this.glyph, this.color, this.accent, this.rtl);
  final DoodimoGlyph glyph;
  final Color color;
  final Color accent;
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
    final face = Paint()..color = color;
    final side = Paint()..color = accent.withValues(alpha: .36);
    final middle = Paint()
      ..color = Color.lerp(accent, const Color(0xff090b18), .28)!;
    final detail = Paint()
      ..color = color.computeLuminance() > .45
          ? const Color(0xff151b35)
          : const Color(0xffeaf0ff);
    final gleam = Paint()
      ..color = Color.lerp(color, Colors.white, .56)!.withValues(alpha: .9);
    void slab(
      double x,
      double y,
      double w,
      double h,
      Paint paint, [
      double radius = 2.4,
    ]) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      paint,
    );
    void shape(Path path, Paint paint) => canvas.drawPath(path, paint);
    void orb(double x, double y, double r, Paint paint) =>
        canvas.drawCircle(Offset(x, y), r, paint);
    void bar(
      double x,
      double y,
      double w,
      double h,
      double angle,
      Paint paint,
    ) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      slab(-w / 2, -h / 2, w, h, paint, h / 2);
      canvas.restore();
    }

    void shine(double x, double y, double w) => slab(x, y, w, 1, gleam, .5);
    switch (glyph) {
      case DoodimoGlyph.home:
        slab(4, 9, 16, 12, side, 3);
        shape(
          Path()
            ..moveTo(2.5, 10)
            ..lineTo(10, 3.3)
            ..quadraticBezierTo(12, 1.5, 14, 3.3)
            ..lineTo(21.5, 10)
            ..quadraticBezierTo(22.5, 12, 20, 12)
            ..lineTo(19, 12)
            ..lineTo(19, 19)
            ..quadraticBezierTo(19, 21, 17, 21)
            ..lineTo(7, 21)
            ..quadraticBezierTo(5, 21, 5, 19)
            ..lineTo(5, 12)
            ..lineTo(4, 12)
            ..quadraticBezierTo(1.5, 12, 2.5, 10)
            ..close(),
          face,
        );
        slab(10, 13, 4, 8, middle, 2);
        shine(7, 10, 4);
      case DoodimoGlyph.library:
        slab(3, 3, 14, 17, side, 3);
        slab(6, 5, 15, 17, middle, 3);
        slab(8, 7, 13, 15, face, 2.5);
        shine(10, 9, 7);
        slab(10, 12, 2, 6, gleam, 1);
        slab(14, 12, 4, 2, gleam, 1);
        slab(14, 16, 4, 2, middle, 1);
      case DoodimoGlyph.settings:
        for (final (x, y) in [(3.5, 7.0), (10.5, 14.0), (17.5, 5.0)]) {
          slab(x, 3, 3, 18, side, 1.5);
          slab(x - 1, y, 5, 6, face, 2);
          shine(x, y + 1, 3);
        }
      case DoodimoGlyph.add:
        slab(3, 9, 18, 6, side, 3);
        slab(9, 3, 6, 18, face, 3);
        slab(3, 10, 18, 4, face, 2);
        shine(10, 5, 2);
      case DoodimoGlyph.back:
        slab(6, 9, 15, 6, side, 3);
        shape(
          Path()
            ..moveTo(10, 4.5)
            ..quadraticBezierTo(11.5, 3, 13, 5)
            ..quadraticBezierTo(14, 6, 12.5, 7.5)
            ..lineTo(10, 10)
            ..lineTo(20, 10)
            ..lineTo(20, 14)
            ..lineTo(10, 14)
            ..lineTo(12.5, 16.5)
            ..quadraticBezierTo(14, 18, 12.5, 19.5)
            ..quadraticBezierTo(11, 21, 9.5, 19.5)
            ..lineTo(3, 13)
            ..quadraticBezierTo(2, 12, 3, 11)
            ..close(),
          face,
        );
        shine(11, 10, 7);
      case DoodimoGlyph.close:
        bar(12, 12, 21, 4.8, math.pi / 4, side);
        bar(12, 12, 21, 4, -math.pi / 4, face);
        bar(12, 12, 21, 3.2, math.pi / 4, face);
        bar(8, 8, 6, 1, math.pi / 4, gleam);
      case DoodimoGlyph.draw:
        slab(3, 20, 17, 2, side, 1);
        shape(
          Path()
            ..moveTo(4, 19)
            ..lineTo(6, 12)
            ..lineTo(16, 2.8)
            ..quadraticBezierTo(17.5, 1.5, 19, 3)
            ..lineTo(21, 5)
            ..quadraticBezierTo(22.5, 6.5, 21, 8)
            ..lineTo(11, 18)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(4, 19)
            ..lineTo(6, 12)
            ..lineTo(11, 18)
            ..close(),
          middle,
        );
        bar(13, 10, 9, 1, -math.pi / 4, gleam);
        bar(18, 6, 5, 2, math.pi / 4, middle);
      case DoodimoGlyph.erase:
        canvas.save();
        canvas.translate(12, 11.5);
        canvas.rotate(math.pi / 4);
        slab(-5, -9, 10, 18, side, 3);
        slab(-5, -9, 10, 12, face, 3);
        slab(-5, 3, 10, 6, middle, 2);
        shine(-3, -7, 5);
        canvas.restore();
        slab(8, 20, 13, 2, face, 1);
      case DoodimoGlyph.undo:
      case DoodimoGlyph.redo:
        if (glyph == DoodimoGlyph.redo) {
          canvas.translate(24, 0);
          canvas.scale(-1, 1);
        }
        shape(
          Path()
            ..moveTo(4, 9)
            ..cubicTo(10, 2, 22, 5, 21, 15)
            ..quadraticBezierTo(21, 19, 18, 21)
            ..lineTo(15.5, 18)
            ..cubicTo(22, 11, 12, 5, 7, 11)
            ..close(),
          side,
        );
        shape(
          Path()
            ..moveTo(3, 5)
            ..quadraticBezierTo(3, 3, 4.5, 4.5)
            ..lineTo(11, 11)
            ..quadraticBezierTo(12, 12, 10, 12.5)
            ..lineTo(3, 14)
            ..quadraticBezierTo(2, 14, 2, 12)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(8, 8)
            ..cubicTo(14, 5, 20, 8, 20, 14)
            ..lineTo(17, 14)
            ..cubicTo(17, 10, 13, 8, 9, 11)
            ..close(),
          face,
        );
      case DoodimoGlyph.play:
        shape(
          Path()
            ..moveTo(6, 4.5)
            ..quadraticBezierTo(6, 2, 8.5, 3.5)
            ..lineTo(21, 10.5)
            ..quadraticBezierTo(23, 12, 21, 13.5)
            ..lineTo(8.5, 20.5)
            ..quadraticBezierTo(6, 22, 6, 19.5)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(6, 5)
            ..lineTo(11, 8)
            ..lineTo(11, 17)
            ..lineTo(6, 20)
            ..close(),
          middle,
        );
        bar(14, 8, 8, 1, math.pi / 6, gleam);
      case DoodimoGlyph.pause:
        for (final x in [4.0, 14.0]) {
          slab(x, 3, 6, 18, face, 2.5);
          slab(x, 5, 2, 14, middle, 1);
          shine(x + 2, 5, 2);
        }
      case DoodimoGlyph.replay:
        shape(
          Path()
            ..moveTo(19, 7)
            ..cubicTo(11, -1, 1, 7, 4, 16)
            ..cubicTo(6, 23, 17, 23, 21, 16)
            ..lineTo(18, 14)
            ..cubicTo(15, 20, 8, 19, 7, 14)
            ..cubicTo(5, 8, 12, 4, 16, 9)
            ..close(),
          side,
        );
        shape(
          Path()
            ..moveTo(19, 3)
            ..quadraticBezierTo(20, 2, 20, 4)
            ..lineTo(21, 11)
            ..quadraticBezierTo(21, 12, 20, 12)
            ..lineTo(13, 11)
            ..quadraticBezierTo(11, 11, 12, 10)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(4, 12)
            ..lineTo(7, 12)
            ..cubicTo(7, 20, 16, 21, 19, 15)
            ..lineTo(22, 16)
            ..cubicTo(17, 26, 3, 21, 4, 12)
            ..close(),
          face,
        );
      case DoodimoGlyph.tempo:
        shape(
          Path()
            ..moveTo(8, 3)
            ..quadraticBezierTo(12, 1, 15, 4)
            ..lineTo(20, 20)
            ..lineTo(3, 20)
            ..close(),
          side,
        );
        shape(
          Path()
            ..moveTo(10, 4)
            ..lineTo(13, 4)
            ..lineTo(18, 20)
            ..lineTo(5, 20)
            ..close(),
          face,
        );
        bar(13, 11, 15, 2, -math.pi / 3, middle);
        orb(16.5, 5, 2, gleam);
        slab(3, 19, 18, 3, face, 1.5);
      case DoodimoGlyph.voice:
        orb(12, 12, 10, side);
        slab(5, 8, 3, 8, middle, 1.5);
        slab(10.5, 4, 3, 16, face, 1.5);
        slab(16, 7, 3, 10, face, 1.5);
        shine(11, 6, 2);
      case DoodimoGlyph.music:
        shape(
          Path()
            ..moveTo(8, 5)
            ..lineTo(21, 2)
            ..lineTo(21, 17)
            ..lineTo(18, 17)
            ..lineTo(18, 8)
            ..lineTo(11, 10)
            ..lineTo(11, 19)
            ..lineTo(8, 19)
            ..close(),
          face,
        );
        canvas.drawOval(const Rect.fromLTWH(2, 15, 9, 7), middle);
        canvas.drawOval(const Rect.fromLTWH(12, 13, 9, 7), face);
        shape(
          Path()
            ..moveTo(8, 5)
            ..lineTo(21, 2)
            ..lineTo(21, 6)
            ..lineTo(8, 9)
            ..close(),
          middle,
        );
        shine(15, 4, 3);
      case DoodimoGlyph.paper:
        slab(4, 2, 15, 20, side, 3);
        shape(
          Path()
            ..moveTo(7, 3)
            ..lineTo(15, 3)
            ..lineTo(21, 9)
            ..lineTo(21, 19)
            ..quadraticBezierTo(21, 22, 18, 22)
            ..lineTo(7, 22)
            ..quadraticBezierTo(5, 22, 5, 20)
            ..lineTo(5, 5)
            ..quadraticBezierTo(5, 3, 7, 3)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(15, 3)
            ..lineTo(15, 8)
            ..quadraticBezierTo(15, 10, 17, 10)
            ..lineTo(21, 10)
            ..close(),
          middle,
        );
        shine(8, 13, 8);
        slab(8, 16, 6, 1.5, middle, .75);
      case DoodimoGlyph.export:
        slab(3, 14, 18, 8, side, 3);
        slab(5, 17, 14, 4, middle, 2);
        shape(
          Path()
            ..moveTo(10, 15)
            ..lineTo(10, 8)
            ..lineTo(6, 8)
            ..quadraticBezierTo(4, 8, 6, 6)
            ..lineTo(11, 2.5)
            ..quadraticBezierTo(12, 1.5, 13, 2.5)
            ..lineTo(18, 6)
            ..quadraticBezierTo(20, 8, 18, 8)
            ..lineTo(14, 8)
            ..lineTo(14, 15)
            ..close(),
          face,
        );
        shine(11, 5, 2);
      case DoodimoGlyph.save:
        slab(3, 2, 18, 20, side, 3);
        shape(
          Path()
            ..moveTo(6, 2)
            ..lineTo(17, 2)
            ..lineTo(21, 6)
            ..lineTo(21, 19)
            ..quadraticBezierTo(21, 22, 18, 22)
            ..lineTo(6, 22)
            ..quadraticBezierTo(3, 22, 3, 19)
            ..lineTo(3, 5)
            ..quadraticBezierTo(3, 2, 6, 2)
            ..close(),
          face,
        );
        slab(7, 2, 9, 7, middle, 1);
        slab(7, 13, 10, 9, middle, 2);
        shine(9, 15, 6);
        slab(13, 3, 2, 4, gleam, 1);
      case DoodimoGlyph.image:
        slab(2, 4, 20, 17, side, 3);
        slab(4, 5, 18, 14, middle, 2.5);
        orb(16.5, 8.5, 2, gleam);
        shape(
          Path()
            ..moveTo(3, 17)
            ..lineTo(9, 10)
            ..quadraticBezierTo(10, 9, 11, 11)
            ..lineTo(17, 19)
            ..lineTo(5, 19)
            ..quadraticBezierTo(3, 19, 3, 17)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(12, 18)
            ..lineTo(17, 12)
            ..quadraticBezierTo(18, 11, 19, 13)
            ..lineTo(22, 17)
            ..lineTo(22, 19)
            ..lineTo(12, 19)
            ..close(),
          middle,
        );
      case DoodimoGlyph.sound:
        for (final (x, h) in [
          (2.0, 7.0),
          (7.0, 14.0),
          (12.0, 20.0),
          (17.0, 11.0),
        ]) {
          slab(x, 12 - h / 2, 4, h, x == 7 || x == 17 ? middle : face, 2);
          shine(x + 1, 13 - h / 2, 2);
        }
      case DoodimoGlyph.video:
        slab(2, 5, 14, 15, side, 3);
        slab(2, 4, 14, 14, face, 3);
        shape(
          Path()
            ..moveTo(17, 8)
            ..lineTo(21, 5)
            ..quadraticBezierTo(22, 4, 22, 6)
            ..lineTo(22, 18)
            ..quadraticBezierTo(22, 20, 21, 19)
            ..lineTo(17, 16)
            ..close(),
          middle,
        );
        shine(5, 6, 7);
        slab(4, 15, 9, 1, middle, .5);
      case DoodimoGlyph.notes:
        slab(3, 2, 16, 20, side, 3);
        slab(6, 4, 15, 18, middle, 3);
        shape(
          Path()
            ..moveTo(11, 8)
            ..lineTo(18, 6)
            ..lineTo(18, 17)
            ..lineTo(15.5, 17)
            ..lineTo(15.5, 10)
            ..lineTo(13.5, 11)
            ..lineTo(13.5, 19)
            ..lineTo(11, 19)
            ..close(),
          face,
        );
        canvas.drawOval(const Rect.fromLTWH(7, 16, 6.5, 5), face);
        canvas.drawOval(const Rect.fromLTWH(12, 14, 6, 5), face);
        shine(9, 6, 3);
      case DoodimoGlyph.check:
        shape(
          Path()
            ..moveTo(3, 11)
            ..quadraticBezierTo(4, 10, 5, 11)
            ..lineTo(9, 15)
            ..lineTo(19, 4.5)
            ..quadraticBezierTo(20.5, 3, 22, 5)
            ..quadraticBezierTo(23, 6, 21.5, 7.5)
            ..lineTo(10.5, 20)
            ..quadraticBezierTo(9, 21, 7.5, 19.5)
            ..lineTo(2.5, 14)
            ..quadraticBezierTo(1, 12.5, 3, 11)
            ..close(),
          face,
        );
        bar(6, 14.5, 7, 1, math.pi / 4, gleam);
      case DoodimoGlyph.arrowUpRight:
        shape(
          Path()
            ..moveTo(7, 3)
            ..lineTo(20, 3)
            ..quadraticBezierTo(22, 3, 22, 5)
            ..lineTo(22, 18)
            ..lineTo(17, 18)
            ..lineTo(17, 11)
            ..lineTo(6, 22)
            ..lineTo(2, 18)
            ..lineTo(13, 7)
            ..lineTo(7, 7)
            ..close(),
          side,
        );
        shape(
          Path()
            ..moveTo(7, 3)
            ..lineTo(20, 3)
            ..quadraticBezierTo(21, 3, 21, 4)
            ..lineTo(21, 17)
            ..lineTo(17, 17)
            ..lineTo(17, 10)
            ..lineTo(5, 22)
            ..lineTo(2, 19)
            ..lineTo(14, 7)
            ..lineTo(7, 7)
            ..close(),
          face,
        );
        shine(9, 4, 9);
      case DoodimoGlyph.more:
        for (final x in [4.0, 12.0, 20.0]) {
          orb(x, 12, 2, face);
          orb(x - .5, 11.5, .65, gleam);
        }
      case DoodimoGlyph.chevronDown:
        shape(
          Path()
            ..moveTo(3, 7)
            ..quadraticBezierTo(4, 6, 5, 7)
            ..lineTo(12, 14)
            ..lineTo(19, 7)
            ..quadraticBezierTo(20, 6, 21, 7)
            ..quadraticBezierTo(22, 8, 21, 9)
            ..lineTo(13.5, 17)
            ..quadraticBezierTo(12, 19, 10.5, 17)
            ..lineTo(3, 9)
            ..quadraticBezierTo(2, 8, 3, 7)
            ..close(),
          face,
        );
        bar(7, 11, 7, 1, math.pi / 4, gleam);
      case DoodimoGlyph.moon:
        shape(
          Path()
            ..moveTo(13, 2.5)
            ..cubicTo(1, 1, 0, 19, 11, 21)
            ..quadraticBezierTo(18, 22, 21, 15)
            ..cubicTo(11, 19, 7, 9, 13, 2.5)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(13, 2.5)
            ..cubicTo(4, 5, 4, 18, 13, 20)
            ..quadraticBezierTo(5, 22, 3, 14)
            ..quadraticBezierTo(1, 6, 13, 2.5)
            ..close(),
          middle,
        );
        orb(18, 5, 1.5, gleam);
        orb(21, 9, 1, middle);
      case DoodimoGlyph.sun:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          bar(12 + 9 * math.cos(a), 12 + 9 * math.sin(a), 3, 2, a, side);
        }
        orb(12, 12, 6, face);
        orb(10.5, 10.5, 3, middle);
        shine(9, 8, 4);
      case DoodimoGlyph.help:
        orb(12, 12, 10, side);
        orb(12, 11, 9, face);
        final cut = Paint()
          ..color = detail.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(9, 8)
            ..cubicTo(9, 4.5, 16, 5, 16, 8)
            ..cubicTo(16, 10, 12, 10, 12, 13),
          cut,
        );
        orb(12, 16.5, 1.2, detail);
        shine(7, 5, 3);
      case DoodimoGlyph.camera:
        slab(2, 7, 20, 14, side, 4);
        slab(7, 3, 10, 6, middle, 2);
        slab(3, 6, 18, 14, face, 3);
        orb(12, 13, 5, middle);
        orb(12, 13, 3, detail);
        orb(11, 12, 1, gleam);
        shine(16, 8, 3);
      case DoodimoGlyph.rotate:
        slab(5, 8, 12, 14, side, 3);
        slab(8, 10, 11, 11, face, 2.5);
        shape(
          Path()
            ..moveTo(2, 10)
            ..cubicTo(2, 1, 18, 0, 21, 8)
            ..lineTo(18, 10)
            ..cubicTo(16, 4, 6, 4, 5, 11)
            ..close(),
          middle,
        );
        shape(
          Path()
            ..moveTo(20, 3)
            ..lineTo(22, 11)
            ..quadraticBezierTo(22, 12, 21, 12)
            ..lineTo(14, 10)
            ..close(),
          face,
        );
        shine(10, 12, 6);
      case DoodimoGlyph.mirror:
        slab(2, 4, 8, 16, face, 2.5);
        slab(14, 4, 8, 16, middle, 2.5);
        for (final y in [2.0, 7.0, 12.0, 17.0]) {
          slab(11.4, y, 1.2, 4, gleam, .6);
        }
        shine(4, 6, 4);
        shine(16, 6, 4);
      case DoodimoGlyph.crop:
        shape(
          Path()
            ..moveTo(4, 2)
            ..lineTo(8, 2)
            ..lineTo(8, 16)
            ..lineTo(22, 16)
            ..lineTo(22, 20)
            ..lineTo(7, 20)
            ..quadraticBezierTo(4, 20, 4, 17)
            ..close(),
          face,
        );
        shape(
          Path()
            ..moveTo(2, 5)
            ..lineTo(17, 5)
            ..quadraticBezierTo(20, 5, 20, 8)
            ..lineTo(20, 22)
            ..lineTo(16, 22)
            ..lineTo(16, 9)
            ..lineTo(2, 9)
            ..close(),
          middle,
        );
        shine(9, 6, 6);
      case DoodimoGlyph.language:
        slab(2, 2, 15, 16, side, 3);
        slab(3, 3, 13, 14, middle, 2.5);
        bar(8, 9, 10, 2, -1.23, face);
        bar(11, 9, 10, 2, 1.23, face);
        slab(6, 10, 7, 2, face, 1);
        orb(16, 16, 6, face);
        final grid = Paint()
          ..color = gleam.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawOval(const Rect.fromLTWH(13, 11, 6, 10), grid);
        canvas.drawLine(const Offset(11, 16), const Offset(21, 16), grid);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DoodimoGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent ||
      oldDelegate.rtl != rtl;
}
