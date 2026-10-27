import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'layout.dart';

/// Original decorative line-to-wave. It never reads or paints a document.
class SketchMark extends StatefulWidget {
  const SketchMark({super.key, this.size = 64, this.animated = false});
  final double size;
  final bool animated;
  @override
  State<SketchMark> createState() => _SketchMarkState();
}

class _SketchMarkState extends State<SketchMark>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: CreativeMotion.ambient,
  );
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
  void didUpdateWidget(SketchMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final active =
        widget.animated &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (active && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!active) {
      _motion.stop();
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
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _SketchPainter(
              _motion,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.motion, this.line, this.endpoint)
    : super(repaint: motion);
  final Animation<double> motion;
  final Color line, endpoint;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final drift = math.sin(motion.value * math.pi * 2) * 3;
    final path = Path()
      ..moveTo(10, 62)
      ..cubicTo(23, 25 + drift, 46, 23, 47, 48)
      ..cubicTo(48, 75, 18, 74, 26, 51)
      ..cubicTo(34, 30, 48, 83 + drift, 60, 55)
      ..cubicTo(66, 35 + drift, 69, 27, 75, 51)
      ..cubicTo(80, 75, 85, 63, 91, 40);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(91, 40), 3.6, Paint()..color = endpoint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SketchPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.endpoint != endpoint;
}

class CreativeEmptyState extends StatelessWidget {
  const CreativeEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(CreativeSpace.section),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SketchMark(size: 100),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}
