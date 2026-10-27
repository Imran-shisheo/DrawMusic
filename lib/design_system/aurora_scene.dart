import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'motion.dart';

/// Original decorative ribbon sculpture. Not a waveform, meter or music clock.
/// It has no document/provider dependency and never enters artwork renderers.
class AuroraScene extends StatefulWidget {
  const AuroraScene({super.key, this.animated = true});
  final bool animated;
  @override
  State<AuroraScene> createState() => _AuroraSceneState();
}

class _AuroraSceneState extends State<AuroraScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _cycle = AnimationController(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            painter: _AuroraPainter(
              _cycle,
              Theme.of(context).brightness == Brightness.dark,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.cycle, this.dark) : super(repaint: cycle);
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
    final aura = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * (.72 + math.sin(phase) * .05), size.height * .34),
        size.width * .7,
        dark
            ? const [Color(0x704f2b97), Color(0x00100e2a)]
            : const [Color(0x559f8bff), Color(0x00e8efff)],
      );
    canvas.drawRect(rect, aura);
    canvas.save();
    canvas.translate(
      math.sin(phase) * size.width * .014,
      math.cos(phase) * size.height * .016,
    );
    final ribbonWidth = math.min(size.width, size.height) * .085;
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.cycle != cycle;
}
