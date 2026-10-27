import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'motion.dart';

/// Bounded layered ink/glass finish, without a full-screen backdrop blur.
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
    final edge = accent ?? DoodimoColors.violet;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xff202746), const Color(0xff11172c)]
              : [const Color(0xfffdfdff), const Color(0xffe9edff)],
        ),
        border: Border.all(color: edge.withValues(alpha: dark ? .35 : .25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .28 : .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (glow)
            BoxShadow(
              color: edge.withValues(alpha: dark ? .16 : .08),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
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
    final decoration = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      gradient: luminous
          ? RadialGradient(
              center: const Alignment(.7, -.9),
              radius: 1.1,
              colors: dark
                  ? [const Color(0xff21204a), DoodimoColors.ink]
                  : [const Color(0xffdfe3ff), const Color(0xfff4f7ff)],
              stops: const [0, 1],
            )
          : null,
    );
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: _SceneLighting(decoration: decoration),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Owns only the static scene paint; descendants never enter this display list.
class _SceneLighting extends StatefulWidget {
  const _SceneLighting({required this.decoration});
  final BoxDecoration decoration;
  @override
  State<_SceneLighting> createState() => _SceneLightingState();
}

class _SceneLightingState extends State<_SceneLighting> {
  late BoxPainter _painter = widget.decoration.createBoxPainter();
  @override
  void didUpdateWidget(_SceneLighting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decoration != widget.decoration) {
      _painter.dispose();
      _painter = widget.decoration.createBoxPainter();
    }
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SceneLightingPainter(
      widget.decoration,
      _painter,
      createLocalImageConfiguration(context),
    ),
    isComplex: true,
    willChange: false,
  );
}

class _SceneLightingPainter extends CustomPainter {
  const _SceneLightingPainter(
    this.decoration,
    this.boxPainter,
    this.configuration,
  );
  final BoxDecoration decoration;
  final BoxPainter boxPainter;
  final ImageConfiguration configuration;
  @override
  void paint(Canvas canvas, Size size) =>
      boxPainter.paint(canvas, Offset.zero, configuration.copyWith(size: size));
  @override
  bool shouldRepaint(_SceneLightingPainter oldDelegate) =>
      oldDelegate.decoration != decoration ||
      oldDelegate.configuration != configuration;
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
                    ? const [Color(0xffbda4ff), Color(0xff86e8f7)]
                    : const [Color(0xff48506c), Color(0xff38435c)],
              ),
              border: Border.all(
                color: _focused
                    ? Colors.white
                    : const Color(0xffddd4ff).withValues(alpha: .7),
                width: _focused ? 2 : 1,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: DoodimoColors.violet.withValues(
                          alpha: _pressed ? .1 : .26,
                        ),
                        blurRadius: _pressed ? 8 : 20,
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
