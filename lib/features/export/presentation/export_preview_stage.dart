import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../editor/presentation/canvas.dart';

/// A static, bounded stage for the actual frozen drawing. Lighting is chrome;
/// it never alters the document paper or suggests audio/export activity.
class ExportPreviewStage extends StatelessWidget {
  const ExportPreviewStage({
    super.key,
    required this.document,
    required this.accent,
    required this.extension,
    this.ready = false,
    this.transparentBackground = false,
  });

  final ProjectDocument document;
  final Color accent;
  final String extension;
  final bool ready;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ready
            ? 80.0
            : math.min(176.0, constraints.maxWidth * .58);
        final artwork = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateY(-.16)
            ..rotateX(.05)
            ..rotateZ(-.035),
          child: _artwork(context, width, dark),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: RadialGradient(
              center: const Alignment(.35, -.4),
              radius: 1,
              colors: dark
                  ? [const Color(0xff343264), const Color(0xff11162d)]
                  : [const Color(0xffdedbff), const Color(0xffe9efff)],
            ),
            border: Border.all(
              color: accent.withValues(alpha: dark ? .26 : .36),
            ),
          ),
          child: ready
              ? Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 24),
                      child: artwork,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DoodimoIcon(
                            DoodimoGlyph.check,
                            color: accent,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            extension,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            document.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    artwork,
                    const SizedBox(height: 24),
                    Text(
                      document.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _artwork(BuildContext context, double width, bool dark) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Transform.translate(
        offset: const Offset(7, 7),
        child: Container(
          width: width,
          height: width * 1.25,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: .85), const Color(0xff6550a7)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff090b18).withValues(alpha: .5),
                blurRadius: 24,
                offset: const Offset(10, 20),
              ),
            ],
          ),
        ),
      ),
      Transform.translate(
        offset: Offset(ready ? -5 : -14, ready ? -3 : -7),
        child: Transform.rotate(
          angle: -.095,
          child: Container(
            width: width + 8,
            height: width * 1.25,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .35),
                  const Color(0xff8b5cf6).withValues(alpha: .09),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: .45)),
            ),
          ),
        ),
      ),
      SizedBox(
        width: width,
        height: width * 1.25,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ExcludeSemantics(
            child: transparentBackground
                ? CustomPaint(
                    painter: const _TransparencyGrid(),
                    child: CustomPaint(painter: DrawingPainter(document)),
                  )
                : BackgroundSurface(
                    paper: document.effectiveBackground,
                    maxWidth: 352,
                    maxHeight: 440,
                    child: CustomPaint(painter: DrawingPainter(document)),
                  ),
          ),
        ),
      ),
      if (!ready)
        PositionedDirectional(
          bottom: -8,
          end: -20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? const Color(0xff171e38) : const Color(0xfff7f9ff),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: .6)),
            ),
            child: Text(
              extension,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
    ],
  );
}

/// Familiar checkerboard communicates removed paper; it is never exported.
class _TransparencyGrid extends CustomPainter {
  const _TransparencyGrid();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xfff3f5fb), BlendMode.src);
    final paint = Paint()..color = const Color(0xffd3d9e7);
    const tile = 10.0;
    for (var y = 0; y < size.height / tile; y++) {
      for (var x = 0; x < size.width / tile; x++) {
        if ((x + y).isEven) {
          canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile, tile), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyGrid oldDelegate) => false;
}
