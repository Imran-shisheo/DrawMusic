import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/motion.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../l10n/strings.dart';

/// In-flow library navigation grows with translated text rather than being
/// clipped inside a fixed-height AppBar bottom.
class LibraryTabs extends StatelessWidget implements PreferredSizeWidget {
  const LibraryTabs({super.key, required this.exports});
  final bool exports;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final short = MediaQuery.sizeOf(context).height < 480;
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 21 && !short;
    Widget tab(bool exported, DoodimoGlyph icon, String label) {
      final selected = exported == exports;
      final contents = [
        DoodimoIcon(
          icon,
          size: 24,
          color: selected ? colors.onPrimary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8, height: 6),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ];
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.go(exported ? '/exports' : '/drafts'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: short ? 6 : 12,
                  ),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: selected
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    child: stacked
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DoodimoIcon(
                                icon,
                                size: 24,
                                color: selected
                                    ? colors.onPrimary
                                    : colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              Text(label, textAlign: TextAlign.center),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: contents,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ImmersiveSurface(
      padding: const EdgeInsets.all(5),
      radius: 24,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, bounds) => AnimatedAlign(
                duration: CreativeMotion.duration(
                  context,
                  CreativeMotion.selection,
                ),
                curve: CreativeMotion.curve,
                alignment: exports
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: (bounds.maxWidth - 6) / 2,
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
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tab(false, DoodimoGlyph.draw, context.strings.drafts),
              const SizedBox(width: 6),
              tab(true, DoodimoGlyph.export, context.strings.exports),
            ],
          ),
        ],
      ),
    );
  }
}
