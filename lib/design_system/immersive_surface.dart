import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'motion.dart';

/// Bounded tactile graphite plate. Lighting is static; no backdrop blur.
class ImmersiveSurface extends StatelessWidget {
  const ImmersiveSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.glow = false,
    this.accent,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final edge = accent ?? colors.outline;
    return CustomPaint(
      foregroundPainter: _GraphiteEdgePainter(radius, dark),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [const Color(0xff343837), const Color(0xff111414)]
                : [const Color(0xfffffef8), const Color(0xffe2e5e1)],
          ),
          border: Border.all(color: edge.withValues(alpha: dark ? .55 : .48)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .28 : .08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
            if (glow)
              BoxShadow(
                color: edge.withValues(alpha: dark ? .09 : .05),
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const ExactAssetImage(
                  'assets/branding/graphite-grain.png',
                  scale: 2,
                ),
                repeat: ImageRepeat.repeat,
                opacity: dark ? .8 : .45,
                filterQuality: FilterQuality.none,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static scene lighting; no ticker and no document or canvas dependencies.
class SceneBackdrop extends StatelessWidget {
  const SceneBackdrop({super.key, required this.child, this.luminous = true});
  final Widget child;
  final bool luminous;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        gradient: luminous
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [const Color(0xff303435), DoodimoColors.ink]
                    : [const Color(0xfff7f7f0), const Color(0xffe4e7e3)],
                stops: const [0, 1],
              )
            : null,
      ),
      child: child,
    );
  }
}

class PrismAction extends StatefulWidget {
  const PrismAction({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.busy = false,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  State<PrismAction> createState() => _PrismActionState();
}

class _PrismActionState extends State<PrismAction> {
  bool _pressed = false, _focused = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: _pressed ? .985 : 1,
          duration: CreativeMotion.duration(context, CreativeMotion.press),
          curve: CreativeMotion.curve,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled
                    ? const [Color(0xffffab6b), Color(0xffec7d37)]
                    : const [Color(0xff636b65), Color(0xff4a534e)],
              ),
              border: Border.all(
                color: _focused
                    ? Colors.white
                    : const Color(0xffffd3ad).withValues(alpha: .9),
                width: _focused ? 2 : 1,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: DoodimoColors.orange.withValues(
                          alpha: _pressed ? .07 : .12,
                        ),
                        blurRadius: _pressed ? 4 : 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                onFocusChange: (value) => setState(() => _focused = value),
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 56,
                    minWidth: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    child: IconTheme(
                      data: const IconThemeData(color: DoodimoColors.ink),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.busy)
                            const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DoodimoColors.ink,
                              ),
                            )
                          else if (!largeText)
                            widget.icon,
                          if (widget.busy || !largeText)
                            const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: DoodimoColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The original shared 128px micrograin is bundled offline and decoded once.
// It repeats through an image paint; no filter layer, ticker or generated frame.
/// A machined rim: lit outside bevel, dark recessed seam, inner reflected edge.
class _GraphiteEdgePainter extends CustomPainter {
  const _GraphiteEdgePainter(this.radius, this.dark);
  final double radius;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < 6) return;
    final rect = (Offset.zero & size).deflate(1.8);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? .57 : .98),
          Colors.white.withValues(alpha: dark ? .06 : .30),
          Colors.black.withValues(alpha: dark ? .86 : .30),
        ],
        stops: const [0, .44, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      outer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(3),
        Radius.circular((radius - 3).clamp(0, double.infinity)),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: dark ? .72 : .16),
            Colors.white.withValues(alpha: dark ? .16 : .8),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GraphiteEdgePainter old) =>
      old.radius != radius || old.dark != dark;
}
