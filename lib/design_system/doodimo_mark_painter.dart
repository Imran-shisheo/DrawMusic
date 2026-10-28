import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

// Authoritative authored SVG geometry. scripts/check-brand-icons.py verifies
// parity with assets/branding/mark.svg and the native generated resources.
const doodimoOrbitPathData =
    'M31 18 C57 10 83 25 83 49 C83 73 61 88 36 81 L25 71 L25 31 C25 25 26 20 31 18 Z M39 31 L39 59 L41 68 C56 73 68 63 68 49 C68 34 52 24 39 31 Z';
const doodimoFoldPathData =
    'M25 71 L39 59 L58 39 C61 36 66 37 68 40 L51 60 C45 67 38 73 36 81 Z';
const doodimoEdgePathData =
    'M38 24 C61 17 77 32 78 48 C78 69 59 82 39 76 L41 73 C60 77 74 64 74 48 C74 33 56 23 39 28 Z';

/// The original filled D/sound ribbon shared by launcher and in-app identity.
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
      const [Color(0xffb7a0ff), Color(0xff8b5cf6), Color(0xffef81c7)],
      const [0, .45, 1],
    );
  static final Paint _foldPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(29, 73),
      const Offset(64, 38),
      const [Color(0xff6672f5), Color(0xff55dff5), Color(0xffc6f8ff)],
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
        const [Color(0x6bf2ebff), Color(0x00f2ebff)],
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
