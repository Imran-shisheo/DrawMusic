import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/motion.dart';
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
    Widget tab(bool exported, IconData icon, String label) {
      final selected = exported == exports;
      final contents = [
        Icon(icon, size: 22),
        const SizedBox(width: 8, height: 6),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ];
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: AnimatedContainer(
            duration: CreativeMotion.duration(
              context,
              CreativeMotion.selection,
            ),
            curve: CreativeMotion.curve,
            decoration: BoxDecoration(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: colors.outlineVariant)
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
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
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      child: stacked
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 22),
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
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tab(false, Icons.draw_outlined, context.strings.drafts),
          const SizedBox(width: 6),
          tab(true, Icons.file_copy_outlined, context.strings.exports),
        ],
      ),
    );
  }
}
