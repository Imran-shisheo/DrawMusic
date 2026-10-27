import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../design_system/brand_colors.dart';

/// Original filled instrument objects. These are artwork, never activity meters;
/// the containing named control owns selection and accessibility semantics.
class InstrumentGlyph extends StatelessWidget {
  const InstrumentGlyph(
    this.instrument, {
    super.key,
    this.size = 48,
    this.color,
  });
  final Instrument instrument;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _VoiceObjectPainter(instrument)),
    ),
  );
}

class _VoiceObjectPainter extends CustomPainter {
  _VoiceObjectPainter(this.instrument);
  final Instrument instrument;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    const pairs = [
      [Color(0xffb6a1ff), Color(0xff7189f9)],
      [Color(0xffffb7dc), Color(0xffbc8bf5)],
      [Color(0xff89e8f4), Color(0xff7992f0)],
    ];
    final tones = pairs[instrument.index % pairs.length];
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: tones,
      ).createShader(const Rect.fromLTWH(4, 4, 40, 40));
    final dark = Paint()..color = DoodimoColors.indigo;
    final light = Paint()..color = const Color(0xffeef6ff);
    final accent = Paint()..color = DoodimoColors.cyan;
    final shadow = Paint()
      ..color = const Color(0xff020614).withValues(alpha: .4);
    void box(
      double x,
      double y,
      double w,
      double h,
      Paint p, [
      double radius = 3,
    ]) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      p,
    );
    void line(
      double x,
      double y,
      double a,
      double b,
      Paint p, [
      double width = 2,
    ]) => canvas.drawLine(
      Offset(x, y),
      Offset(a, b),
      Paint()
        ..color = p.color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    void dot(double x, double y, double r, Paint p) =>
        canvas.drawCircle(Offset(x, y), r, p);
    // Every role has a deliberate three-dimensional underside, a lit material
    // plane and crisp accents. All geometry is bounded and statically painted.
    canvas.drawOval(const Rect.fromLTWH(8, 39, 34, 5), shadow);
    switch (instrument) {
      case Instrument.keys:
        box(4, 11, 40, 29, shadow, 7);
        box(3, 8, 40, 29, body, 7);
        for (var i = 0; i < 5; i++) {
          box(7 + i * 6.0, 16, 5, 17, light, 1.5);
        }
        for (final x in [11.0, 17.0, 29.0]) {
          box(x, 15, 3, 10, dark, 1);
        }
        line(9, 12, 35, 12, accent, 1.5);
      case Instrument.mallet:
        line(12, 38, 31, 12, shadow, 5);
        line(34, 38, 15, 12, shadow, 5);
        line(11, 36, 30, 10, light, 3);
        line(33, 36, 14, 10, light, 3);
        dot(31, 11, 8, body);
        dot(14, 11, 8, body);
        dot(29, 8, 2, light);
        dot(12, 8, 2, light);
      case Instrument.bell:
        final bell = Path()
          ..moveTo(10, 34)
          ..quadraticBezierTo(16, 27, 15, 20)
          ..cubicTo(14, 8, 34, 8, 33, 20)
          ..quadraticBezierTo(32, 28, 39, 34)
          ..close();
        canvas.drawPath(bell, shadow);
        canvas.save();
        canvas.translate(-2, -2);
        canvas.drawPath(bell, body);
        canvas.restore();
        box(8, 31, 31, 5, body, 2);
        dot(23, 38, 4, accent);
        box(20, 7, 6, 6, light, 3);
        line(18, 19, 16, 27, light, 2);
      case Instrument.warmSynth:
        for (var i = 0; i < 3; i++) {
          final y = 10 + i * 11.0;
          final path = Path()
            ..moveTo(5, y + 5)
            ..cubicTo(13, y - 8, 18, y + 17, 27, y + 4)
            ..cubicTo(33, y - 7, 38, y - 1, 43, y + 5);
          canvas.drawPath(
            path,
            Paint()
              ..shader = body.shader
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round,
          );
        }
        dot(7, 14, 2, light);
        dot(39, 37, 2, accent);
      case Instrument.pluck:
        canvas.drawPath(
          Path()
            ..moveTo(9, 38)
            ..lineTo(12, 9)
            ..quadraticBezierTo(23, 5, 36, 12)
            ..lineTo(39, 38)
            ..close(),
          body,
        );
        for (var i = 0; i < 5; i++) {
          line(
            16 + i * 4.0,
            14,
            14 + i * 5.0,
            35,
            i.isEven ? light : accent,
            1.5,
          );
        }
        box(8, 36, 33, 5, dark, 2);
      case Instrument.flute:
        canvas.save();
        canvas.translate(24, 24);
        canvas.rotate(-.65);
        box(-19, -5, 39, 13, shadow, 5);
        box(-20, -8, 39, 13, body, 5);
        box(-20, -8, 7, 13, light, 2);
        for (var i = 0; i < 4; i++) {
          dot(-6 + i * 6.0, -2, 2, dark);
          dot(-6 + i * 6.0, -3, 1, accent);
        }
        canvas.restore();
      case Instrument.strings:
        final violin = Path()
          ..moveTo(19, 15)
          ..cubicTo(6, 16, 7, 24, 16, 26)
          ..cubicTo(1, 38, 17, 47, 24, 36)
          ..cubicTo(31, 47, 47, 38, 32, 26)
          ..cubicTo(41, 24, 42, 16, 29, 15)
          ..close();
        canvas.drawPath(violin, body);
        box(21, 3, 6, 28, dark, 2);
        box(20, 1, 8, 8, body, 2);
        line(24, 10, 24, 36, light, 1.5);
        line(34, 7, 12, 41, accent, 2);
        box(19, 31, 10, 3, light, 1);
      case Instrument.chime:
        box(6, 6, 36, 6, body, 3);
        for (var i = 0; i < 5; i++) {
          final x = 10 + i * 7.0;
          line(x, 12, x, 17, light, 1);
          box(x - 2, 16, 5, 13 + i * 3.0, body, 2);
          line(x - 1, 18, x - 1, 25 + i * 3.0, light, 1);
        }
      case Instrument.bass:
      case Instrument.guitar:
        final bass = instrument == Instrument.bass;
        canvas.save();
        canvas.translate(24, 25);
        canvas.rotate(.45);
        final shape = Path()
          ..moveTo(-5, -3)
          ..cubicTo(-18, -10, -21, 5, -12, 9)
          ..cubicTo(-24, 26, 23, 26, 12, 8)
          ..cubicTo(21, 4, 18, -10, 5, -3)
          ..close();
        canvas.drawPath(shape, body);
        box(-3, -22, 6, 31, dark, 2);
        box(-4, -25, 8, 10, body, 2);
        if (!bass) dot(0, 8, 4, dark);
        box(-6, 14, 12, 3, light, 1);
        line(-1, -20, -1, 15, light, 1);
        line(2, -20, 2, 15, accent, 1);
        canvas.restore();
      case Instrument.chip:
        box(8, 8, 32, 32, shadow, 8);
        box(6, 6, 32, 32, body, 8);
        box(12, 12, 20, 17, dark, 3);
        final path = Path()
          ..moveTo(14, 23)
          ..lineTo(18, 23)
          ..lineTo(18, 17)
          ..lineTo(23, 17)
          ..lineTo(23, 23)
          ..lineTo(29, 23);
        canvas.drawPath(
          path,
          Paint()
            ..color = DoodimoColors.cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        for (var i = 0; i < 3; i++) {
          dot(15 + i * 7.0, 33, 1.5, light);
        }
        box(1, 15, 5, 4, body, 1);
        box(38, 23, 5, 4, body, 1);
      case Instrument.electronicBass:
        box(5, 8, 38, 32, body, 8);
        box(10, 13, 27, 20, dark, 4);
        for (var i = 0; i < 4; i++) {
          box(
            13 + i * 6.0,
            18 + (i % 2) * 5.0,
            3,
            12 - (i % 2) * 5.0,
            i.isEven ? accent : light,
            1,
          );
        }
        dot(13, 36, 1.5, light);
        dot(36, 36, 2, accent);
      case Instrument.saxophone:
        final horn = Path()
          ..moveTo(25, 6)
          ..lineTo(35, 6)
          ..lineTo(35, 11)
          ..lineTo(29, 12)
          ..lineTo(29, 29)
          ..cubicTo(29, 46, 7, 46, 8, 29)
          ..lineTo(5, 20)
          ..lineTo(20, 20)
          ..lineTo(16, 29)
          ..cubicTo(15, 37, 23, 37, 23, 29)
          ..lineTo(23, 11)
          ..close();
        canvas.drawPath(horn, body);
        canvas.drawOval(const Rect.fromLTWH(4, 17, 17, 7), dark);
        canvas.drawOval(const Rect.fromLTWH(6, 18, 13, 3), accent);
        for (var i = 0; i < 3; i++) {
          dot(27, 17 + i * 6.0, 2, light);
        }
        line(35, 8, 41, 10, accent, 4);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VoiceObjectPainter old) =>
      old.instrument != instrument;
}
