import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../editor/presentation/canvas.dart';

/// One anchored view of the frozen export snapshot. The stage stays mounted
/// through settings, work, errors and success; its lighting is never artwork.
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
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(160.0, constraints.maxWidth * .64);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.surfaceContainerHigh, colors.surface],
            ),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.outline.withValues(alpha: .65),
                        colors.surface,
                        colors.outlineVariant,
                      ],
                      stops: const [0, .5, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? .5 : .15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: width,
                    height: width * 1.25,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ExcludeSemantics(
                        child: RepaintBoundary(
                          key: const ValueKey('export-frozen-artwork'),
                          child: transparentBackground
                              ? CustomPaint(
                                  painter: const _TransparencyGrid(),
                                  child: CustomPaint(
                                    painter: DrawingPainter(document),
                                  ),
                                )
                              : BackgroundSurface(
                                  paper: document.effectiveBackground,
                                  maxWidth: 360,
                                  maxHeight: 450,
                                  child: CustomPaint(
                                    painter: DrawingPainter(document),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      height: 32,
                      child: ready
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _ReadySeal(
                                key: const ValueKey('export-finalized-seal'),
                                accent: accent,
                              ),
                            )
                          : null,
                    ),
                    Text(
                      extension,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bounded original confirmation ink, mounted only after a real artifact is
/// finalized. It does not drive, predict or substitute for export progress.
class _ReadySeal extends StatefulWidget {
  const _ReadySeal({super.key, required this.accent});
  final Color accent;
  @override
  State<_ReadySeal> createState() => _ReadySealState();
}

class _ReadySealState extends State<_ReadySeal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _arrival.stop();
      _arrival.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _arrival.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _arrival.stop();
      _arrival.value = 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ReadyInk(_arrival, widget.accent),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: DoodimoIcon(
                DoodimoGlyph.check,
                size: 20,
                color: widget.accent,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReadyInk extends CustomPainter {
  _ReadyInk(this.animation, this.accent) : super(repaint: animation);
  final Animation<double> animation;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(animation.value);
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      12 + 3 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = accent.withValues(alpha: .28 + .35 * (1 - t)),
    );
    // Short arcs gather into the finished seal instead of spraying confetti.
    if (t < 1) {
      final bounds = Rect.fromCircle(center: center, radius: 15 + 2 * t);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 1 - t);
      canvas.drawArc(bounds, -.8 + t, .5, false, paint);
      canvas.drawArc(bounds, math.pi + t, .5, false, paint);
    }
  }

  @override
  bool shouldRepaint(_ReadyInk oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.animation != animation;
}

/// Familiar checkerboard communicates removed paper; it is never exported.
class _TransparencyGrid extends CustomPainter {
  const _TransparencyGrid();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xfff2f1ed), BlendMode.src);
    final paint = Paint()..color = const Color(0xffd4d3cf);
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
