import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../creative_document/document.dart';
import '../domain/export_port.dart';
import '../../backgrounds/domain/background.dart';
import '../../backgrounds/data/background_assets.dart';
import '../../backgrounds/presentation/background_painter.dart';

/// A single bounded document-coordinate raster, with no widget chrome/cursor.
/// At the largest allowed size the raw pixel allocation is 5,832,000 bytes.
Future<Uint8List> renderDocumentPng(
  ProjectDocument document,
  ExportCancellation cancellation, {
  int width = 1080,
  bool transparentBackground = false,
  void Function(double)? onProgress,
  BackgroundAssets? assets,
}) async {
  if (width != 640 && width != 1080) {
    throw const FormatException('Unsupported PNG dimensions');
  }
  cancellation.check();
  final height = width * 5 ~/ 4;
  final size = ui.Size(width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  ui.Picture? picture;
  ui.Image? image, backgroundImage;
  try {
    final canvas = ui.Canvas(recorder)..clipRect(ui.Offset.zero & size);
    if (!transparentBackground) {
      final paper =
          document.paper ?? BackgroundDefinition.solid(document.background);
      if (paper.kind == BackgroundKind.photo) {
        backgroundImage = await loadBackgroundImage(
          paper,
          maxWidth: width,
          maxHeight: height,
          assets: assets,
        );
      }
      cancellation.check();
      if (paper.kind == BackgroundKind.photo && backgroundImage == null) {
        throw const FormatException(
          'Background image is missing; replace or remove it before exporting',
        );
      }
      paintBackground(
        canvas,
        ui.Offset.zero & size,
        paper,
        image: backgroundImage,
      );
    }
    for (var i = 0; i < document.strokes.length; i++) {
      final stroke = document.strokes[i];
      paintDocumentStroke(canvas, size, stroke, document.style);
      if (i % 64 == 0) {
        onProgress?.call(.1 + .4 * (i + 1) / document.strokes.length);
        // Yield between bounded batches so cancellation is actionable for dense
        // drawings, without one Future/allocation for each point.
        await Future<void>.delayed(Duration.zero);
        cancellation.check();
      }
    }
    picture = recorder.endRecording();
    cancellation.check();
    onProgress?.call(.6);
    image = await picture.toImage(width, height);
    cancellation.check();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    cancellation.check();
    if (bytes == null) throw const FormatException('PNG encoding failed');
    onProgress?.call(.85);
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image?.dispose();
    backgroundImage?.dispose();
    picture?.dispose();
    if (recorder.isRecording) recorder.endRecording().dispose();
  }
}

/// Normalized geometry and the same fixed Pixel grid as canvas/video rendering.
void paintDocumentStroke(
  ui.Canvas canvas,
  ui.Size size,
  Stroke stroke,
  DrawingStyle style,
) {
  final paint = ui.Paint()
    ..color = ui.Color(stroke.instrument.definition.color);
  if (style == DrawingStyle.pixel) {
    paint.isAntiAlias = false;
    for (final cell in stroke.displayPixels) {
      final x = cell % 40, y = cell ~/ 40;
      canvas.drawRect(
        ui.Rect.fromLTRB(
          x * size.width / 40,
          y * size.height / 50,
          (x + 1) * size.width / 40,
          (y + 1) * size.height / 50,
        ),
        paint,
      );
    }
    return;
  }
  paint
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeWidth = stroke.width * size.width;
  ui.Offset at(InkPoint p) => ui.Offset(p.u * size.width, p.v * size.height);
  if (stroke.points.length == 1) {
    canvas.drawCircle(
      at(stroke.points.first),
      paint.strokeWidth / 2,
      paint..style = ui.PaintingStyle.fill,
    );
    return;
  }
  final first = at(stroke.points.first);
  final path = ui.Path()..moveTo(first.dx, first.dy);
  for (final point in stroke.points.skip(1)) {
    final p = at(point);
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, paint);
}
