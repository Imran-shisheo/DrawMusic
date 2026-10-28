import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../design_system/brand_colors.dart';
import '../../../l10n/strings.dart';
import '../data/background_assets.dart';
import '../domain/background.dart';
import 'background_painter.dart';

/// Each visible surface owns a bounded decode; revisions/history retain only the
/// immutable asset identifier. Late decodes cannot replace a newer document.
class BackgroundSurface extends StatefulWidget {
  const BackgroundSurface({
    super.key,
    required this.paper,
    this.child,
    this.assets,
    this.maxWidth = 1080,
    this.maxHeight = 1350,
    this.showMissingIndicator = true,
  });
  final BackgroundDefinition paper;
  final Widget? child;
  final BackgroundAssets? assets;
  final int maxWidth, maxHeight;
  final bool showMissingIndicator;
  @override
  State<BackgroundSurface> createState() => _BackgroundSurfaceState();
}

class _BackgroundSurfaceState extends State<BackgroundSurface> {
  ui.Image? image;
  int generation = 0;
  bool missing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BackgroundSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paper.assetId != widget.paper.assetId ||
        oldWidget.paper.kind != widget.paper.kind ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.maxHeight != widget.maxHeight ||
        oldWidget.assets != widget.assets) {
      _load();
    }
  }

  Future<void> _load() async {
    final token = ++generation;
    ui.Image? next;
    try {
      next = await loadBackgroundImage(
        widget.paper,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        assets: widget.assets,
      );
    } catch (_) {
      /* Preserve drawing access; Replace/Remove live in the panel. */
    }
    if (!mounted || token != generation) {
      next?.dispose();
      return;
    }
    final previous = image;
    setState(() {
      image = next;
      missing = widget.paper.kind == BackgroundKind.photo && next == null;
    });
    previous?.dispose();
  }

  @override
  void dispose() {
    generation++;
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SurfacePainter(widget.paper, image),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (widget.child != null) widget.child!,
        if (missing && widget.showMissingIndicator)
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Semantics(
                label: context.strings.imageUnavailable,
                image: true,
                excludeSemantics: true,
                // Document paper is independent of chrome brightness. Keep the
                // essential image silhouette legible on every fallback color.
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: DoodimoColors.indigo,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: IconTheme(
                      data: IconThemeData(
                        color: Colors.white,
                        opacity: 1,
                        size: 24,
                      ),
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SurfacePainter extends CustomPainter {
  const _SurfacePainter(this.paper, this.image);
  final BackgroundDefinition paper;
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) =>
      paintBackground(canvas, Offset.zero & size, paper, image: image);
  @override
  bool shouldRepaint(_SurfacePainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.image != image;
}
