import 'package:flutter/material.dart';

import '../domain/export_port.dart';

/// Original static format illustrations. These are icons, never a live audio
/// waveform, a preview of output progress or part of document rendering.
class ExportFormatArt extends StatelessWidget {
  const ExportFormatArt({
    super.key,
    required this.format,
    required this.ink,
    required this.accent,
    this.size = 36,
  });
  final ExportFormat format;
  final Color ink, accent;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _FormatPainter(format, ink, accent)),
      ),
    ),
  );
}

class _FormatPainter extends CustomPainter {
  const _FormatPainter(this.format, this.ink, this.accent);
  final ExportFormat format;
  final Color ink, accent;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final pen = Paint()
      ..color = ink
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = accent;
    switch (format) {
      case ExportFormat.png:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 12, 58, 68),
            const Radius.circular(9),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 24, 62, 64),
            const Radius.circular(9),
          ),
          pen,
        );
        canvas.drawCircle(const Offset(59, 41), 6, Paint()..color = ink);
        canvas.drawPath(
          Path()
            ..moveTo(25, 71)
            ..cubicTo(33, 53, 39, 58, 45, 66)
            ..cubicTo(51, 75, 59, 63, 66, 58),
          pen,
        );
      case ExportFormat.wav:
        canvas.drawCircle(const Offset(50, 50), 31, fill);
        canvas.drawPath(
          Path()
            ..moveTo(12, 58)
            ..cubicTo(25, 16, 41, 19, 40, 49)
            ..cubicTo(39, 80, 18, 79, 27, 54)
            ..cubicTo(38, 28, 48, 79, 60, 55)
            ..cubicTo(69, 27, 73, 24, 86, 46),
          pen,
        );
        canvas.drawCircle(const Offset(86, 46), 6, Paint()..color = ink);
      case ExportFormat.mp4:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 16, 65, 52),
            const Radius.circular(11),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(12, 30, 70, 54),
            const Radius.circular(11),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(40, 43)
            ..lineTo(60, 57)
            ..lineTo(40, 71)
            ..close(),
          Paint()..color = ink,
        );
        canvas.drawLine(const Offset(25, 23), const Offset(35, 23), pen);
      case ExportFormat.midi:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 14, 61, 71),
            const Radius.circular(12),
          ),
          fill,
        );
        for (final y in [35.0, 51.0, 67.0]) {
          canvas.drawLine(
            Offset(13, y),
            Offset(88, y),
            pen..color = ink.withValues(alpha: .38),
          );
        }
        pen.color = ink;
        for (final note in [
          const Offset(29, 69),
          const Offset(52, 53),
          const Offset(75, 37),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: note, width: 14, height: 10),
            Paint()..color = ink,
          );
          canvas.drawLine(
            Offset(note.dx + 6, note.dy),
            Offset(note.dx + 6, note.dy - 24),
            pen,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FormatPainter old) =>
      old.format != format || old.ink != ink || old.accent != accent;
}

class ExportTicketClipper extends CustomClipper<Path> {
  const ExportTicketClipper();
  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)),
      );
    final cutouts = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(0, size.height * .55), radius: 10),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height * .55),
          radius: 10,
        ),
      );
    return Path.combine(PathOperation.difference, body, cutouts);
  }

  @override
  bool shouldReclip(ExportTicketClipper old) => false;
}

class ExportTicketRule extends StatelessWidget {
  const ExportTicketRule({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _RulePainter(color)),
  );
}

class _RulePainter extends CustomPainter {
  const _RulePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + 4).clamp(0, size.width), 0),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.color != color;
}
