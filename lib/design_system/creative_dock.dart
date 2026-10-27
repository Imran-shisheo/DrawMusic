import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_colors.dart';
import 'doodimo_icon.dart';
import 'motion.dart';

/// A compact four-key studio dock. It does not own or recreate branch content.
class CreativeDock extends StatelessWidget {
  const CreativeDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCreate,
    required this.labels,
    required this.createLabel,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreate;
  final List<String> labels;
  final String createLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final large =
          MediaQuery.textScalerOf(context).scale(12) > 18 &&
          constraints.maxWidth < 520;
      final cellWidth = (constraints.maxWidth - 20) / 2;
      final slotWidth = (constraints.maxWidth - 18) / 4;
      final style = Theme.of(context).textTheme.labelMedium!
          .copyWith(fontWeight: FontWeight.w700, height: 1.15);
      var height = 76.0;
      for (final label in [...labels, createLabel]) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, (large ? cellWidth : slotWidth) - 8));
        height = math.max(height, 56 + painter.height);
        painter.dispose();
      }
      var longestWord = 0.0;
      for (final label in [...labels, createLabel]) {
        for (final word in label.split(RegExp(r'\s+'))) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          longestWord = math.max(longestWord, painter.width);
          painter.dispose();
        }
      }
      if (large && longestWord > cellWidth - 8) {
        var rowHeight = 48.0;
        for (final label in [...labels, createLabel]) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: math.max(1, constraints.maxWidth - 72));
          rowHeight = math.max(rowHeight, painter.height + 16);
          painter.dispose();
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: DoodimoColors.ink,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    height: rowHeight,
                    child: _DockKey(
                      key: ValueKey(
                        [
                          'nav-home',
                          'nav-library',
                          'nav-settings',
                          'root-new-drawing',
                        ][i],
                      ),
                      label: i == 3 ? createLabel : labels[i],
                      glyph: [
                        DoodimoGlyph.home,
                        DoodimoGlyph.library,
                        DoodimoGlyph.settings,
                        DoodimoGlyph.add,
                      ][i],
                      selected: selectedIndex == i,
                      create: i == 3,
                      horizontal: true,
                      onTap: i == 3 ? onCreate : () => onDestinationSelected(i),
                      style: style,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      if (large) {
        final rowHeight = height;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: DoodimoColors.ink,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < 2; row++)
                  SizedBox(
                    height: rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < 2; column++)
                          Expanded(
                            child: _DockKey(
                              key: ValueKey(
                                [
                                  'nav-home',
                                  'nav-library',
                                  'nav-settings',
                                  'root-new-drawing',
                                ][row * 2 + column],
                              ),
                              label: row * 2 + column == 3
                                  ? createLabel
                                  : labels[row * 2 + column],
                              glyph: [
                                DoodimoGlyph.home,
                                DoodimoGlyph.library,
                                DoodimoGlyph.settings,
                                DoodimoGlyph.add,
                              ][row * 2 + column],
                              selected: selectedIndex == row * 2 + column,
                              create: row * 2 + column == 3,
                              onTap: row * 2 + column == 3
                                  ? onCreate
                                  : () =>
                                        onDestinationSelected(row * 2 + column),
                              style: style,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: DoodimoColors.ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              children: [
                AnimatedPositionedDirectional(
                  duration: CreativeMotion.duration(
                    context,
                    CreativeMotion.branch,
                  ),
                  curve: CreativeMotion.curve,
                  start: slotWidth * selectedIndex + (slotWidth - 20) / 2,
                  bottom: 0,
                  width: 20,
                  height: 3,
                  child: const ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DoodimoColors.lime,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: _DockKey(
                          key: ValueKey(
                            ['nav-home', 'nav-library', 'nav-settings'][i],
                          ),
                          label: labels[i],
                          glyph: [
                            DoodimoGlyph.home,
                            DoodimoGlyph.library,
                            DoodimoGlyph.settings,
                          ][i],
                          selected: selectedIndex == i,
                          onTap: () => onDestinationSelected(i),
                          style: style,
                        ),
                      ),
                    Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: DoodimoColors.paper.withValues(alpha: .24),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _DockKey(
                        key: const ValueKey('root-new-drawing'),
                        label: createLabel,
                        glyph: DoodimoGlyph.add,
                        create: true,
                        onTap: onCreate,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DockKey extends StatelessWidget {
  const _DockKey({
    super.key,
    required this.label,
    required this.glyph,
    required this.onTap,
    required this.style,
    this.selected = false,
    this.create = false,
    this.horizontal = false,
  });
  final String label;
  final DoodimoGlyph glyph;
  final VoidCallback onTap;
  final TextStyle style;
  final bool selected, create, horizontal;

  @override
  Widget build(BuildContext context) {
    final symbol = DecoratedBox(
      decoration: BoxDecoration(
        color: create ? DoodimoColors.lime : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(create ? 3 : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DoodimoIcon(
              glyph,
              size: create ? 20 : 24,
              color: create
                  ? DoodimoColors.ink
                  : selected
                  ? DoodimoColors.lime
                  : DoodimoColors.paper,
            ),
            if (selected)
              const PositionedDirectional(
                end: -4,
                top: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: DoodimoColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 4),
                ),
              ),
          ],
        ),
      ),
    );
    final title = Text(
      label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: style.copyWith(
        color: selected ? DoodimoColors.lime : DoodimoColors.paper,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: DoodimoColors.lime.withValues(alpha: .2),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal ? 12 : 4,
                vertical: 6,
              ),
              child: horizontal
                  ? Row(
                      children: [
                        symbol,
                        const SizedBox(width: 12),
                        Expanded(child: title),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [symbol, const SizedBox(height: 4), title],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
