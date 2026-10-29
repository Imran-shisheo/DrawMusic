import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';
import 'layout.dart';
import 'doodimo_mark_painter.dart';
import 'brand.dart';
import 'doodimo_icon.dart';
import '../l10n/strings.dart';

/// The same compact instrument identity on Home and retained Library surfaces.
/// Natural text height is retained at200% and in translated/RTL interfaces.
class StudioHeader extends StatelessWidget {
  const StudioHeader({
    super.key,
    this.showSettings = true,
    this.showHelp = true,
  });
  final bool showSettings, showHelp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact =
            bounds.maxWidth < 350 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHelp)
              IconButton(
                tooltip: context.strings.replayCreationGuide,
                onPressed: () => context.push('/help'),
                icon: const DoodimoIcon(DoodimoGlyph.help),
              ),
            if (showSettings)
              IconButton(
                tooltip: context.strings.settings,
                onPressed: () => context.go('/settings'),
                icon: const DoodimoIcon(DoodimoGlyph.settings),
              ),
          ],
        );
        final identity = Row(
          children: [
            SketchMark(size: compact ? 36 : 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppBrand.displayName,
                    style: type.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    Text(
                      AppBrand.tagline,
                      style: type.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!compact) actions,
          ],
        );
        return compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  identity,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: actions,
                  ),
                ],
              )
            : identity;
      },
    );
  }
}

/// Original drawing-to-sound gesture, separate from document rendering.
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
          child: CustomPaint(painter: DoodimoMarkPainter(_motion)),
        ),
      ),
    ),
  );
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
