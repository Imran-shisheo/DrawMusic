import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';

/// Thirteen original role sketches, drawn in the shared rounded line grammar.
/// Decorative names/selection semantics belong to the containing voice tile.
class InstrumentGlyph extends StatelessWidget {
  const InstrumentGlyph(
    this.instrument, {
    super.key,
    this.size = 24,
    this.color,
  });
  final Instrument instrument;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _InstrumentPainter(
          instrument,
          color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _InstrumentPainter extends CustomPainter {
  _InstrumentPainter(this.instrument, this.color);
  final Instrument instrument;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void path(Path path) => canvas.drawPath(path, p);
    void line(double ax, double ay, double bx, double by) =>
        canvas.drawLine(Offset(ax, ay), Offset(bx, by), p);
    void dot(double x, double y, [double r = 1]) =>
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
    switch (instrument) {
      case Instrument.keys:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 4, 18, 16),
            const Radius.circular(2),
          ),
          p,
        );
        for (final x in [9.0, 15.0]) {
          line(x, 5, x, 19);
        }
        for (final x in [7.5, 13.5]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 4, 3, 8),
              const Radius.circular(.6),
            ),
            Paint()..color = color,
          );
        }
      case Instrument.mallet:
        line(5, 20, 16, 6);
        line(19, 20, 8, 6);
        canvas.drawCircle(const Offset(17, 5), 3, p);
        canvas.drawCircle(const Offset(7, 5), 3, p);
      case Instrument.bell:
        path(
          Path()
            ..moveTo(5, 17)
            ..quadraticBezierTo(8, 14, 7, 10)
            ..cubicTo(7, 3, 17, 3, 17, 10)
            ..quadraticBezierTo(16, 14, 19, 17)
            ..close(),
        );
        path(
          Path()
            ..moveTo(10, 20)
            ..quadraticBezierTo(12, 22, 14, 20),
        );
        dot(12, 3);
      case Instrument.warmSynth:
        for (final y in [6.0, 12.0, 18.0]) {
          path(
            Path()
              ..moveTo(3, y)
              ..cubicTo(7, y - 7, 9, y + 7, 13, y)
              ..cubicTo(17, y - 7, 19, y + 7, 21, y),
          );
        }
      case Instrument.pluck:
        path(
          Path()
            ..moveTo(4, 19)
            ..quadraticBezierTo(19, 17, 19, 4),
        );
        line(6, 17, 16, 7);
        line(4, 4, 8, 8);
        line(5, 8, 8, 5);
        dot(19, 4, 1.6);
      case Instrument.flute:
        path(
          Path()
            ..moveTo(3, 19)
            ..lineTo(18, 4)
            ..lineTo(21, 7)
            ..lineTo(6, 22)
            ..close(),
        );
        for (final n in [9.0, 12.0, 15.0]) {
          dot(n, 22 - n, .8);
        }
      case Instrument.strings:
        for (final x in [6.0, 12.0, 18.0]) {
          path(
            Path()
              ..moveTo(x, 3)
              ..cubicTo(x - 4, 9, x + 4, 15, x, 21),
          );
        }
        line(4, 12, 20, 12);
      case Instrument.chime:
        path(
          Path()
            ..moveTo(3, 6)
            ..quadraticBezierTo(12, 1, 21, 6),
        );
        for (var i = 0; i < 4; i++) {
          final x = 5.0 + i * 4.5;
          line(x, 6, x, 17 + i % 2 * 3.0);
          dot(x, 17 + i % 2 * 3.0, 1.2);
        }
      case Instrument.bass:
        path(
          Path()
            ..moveTo(13, 8)
            ..lineTo(17, 3)
            ..lineTo(20, 5)
            ..lineTo(15, 11)
            ..cubicTo(24, 19, 13, 26, 8, 18)
            ..cubicTo(1, 16, 4, 7, 13, 8)
            ..close(),
        );
        line(8, 18, 18, 4);
        dot(11, 15, 1.3);
      case Instrument.chip:
        path(
          Path()
            ..moveTo(2, 17)
            ..lineTo(2, 7)
            ..lineTo(7, 7)
            ..lineTo(7, 17)
            ..lineTo(12, 17)
            ..lineTo(12, 7)
            ..lineTo(17, 7)
            ..lineTo(17, 17)
            ..lineTo(22, 17),
        );
      case Instrument.electronicBass:
        path(
          Path()
            ..moveTo(2, 16)
            ..lineTo(8, 6)
            ..lineTo(8, 18)
            ..lineTo(15, 6)
            ..lineTo(15, 18)
            ..lineTo(22, 8),
        );
        dot(4, 21, 1.2);
        line(8, 21, 20, 21);
      case Instrument.guitar:
        path(
          Path()
            ..moveTo(12, 9)
            ..lineTo(17, 3)
            ..lineTo(20, 5)
            ..lineTo(15, 11)
            ..cubicTo(22, 13, 18, 23, 12, 20)
            ..cubicTo(9, 25, 1, 17, 6, 13)
            ..cubicTo(4, 8, 9, 6, 12, 9)
            ..close(),
        );
        line(8, 17, 18, 4);
        dot(11, 14, 1.5);
      case Instrument.saxophone:
        path(
          Path()
            ..moveTo(8, 3)
            ..lineTo(14, 3)
            ..lineTo(10, 14)
            ..quadraticBezierTo(9, 20, 15, 19)
            ..lineTo(17, 13)
            ..lineTo(22, 16)
            ..quadraticBezierTo(20, 24, 11, 21)
            ..quadraticBezierTo(4, 19, 6, 13)
            ..lineTo(10, 6),
        );
        for (final y in [8.0, 11.0, 14.0]) {
          dot(10, y, .7);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InstrumentPainter oldDelegate) =>
      oldDelegate.instrument != instrument || oldDelegate.color != color;
}
