import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/motion.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../l10n/strings.dart';

/// Retained in-flow navigation measures both labels before choosing its axis.
/// A whole translated word never gets split merely to retain two columns.
class LibraryTabs extends StatelessWidget implements PreferredSizeWidget {
  const LibraryTabs({super.key, required this.exports});
  final bool exports;
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final short = MediaQuery.sizeOf(context).height < 480;
    final stacked = scaler.scale(14) > 21 && !short;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(fontWeight: FontWeight.w700);
    final labels = [context.strings.drafts, context.strings.exports];
    double measure(String label, {double maxWidth = double.infinity}) {
      final text = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: maxWidth);
      final value = maxWidth.isInfinite ? text.width : text.height;
      text.dispose();
      return value;
    }

    final widestWord = labels
        .expand((label) => label.split(RegExp(r'\s+')))
        .map(measure)
        .reduce(math.max);
    final verticalPadding = short ? 6.0 : 12.0;
    return ImmersiveSurface(
      padding: const EdgeInsets.all(5),
      radius: 24,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final columnWidth = (bounds.maxWidth - 6) / 2;
          final columnTextWidth = columnWidth - 24 - (stacked ? 0 : 32);
          final fullRows = widestWord > columnTextWidth;
          final iconAbove = stacked && !fullRows;
          final textWidth = math.max(
            1.0,
            (fullRows ? bounds.maxWidth : columnWidth) -
                24 -
                (iconAbove ? 0 : 32),
          );
          final labelHeight = labels
              .map((label) => measure(label, maxWidth: textWidth))
              .reduce(math.max);
          final contentHeight = iconAbove
              ? labelHeight + 30
              : math.max(24.0, labelHeight);
          final rowHeight = math.max(52.0, contentHeight + verticalPadding * 2);

          Widget tab(bool exported, DoodimoGlyph glyph, String label) {
            final selected = exported == exports;
            final color = selected ? colors.onPrimary : colors.onSurfaceVariant;
            final icon = DoodimoIcon(glyph, size: 24, color: color);
            final text = Text(label, textAlign: TextAlign.center);
            return Semantics(
              selected: selected,
              button: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.go(exported ? '/exports' : '/drafts'),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rowHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: verticalPadding,
                      ),
                      child: DefaultTextStyle(
                        style: style.copyWith(color: color),
                        child: iconAbove
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  icon,
                                  const SizedBox(height: 6),
                                  text,
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  icon,
                                  const SizedBox(width: 8),
                                  Flexible(child: text),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final tabs = [
            tab(false, DoodimoGlyph.draw, labels[0]),
            tab(true, DoodimoGlyph.export, labels[1]),
          ];
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: CreativeMotion.duration(
                    context,
                    CreativeMotion.selection,
                  ),
                  curve: CreativeMotion.curve,
                  alignment: fullRows
                      ? (exports ? Alignment.bottomCenter : Alignment.topCenter)
                      : (exports
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart),
                  child: Container(
                    width: fullRows ? bounds.maxWidth : columnWidth,
                    height: rowHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(colors.primary, Colors.white, .12)!,
                          colors.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Color.lerp(colors.primary, Colors.white, .3)!,
                      ),
                    ),
                  ),
                ),
              ),
              if (fullRows)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [tabs[0], const SizedBox(height: 6), tabs[1]],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tabs[0]),
                    const SizedBox(width: 6),
                    Expanded(child: tabs[1]),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
