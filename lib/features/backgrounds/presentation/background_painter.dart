import 'dart:math' as math;
import 'dart:ui' as ui;

import '../domain/background.dart';

/// Shared document-coordinate picture used by editor, thumbnail and PNG.
/// White is the normal compositing base; transparent PNG can omit this renderer.
void paintBackground(
  ui.Canvas canvas,
  ui.Rect rect,
  BackgroundDefinition paper, {
  ui.Image? image,
  bool transparentBase = false,
}) {
  canvas.save();
  canvas.clipRect(rect);
  if (!transparentBase) {
    canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xffffffff));
  }
  final paint = ui.Paint()
    ..color = ui.Color(0xffffffff).withValues(alpha: paper.opacity);
  if (paper.kind == BackgroundKind.photo && image != null) {
    final crop = paper.crop;
    final source = ui.Rect.fromLTWH(
      crop.left * image.width,
      crop.top * image.height,
      crop.width * image.width,
      crop.height * image.height,
    );
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(paper.quarterTurns * math.pi / 2);
    if (paper.mirror) canvas.scale(-1, 1);
    final swapped = paper.quarterTurns.isOdd;
    final width = swapped ? rect.height : rect.width,
        height = swapped ? rect.width : rect.height;
    final ratio = math.max(width / source.width, height / source.height);
    final srcWidth = width / ratio, srcHeight = height / ratio;
    final cover = ui.Rect.fromCenter(
      center: source.center,
      width: srcWidth,
      height: srcHeight,
    );
    canvas.drawImageRect(
      image,
      cover,
      ui.Rect.fromCenter(center: ui.Offset.zero, width: width, height: height),
      paint..filterQuality = ui.FilterQuality.medium,
    );
  } else {
    final colors = [for (final color in paper.colors) ui.Color(color)];
    if (paper.kind == BackgroundKind.linear ||
        paper.kind == BackgroundKind.radial) {
      if (colors.length == 1) colors.add(colors.first);
      // dart:ui requires explicit stops for three/four-color documents. Native
      // Android/iOS renderers use the same evenly spaced interpolation policy.
      final stops = [
        for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
      ];
      paint.shader = paper.kind == BackgroundKind.linear
          ? ui.Gradient.linear(rect.topLeft, rect.bottomRight, colors, stops)
          : ui.Gradient.radial(
              rect.center,
              rect.longestSide / 2,
              colors,
              stops,
            );
      // Shader colors preserve each stop's alpha; opacity is an independent mix.
      if (paper.opacity < 1) {
        canvas.saveLayer(
          rect,
          ui.Paint()
            ..color = ui.Color(0xffffffff).withValues(alpha: paper.opacity),
        );
      }
      canvas.drawRect(rect, ui.Paint()..shader = paint.shader);
      if (paper.opacity < 1) canvas.restore();
    } else {
      final color = colors.first;
      canvas.drawRect(
        rect,
        ui.Paint()..color = color.withValues(alpha: color.a * paper.opacity),
      );
    }
  }
  canvas.restore();
}
