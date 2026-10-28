import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'motion.dart';

/// Original decorative ribbon sculpture. Not a waveform, meter or music clock.
/// It has no document/provider dependency and never enters artwork renderers.
class AuroraScene extends StatefulWidget {
  const AuroraScene({super.key, this.animated = true, this.rasterizeStatic});
  final bool animated;

  /// Deterministic completion control for resource-lifetime tests only. Normal
  /// product and profile paths always use the engine's Picture.toImage.
  @visibleForTesting
  final Future<ui.Image> Function(ui.Picture, int, int)? rasterizeStatic;
  @override
  State<AuroraScene> createState() => _AuroraSceneState();
}

class _AuroraSceneState extends State<AuroraScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: CreativeMotion.ambient,
  );
  // One resident static texture plus at most one in-flight replacement. Each
  // allocation is <=1,048,576 pixels (~4MiB RGBA), capped at2048 per dimension.
  // Vector geometry and original paint remain the exact first-frame/failure
  // fallback. No decorative frame cadence or animation clock is changed.
  _AuroraRasterKey? _wantedRaster, _readyRaster, _failedRaster;
  ui.Image? _staticRaster;
  bool _rasterScheduled = false, _rasterBusy = false, _rasterAllowed = false;

  void _requestRaster(_AuroraRasterKey key) {
    _wantedRaster = key;
    if (!_rasterAllowed) return;
    if (_readyRaster == key ||
        _failedRaster == key ||
        _rasterBusy ||
        _rasterScheduled) {
      return;
    }
    _rasterScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rasterScheduled = false;
      if (!mounted || !_rasterAllowed) return;
      final wanted = _wantedRaster;
      if (wanted == null ||
          wanted == _readyRaster ||
          wanted == _failedRaster ||
          _rasterBusy) {
        return;
      }
      unawaited(_rasterize(wanted));
    });
  }

  Future<void> _rasterize(_AuroraRasterKey key) async {
    _rasterBusy = true;
    ui.Picture? picture;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(
        key.pixelWidth / key.extent.width,
        key.pixelHeight / key.extent.height,
      );
      canvas.translate(key.overscan.dx, key.overscan.dy);
      _AuroraPainter(
        _cycle,
        key.dark,
        staticLayer: true,
      ).paint(canvas, key.size);
      picture = recorder.endRecording();
      final rasterize = widget.rasterizeStatic;
      final image = rasterize == null
          ? await picture.toImage(key.pixelWidth, key.pixelHeight)
          : await rasterize(picture, key.pixelWidth, key.pixelHeight);
      if (!mounted || _wantedRaster != key) {
        image.dispose();
      } else {
        final previous = _staticRaster;
        setState(() {
          _staticRaster = image;
          _readyRaster = key;
          _failedRaster = null;
        });
        // RawImage retains its own clone while its existing render object is
        // being replaced, so disposing this owner cannot invalidate a frame.
        previous?.dispose();
      }
    } catch (_) {
      // Preserve the original luminous vector scene on unavailable allocation.
      // Retry only for a different size/theme/raster scale, never every tick.
      if (mounted && _wantedRaster == key) _failedRaster = key;
    } finally {
      picture?.dispose();
      _rasterBusy = false;
      if (mounted) {
        final wanted = _wantedRaster;
        if (wanted != null) _requestRaster(wanted);
      }
    }
  }

  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AuroraScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final active =
        widget.animated &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _rasterAllowed = active;
    if (active && _wantedRaster != null) _requestRaster(_wantedRaster!);
    if (active && !_cycle.isAnimating) {
      _cycle.repeat();
    }
    if (!active) {
      _cycle.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cycle.dispose();
    _staticRaster?.dispose();
    _staticRaster = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final size = Size(bounds.maxWidth, bounds.maxHeight);
              if (size.isEmpty || !size.isFinite) {
                return const SizedBox.shrink();
              }
              final dark = Theme.of(context).brightness == Brightness.dark;
              final rasterKey = _AuroraRasterKey(
                size,
                dark,
                MediaQuery.devicePixelRatioOf(context),
              );
              _requestRaster(rasterKey);
              final image = _readyRaster == rasterKey ? _staticRaster : null;
              return AnimatedBuilder(
                animation: _cycle,
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      if (image == null)
                        RepaintBoundary(
                          child: CustomPaint(
                            isComplex: true,
                            painter: _AuroraPainter(
                              _cycle,
                              dark,
                              staticLayer: true,
                            ),
                          ),
                        )
                      else
                        Positioned(
                          left: -rasterKey.overscan.dx,
                          top: -rasterKey.overscan.dy,
                          width: rasterKey.extent.width,
                          height: rasterKey.extent.height,
                          child: RawImage(
                            image: image,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      // The small changing highlight/orbits get their own
                      // repaint boundary: no static/home display-list rebuild.
                      RepaintBoundary(
                        child: CustomPaint(
                          willChange: true,
                          painter: _AuroraPainter(_cycle, dark),
                        ),
                      ),
                    ],
                  ),
                ),
                builder: (context, child) {
                  final phase = _cycle.value * math.pi * 2;
                  return Transform.translate(
                    offset: Offset(
                      math.sin(phase) * size.width * .014,
                      math.cos(phase) * size.height * .016,
                    ),
                    child: child,
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _AuroraRasterKey {
  _AuroraRasterKey(this.size, this.dark, double devicePixelRatio) {
    // Preserve the tiny whole-sculpture translation without clipping the
    // original ribbon's off-canvas strokes into the texture's edge.
    overscan = Offset(
      (size.width * .014).ceilToDouble() + 2,
      (size.height * .016).ceilToDouble() + 2,
    );
    extent = Size(size.width + overscan.dx * 2, size.height + overscan.dy * 2);
    final scale = math.min(
      devicePixelRatio.clamp(1.0, 2.0),
      math.min(
        math.sqrt(1048576 / (extent.width * extent.height)),
        2048 / math.max(extent.width, extent.height),
      ),
    );
    pixelWidth = math.max(1, (extent.width * scale).floor());
    pixelHeight = math.max(1, (extent.height * scale).floor());
  }
  final Size size;
  final bool dark;
  late final Offset overscan;
  late final Size extent;
  late final int pixelWidth, pixelHeight;
  @override
  bool operator ==(Object other) =>
      other is _AuroraRasterKey &&
      other.size == size &&
      other.dark == dark &&
      other.pixelWidth == pixelWidth &&
      other.pixelHeight == pixelHeight;
  @override
  int get hashCode => Object.hash(size, dark, pixelWidth, pixelHeight);
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.cycle, this.dark, {this.staticLayer = false})
    : super(repaint: staticLayer ? null : cycle);
  final bool staticLayer;
  final Animation<double> cycle;
  final bool dark;
  Size? _size;
  late Path _ribbon, _echo;
  late List<ui.PathMetric> _metrics;
  void _geometry(Size size) {
    if (_size == size) return;
    _size = size;
    final w = size.width, h = size.height;
    _ribbon = Path()
      ..moveTo(-w * .1, h * .65)
      ..cubicTo(w * .28, h * .95, w * .08, h * .04, w * .53, h * .22)
      ..cubicTo(w * .95, h * .38, w * .38, h * .95, w * .76, h * .69)
      ..cubicTo(w * .99, h * .53, w * .87, h * .19, w * 1.12, h * .29);
    _echo = Path()
      ..moveTo(w * .18, h * .9)
      ..cubicTo(w * .5, h * .7, w * .65, h * .02, w * 1.1, h * .09);
    _metrics = _ribbon.computeMetrics().toList(growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _geometry(size);
    final rect = Offset.zero & size;
    final phase = cycle.value * math.pi * 2;
    final ribbonWidth = math.min(size.width, size.height) * .085;
    if (staticLayer) {
      final aura = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .72, size.height * .34),
          size.width * .7,
          dark
              ? const [Color(0x704f2b97), Color(0x00100e2a)]
              : const [Color(0x559f8bff), Color(0x00e8efff)],
        );
      canvas.drawRect(rect, aura);
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: dark ? .32 : .09)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ribbonWidth + 8;
      canvas.save();
      canvas.translate(0, 7);
      canvas.drawPath(_ribbon, shadow);
      canvas.restore();
      canvas.drawPath(
        _echo,
        Paint()
          ..color = DoodimoColors.cyan.withValues(alpha: dark ? .16 : .24)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ribbonWidth * .35,
      );
      canvas.drawPath(
        _ribbon,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(size.width * .1, size.height * .8),
            Offset(size.width, size.height * .2),
            const [
              Color(0xff5c2bbb),
              Color(0xffa478ff),
              Color(0xff6b66f6),
              Color(0xff55dff5),
            ],
            const [0, .34, .67, 1],
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = ribbonWidth,
      );
      canvas.drawPath(
        _ribbon,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, size.height),
            [
              Colors.white.withValues(alpha: .55),
              Colors.white.withValues(alpha: .02),
              DoodimoColors.cyan.withValues(alpha: .55),
            ],
            const [0, .55, 1],
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.2,
      );
      return;
    }
    for (final metric in _metrics) {
      final start = cycle.value * metric.length;
      final end = start + metric.length * .12;
      final pen = Paint()
        ..color = const Color(0xffd1faff).withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ribbonWidth * .14;
      canvas.drawPath(
        metric.extractPath(start, math.min(metric.length, end)),
        pen,
      );
      if (end > metric.length) {
        canvas.drawPath(metric.extractPath(0, end - metric.length), pen);
      }
    }
    for (var i = 0; i < 3; i++) {
      final angle = phase + i * 2.1;
      final point = Offset(
        size.width * (.55 + math.cos(angle) * .32),
        size.height * (.48 + math.sin(angle) * .33),
      );
      canvas.drawCircle(
        point,
        4 + i.toDouble(),
        Paint()
          ..color = [
            DoodimoColors.cyan,
            DoodimoColors.pink,
            const Color(0xffb6a2ff),
          ][i].withValues(alpha: dark ? .75 : .65),
      );
      canvas.drawCircle(
        point,
        9 + i.toDouble(),
        Paint()..color = DoodimoColors.cyan.withValues(alpha: .06),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.staticLayer != staticLayer ||
      (!staticLayer && oldDelegate.cycle != cycle);
}
