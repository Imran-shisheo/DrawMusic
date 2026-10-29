import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

// Authoritative authored SVG geometry. scripts/check-brand-icons.py verifies
// parity with assets/branding/mark.svg and the native generated resources.
const doodimoOrbitPathData =
    'M7 66 C18 55 30 27 39 25 C49 22 49 60 57 64 C64 69 76 45 91 40 L93 46 C79 51 67 80 55 71 C43 64 45 31 38 33 C32 34 19 62 10 71 Z';
const doodimoFoldPathData =
    'M8 66 C20 53 31 27 39 25 C48 23 48 53 54 61 L52 65 C44 59 45 32 39 33 C31 31 20 62 10 71 Z';
const doodimoEdgePathData =
    'M10 64 C22 49 31 29 39 28 C43 28 45 39 46 47 L44 47 C43 39 42 31 39 31 C33 31 22 52 11 66 Z';

/// The original filled drawing-to-sound gesture shared by launcher and in-app identity.
///
/// Motion only shifts the small edge reflection. Its silhouette, actual audio
/// clock and layout remain independent. The owning widget stops its animation
/// for reduced motion, hidden routes and application lifecycle changes.
class DoodimoMarkPainter extends CustomPainter {
  DoodimoMarkPainter(this.motion) : super(repaint: motion);

  final Animation<double> motion;

  static final Path _orbit = _authoredPath(doodimoOrbitPathData);
  static final Path _fold = _authoredPath(doodimoFoldPathData);
  static final Path _edge = _authoredPath(doodimoEdgePathData);

  static final Paint _orbitPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(25, 25),
      const Offset(79, 76),
      const [Color(0xffffb577), Color(0xffff9855), Color(0xffe27432)],
      const [0, .45, 1],
    );
  static final Paint _foldPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(29, 73),
      const Offset(64, 38),
      const [Color(0xffe97c3b), Color(0xffffaa68), Color(0xffffd4ae)],
      const [0, .48, 1],
    );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final extent = math.min(size.width, size.height);
    final reflection = math.sin(motion.value * math.pi * 2) * 1.4;
    final edgePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(36 + reflection, 22 + reflection),
        Offset(70 + reflection, 71 + reflection),
        const [Color(0x6bfff1db), Color(0x00fff1db)],
      );
    canvas.save();
    canvas.translate((size.width - extent) / 2, (size.height - extent) / 2);
    canvas.scale(extent / 100);
    canvas.drawPath(_orbit, _orbitPaint);
    canvas.drawPath(_fold, _foldPaint);
    canvas.drawPath(_edge, edgePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(DoodimoMarkPainter oldDelegate) =>
      oldDelegate.motion != motion;
}

/// Parses only this bounded, original M/L/C/Z geometry once per plane. This is
/// neither a general SVG loader nor per-frame path construction.
Path _authoredPath(String data) {
  final tokens = RegExp(r'[MLCZ]|-?(?:\d*\.)?\d+')
      .allMatches(data)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final path = Path()..fillType = PathFillType.evenOdd;
  var index = 0;
  double number() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    switch (tokens[index++]) {
      case 'M':
        path.moveTo(number(), number());
      case 'L':
        path.lineTo(number(), number());
      case 'C':
        path.cubicTo(
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
        );
      case 'Z':
        path.close();
      default:
        throw StateError('Unexpected authored Doodimo mark geometry');
    }
  }
  return path;
}
