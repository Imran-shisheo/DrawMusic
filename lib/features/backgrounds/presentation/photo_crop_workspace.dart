import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/strings.dart';
import '../domain/background.dart';

/// A local editing interaction. Only Apply publishes a document revision. The
/// original image remains intact; this maps gesture positions into source space.
class PhotoCropGesture {
  PhotoCropGesture({
    required this.paper,
    required this.imageSize,
    required this.viewport,
    required Offset focalPoint,
  }) {
    final crop = paper.crop;
    final target = paper.quarterTurns.isOdd
        ? Size(viewport.height, viewport.width)
        : viewport;
    final source = Rect.fromLTWH(
      crop.left * imageSize.width,
      crop.top * imageSize.height,
      crop.width * imageSize.width,
      crop.height * imageSize.height,
    );
    final ratio = math.max(
      target.width / source.width,
      target.height / source.height,
    );
    final cover = Rect.fromCenter(
      center: source.center,
      width: target.width / ratio,
      height: target.height / ratio,
    );
    visible = CropWindow(
      left: cover.left / imageSize.width,
      top: cover.top / imageSize.height,
      width: cover.width / imageSize.width,
      height: cover.height / imageSize.height,
    );
    final local = _local(focalPoint);
    anchor = Offset(
      visible.left + (local.dx / target.width + .5) * visible.width,
      visible.top + (local.dy / target.height + .5) * visible.height,
    );
  }
  final BackgroundDefinition paper;
  final Size imageSize, viewport;
  late final CropWindow visible;
  late final Offset anchor;
  Offset _local(Offset point) {
    var x = point.dx - viewport.width / 2, y = point.dy - viewport.height / 2;
    for (var i = 0; i < paper.quarterTurns; i++) {
      final previous = x;
      x = y;
      y = -previous;
    }
    if (paper.mirror) x = -x;
    return Offset(x, y);
  }

  CropWindow update(Offset focalPoint, double scale) {
    if (!scale.isFinite ||
        scale <= 0 ||
        !focalPoint.dx.isFinite ||
        !focalPoint.dy.isFinite) {
      return paper.crop;
    }
    // Extremely wide/tall images can have a visible cover thinner than the
    // model's five-percent crop floor. Retain a valid enclosing crop while
    // anchoring the actual visible cover, rather than jumping or throwing.
    final width = (visible.width / scale).clamp(.05, 1.0),
        height = (visible.height / scale).clamp(.05, 1.0);
    final target = paper.quarterTurns.isOdd
            ? Size(viewport.height, viewport.width)
            : viewport,
        local = _local(focalPoint);
    final ratio = math.max(
      target.width / (width * imageSize.width),
      target.height / (height * imageSize.height),
    );
    final viewWidth = target.width / ratio / imageSize.width,
        viewHeight = target.height / ratio / imageSize.height;
    return CropWindow(
      left:
          (anchor.dx -
                  (local.dx / target.width + .5) * viewWidth -
                  (width - viewWidth) / 2)
              .clamp(0, 1 - width),
      top:
          (anchor.dy -
                  (local.dy / target.height + .5) * viewHeight -
                  (height - viewHeight) / 2)
              .clamp(0, 1 - height),
      width: width,
      height: height,
    );
  }
}

class PhotoCropWorkspace extends StatefulWidget {
  const PhotoCropWorkspace({
    super.key,
    required this.paper,
    required this.image,
    required this.onChanged,
    required this.child,
  });
  final BackgroundDefinition paper;
  final ui.Image image;
  final ValueChanged<CropWindow> onChanged;
  final Widget child;
  @override
  State<PhotoCropWorkspace> createState() => _PhotoCropWorkspaceState();
}

class _PhotoCropWorkspaceState extends State<PhotoCropWorkspace> {
  final focus = FocusNode();
  PhotoCropGesture? gesture;
  bool focused = false;
  @override
  void didUpdateWidget(PhotoCropWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paper.quarterTurns != widget.paper.quarterTurns ||
        oldWidget.paper.mirror != widget.paper.mirror ||
        oldWidget.image != widget.image) {
      gesture = null;
    }
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  void _keyboard(Size viewport, Offset delta) {
    final center = viewport.center(Offset.zero);
    final edit = PhotoCropGesture(
      paper: widget.paper,
      imageSize: Size(
        widget.image.width.toDouble(),
        widget.image.height.toDouble(),
      ),
      viewport: viewport,
      focalPoint: center,
    );
    widget.onChanged(edit.update(center + delta, 1));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = Size(constraints.maxWidth, constraints.maxHeight);
      return Semantics(
        label: context.strings.cropWorkspace,
        hint: context.strings.cropMoveHint,
        focusable: true,
        child: FocusableActionDetector(
          focusNode: focus,
          onFocusChange: (value) => setState(() => focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowLeft): _CropPanIntent(
              Offset(-8, 0),
            ),
            SingleActivator(LogicalKeyboardKey.arrowRight): _CropPanIntent(
              Offset(8, 0),
            ),
            SingleActivator(LogicalKeyboardKey.arrowUp): _CropPanIntent(
              Offset(0, -8),
            ),
            SingleActivator(LogicalKeyboardKey.arrowDown): _CropPanIntent(
              Offset(0, 8),
            ),
          },
          actions: {
            _CropPanIntent: CallbackAction<_CropPanIntent>(
              onInvoke: (intent) {
                _keyboard(viewport, intent.delta);
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              focus.requestFocus();
              gesture = PhotoCropGesture(
                paper: widget.paper,
                imageSize: Size(
                  widget.image.width.toDouble(),
                  widget.image.height.toDouble(),
                ),
                viewport: viewport,
                focalPoint: details.localFocalPoint,
              );
            },
            onScaleUpdate: (details) {
              final current = gesture;
              if (current != null) {
                widget.onChanged(
                  current.update(details.localFocalPoint, details.scale),
                );
              }
            },
            onScaleEnd: (_) => gesture = null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _CropFramePainter(
                        Theme.of(context).colorScheme.primary,
                        focused,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CropPanIntent extends Intent {
  const _CropPanIntent(this.delta);
  final Offset delta;
}

class _CropFramePainter extends CustomPainter {
  const _CropFramePainter(this.color, this.focused);
  final Color color;
  final bool focused;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5), grid = Path();
    for (final fraction in [1 / 3, 2 / 3]) {
      grid.moveTo(rect.left + rect.width * fraction, rect.top);
      grid.lineTo(rect.left + rect.width * fraction, rect.bottom);
      grid.moveTo(rect.left, rect.top + rect.height * fraction);
      grid.lineTo(rect.right, rect.top + rect.height * fraction);
    }
    canvas.drawPath(
      grid,
      Paint()
        ..color = Colors.black.withValues(alpha: .35)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      grid,
      Paint()
        ..color = Colors.white.withValues(alpha: .72)
        ..strokeWidth = .7
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..color = Colors.black.withValues(alpha: .72)
        ..strokeWidth = focused ? 6 : 4
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..color = focused ? color : Colors.white
        ..strokeWidth = focused ? 3 : 1.5
        ..style = PaintingStyle.stroke,
    );
    // Physical-looking crop corners stay fixed to the document plane. These
    // are editing chrome only; the background renderer/export never sees them.
    final corners = Path();
    const length = 18.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final dx = corner.dx == rect.left ? 1.0 : -1.0;
      final dy = corner.dy == rect.top ? 1.0 : -1.0;
      corners
        ..moveTo(corner.dx + dx * length, corner.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx, corner.dy + dy * length);
    }
    canvas.drawPath(
      corners,
      Paint()
        ..color = color
        ..strokeWidth = focused ? 3.5 : 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CropFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.focused != focused;
}
