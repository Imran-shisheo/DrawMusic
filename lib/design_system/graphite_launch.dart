import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// A finite, input-transparent opening composition over the ready application.
/// [preferencesReady] means the stored motion setting is known; while it is not,
/// only the unchanged child is shown. No startup/provider/audio work lives here.
///
/// One instance consumes its opening on completion, first input, hidden/background
/// lifecycle or reduced motion. Theme changes and warm resume never replay it.
class GraphiteLaunch extends StatefulWidget {
  const GraphiteLaunch({
    super.key,
    required this.preferencesReady,
    required this.reduceMotion,
    required this.child,
    this.enabled = true,
  });

  final bool preferencesReady;
  final bool reduceMotion;
  final bool enabled;
  final Widget child;

  @override
  State<GraphiteLaunch> createState() => _GraphiteLaunchState();
}

class _GraphiteLaunchState extends State<GraphiteLaunch>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: CreativeMotion.launch,
  )..addStatusListener(_status);
  var _consumed = false;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcile();
  }

  @override
  void didUpdateWidget(GraphiteLaunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
  }

  void _reconcile() {
    if (_consumed) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!widget.enabled ||
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _finish(rebuild: false);
      return;
    }
    if (!widget.preferencesReady || _visible) return;
    _visible = true;
    _progress.forward();
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed && _visible && mounted) {
      setState(() {
        _consumed = true;
        _visible = false;
      });
    }
  }

  void _finish({bool rebuild = true}) {
    if (_consumed) return;
    final wasVisible = _visible;
    _consumed = true;
    _visible = false;
    _progress.stop();
    _progress.value = 1;
    if (rebuild && wasVisible && mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _finish();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _finish(),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_visible)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (context, bounds) => Align(
                      alignment: const Alignment(0, -.22),
                      child: RepaintBoundary(
                        key: const ValueKey('graphite-launch-decoration'),
                        child: SizedBox(
                          width: math.min(320, bounds.maxWidth * .84),
                          height: math.min(300, bounds.maxHeight * .46),
                          child: CustomPaint(
                            painter: _GestureSeedPainter(
                              _progress,
                              colors.primary,
                              colors.onSurface,
                            ),
                          ),
                        ),
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
}

/// Original unit-geometry gesture becoming a bounded drawing/controls motif.
/// This is finite branding, never an audio waveform, progress meter or artwork.
class _GestureSeedPainter extends CustomPainter {
  _GestureSeedPainter(this.progress, this.accent, this.ink)
    : super(repaint: progress);
  final Animation<double> progress;
  final Color accent, ink;

  static double _phase(double value, double begin, double end) =>
      ((value - begin) / (end - begin)).clamp(0, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final seed = _phase(t, 0, .127);
    final expand = _phase(t, .127, .4);
    final gather = _phase(t, .4, .564);
    final reform = _phase(t, .564, .818);
    final settle = _phase(t, .818, 1);
    final opacity = seed * (1 - Curves.easeIn.transform(settle));
    if (opacity <= 0) return;

    final scale = t < .4
        ? .38 + .65 * Curves.easeOutBack.transform(expand)
        : (1.03 - .2 * Curves.easeInOut.transform(gather)) + .17 * reform;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height / 2);

    Offset point(double x, double y) => Offset(x * size.width, y * size.height);
    final drawing = Path()
      ..moveTo(size.width * .14, size.height * .77)
      ..cubicTo(
        size.width * .44,
        size.height * .79,
        size.width * .49,
        size.height * .24,
        size.width * .84,
        size.height * .2,
      );
    final secondary = Path()
      ..moveTo(size.width * .1, size.height * .7)
      ..cubicTo(
        size.width * .27,
        size.height * .12,
        size.width * .51,
        size.height * .29,
        size.width * .88,
        size.height * .7,
      );
    final quiet = Path()
      ..moveTo(size.width * .18, size.height * .82)
      ..cubicTo(
        size.width * .43,
        size.height * .91,
        size.width * .64,
        size.height * .55,
        size.width * .88,
        size.height * .78,
      );
    final reveal = .24 + .76 * Curves.easeOutCubic.transform(expand);
    final drawingOpacity = opacity * (1 - .72 * reform);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in drawing.computeMetrics()) {
      final visible = metric.extractPath(0, metric.length * reveal);
      canvas.drawPath(
        visible,
        stroke
          ..color = accent.withValues(alpha: drawingOpacity * .09)
          ..strokeWidth = 15,
      );
      canvas.drawPath(
        visible,
        stroke
          ..color = accent.withValues(alpha: drawingOpacity * .92)
          ..strokeWidth = 4.5,
      );
      final tip = metric.getTangentForOffset(metric.length * reveal)?.position;
      if (tip != null) {
        canvas.drawCircle(
          tip,
          4,
          Paint()..color = accent.withValues(alpha: drawingOpacity),
        );
      }
    }
    if (expand > 0) {
      canvas.drawPath(
        secondary,
        stroke
          ..strokeWidth = 1.8
          ..color = ink.withValues(alpha: expand * drawingOpacity * .32),
      );
      canvas.drawPath(
        quiet,
        stroke
          ..strokeWidth = 1.1
          ..color = ink.withValues(alpha: expand * drawingOpacity * .18),
      );
    }
    if (reform > 0) {
      final eased = Curves.easeOutCubic.transform(reform);
      for (var i = 0; i < 7; i++) {
        final start = point(.24 + .085 * i, .65 - .06 * i);
        final end = point(.08 + .14 * i, i.isEven ? .88 : .12);
        final location = Offset.lerp(start, end, eased)!;
        canvas.drawCircle(
          location,
          2.5 * (1 - .45 * eased),
          Paint()..color = accent.withValues(alpha: opacity * (1 - .7 * eased)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GestureSeedPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.ink != ink;
}
