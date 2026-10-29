import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'doodimo_icon.dart';
import 'motion.dart';
import 'immersive_surface.dart';

/// Structural accessibility hint, never a replacement for measuring content.
/// System scaling can be nonlinear; its preference is compared only, while
/// rendered text below always retains the original TextScaler.
bool prefersExpandedTextLayout(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  return switch (scaler) {
    SystemTextScaler(:final textScaleFactor) => textScaleFactor >= 1.5,
    _ => scaler.scale(10) >= 15 || scaler.scale(14) >= 21,
  };
}

/// A layered navigation instrument. Branch navigators belong to the router.
class CreativeDock extends StatelessWidget {
  const CreativeDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCreate,
    required this.labels,
    required this.createLabel,
    this.rail = false,
    this.compactCreateLabel,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreate;
  final List<String> labels;
  final String createLabel;
  final bool rail;
  final String? compactCreateLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final style = Theme.of(context).textTheme.labelMedium!
          .copyWith(fontWeight: FontWeight.w700, height: 1.2);
      final expandedText = prefersExpandedTextLayout(context);
      const order = [
        0,
        1,
        3,
        2,
      ]; // Create is physically between Library and Settings.
      final allLabels = [...labels, createLabel];
      if (rail) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xff303334), Color(0xff171b1c)]
                  : const [Color(0xfffafaf2), Color(0xffdfe5d9)],
            ),
            border: Border.all(color: colors.primary.withValues(alpha: .4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                for (final role in order)
                  Expanded(
                    child: _DockKey(
                      key: ValueKey(
                        [
                          'nav-home',
                          'nav-library',
                          'nav-settings',
                          'root-new-drawing',
                        ][role],
                      ),
                      label: role == 3
                          ? compactCreateLabel ?? createLabel
                          : labels[role],
                      semanticLabel: role == 3 ? createLabel : null,
                      glyph: [
                        DoodimoGlyph.home,
                        DoodimoGlyph.library,
                        DoodimoGlyph.settings,
                        DoodimoGlyph.add,
                      ][role],
                      selected: role == selectedIndex,
                      create: role == 3,
                      horizontal: true,
                      raised: false,
                      rail: true,
                      style: style,
                      onTap: role == 3
                          ? onCreate
                          : () => onDestinationSelected(role),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      // Subtract the actual decorative shell padding before measuring keys.
      final contentWidth = math.max(1.0, constraints.maxWidth - 12);
      var longest = 0.0;
      for (final label in allLabels) {
        for (final word in label.split(RegExp(r'\s+'))) {
          final text = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          longest = math.max(longest, text.width);
          text.dispose();
        }
      }
      final fitsFour = longest <= contentWidth / 4 - 8;
      final fitsTwo = longest <= contentWidth / 2 - 8;
      // A narrow accessibility layout uses full-width horizontal keys. Normal
      // compact phones still use two columns when their words fit. This does
      // not rely on a single sampled font size crossing a strict threshold.
      final columns = !expandedText && contentWidth >= 320 && fitsFour
          ? 4
          : fitsTwo && !(expandedText && contentWidth < 320)
          ? 2
          : 1;
      final fullRows = columns == 1;
      final adaptive = columns != 4;
      final slot = contentWidth / columns;
      var keyHeight = fullRows ? 54.0 : 78.0;
      for (var role = 0; role < allLabels.length; role++) {
        final reserved = fullRows
            ? 24.0 + 42 + 14 + (role == selectedIndex ? 18 : 0)
            : (role == 3 ? 20.0 : 8.0);
        final text = TextPainter(
          text: TextSpan(text: allLabels[role], style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, slot - reserved));
        keyHeight = math.max(
          keyHeight,
          text.height +
              (fullRows ? (role == 3 ? 18 : 12) : (role == 3 ? 64 : 58)),
        );
        text.dispose();
      }
      Widget tile(int role) => _DockKey(
        key: ValueKey(
          ['nav-home', 'nav-library', 'nav-settings', 'root-new-drawing'][role],
        ),
        label: allLabels[role],
        glyph: [
          DoodimoGlyph.home,
          DoodimoGlyph.library,
          DoodimoGlyph.settings,
          DoodimoGlyph.add,
        ][role],
        selected: role == selectedIndex,
        create: role == 3,
        horizontal: fullRows,
        raised: !adaptive && role == 3,
        style: style,
        onTap: role == 3 ? onCreate : () => onDestinationSelected(role),
      );
      final activeSlot = selectedIndex == 2 ? 3 : selectedIndex;
      final keys = adaptive
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < (4 / columns).ceil(); row++)
                  SizedBox(
                    height: keyHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var col = 0; col < columns; col++)
                          Expanded(child: tile(order[row * columns + col])),
                      ],
                    ),
                  ),
              ],
            )
          : SizedBox(
              height: keyHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositionedDirectional(
                    duration: CreativeMotion.duration(
                      context,
                      CreativeMotion.branch,
                    ),
                    curve: CreativeMotion.curve,
                    start: slot * activeSlot + 3,
                    top: 3,
                    bottom: 3,
                    width: slot - 6,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: dark
                                ? const [Color(0xff383e3e), Color(0xff171b1c)]
                                : const [Color(0xffd6d9d5), Color(0xffeeeee7)],
                          ),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final role in order) Expanded(child: tile(role)),
                    ],
                  ),
                ],
              ),
            );
      return ImmersiveSurface(
        radius: 28,
        padding: const EdgeInsets.all(5),
        child: keys,
      );
    },
  );
}

class _DockKey extends StatefulWidget {
  const _DockKey({
    super.key,
    required this.label,
    required this.glyph,
    required this.onTap,
    required this.style,
    required this.selected,
    required this.create,
    required this.horizontal,
    required this.raised,
    this.rail = false,
    this.semanticLabel,
  });
  final String label;
  final DoodimoGlyph glyph;
  final VoidCallback onTap;
  final TextStyle style;
  final bool selected, create, horizontal, raised, rail;
  final String? semanticLabel;
  @override
  State<_DockKey> createState() => _DockKeyState();
}

class _DockKeyState extends State<_DockKey> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = widget.rail
        ? 24.0
        : widget.horizontal
        ? 42.0
        : 42.0;
    final icon = Container(
      width: iconSize,
      height: iconSize,
      decoration: widget.create
          ? null
          : BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceContainerHigh,
                  colors.surfaceContainerLow,
                ],
              ),
              border: Border.all(
                color: widget.selected ? colors.primary : colors.outline,
                width: widget.selected ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .3 : .09),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
      child: Center(
        child: DoodimoIcon(
          widget.glyph,
          size: widget.rail
              ? 20
              : widget.create
              ? 30
              : 24,
          color: widget.create
              ? DoodimoColors.ink
              : widget.selected
              ? colors.primary
              : colors.onSurface,
        ),
      ),
    );
    final title = Text(
      widget.label,
      textAlign: widget.horizontal ? TextAlign.start : TextAlign.center,
      style: widget.style.copyWith(
        color: widget.create
            ? DoodimoColors.ink
            : widget.selected
            ? colors.onSurface
            : colors.onSurfaceVariant,
      ),
    );
    Widget content = widget.horizontal
        ? Row(
            children: [
              icon,
              SizedBox(width: widget.rail ? 8 : 14),
              Expanded(child: title),
              if (widget.selected)
                DoodimoIcon(
                  DoodimoGlyph.check,
                  size: 18,
                  color: colors.secondary,
                ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 4),
              title,
              const SizedBox(height: 3),
              SizedBox(
                height: 2,
                width: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? colors.secondary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
    if (widget.create) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffffac6a), Color(0xffed7e37)],
          ),
          border: Border.all(color: const Color(0xffffc89c)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .3),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: content,
        ),
      );
    }
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel ?? widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedScale(
              scale: _pressed ? .96 : 1,
              duration: CreativeMotion.duration(context, CreativeMotion.press),
              curve: CreativeMotion.curve,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.rail
                      ? 6
                      : widget.horizontal
                      ? 12
                      : 4,
                  vertical: widget.rail
                      ? 3
                      : widget.horizontal
                      ? 6
                      : 3,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
