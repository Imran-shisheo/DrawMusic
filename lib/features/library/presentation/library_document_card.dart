import 'package:flutter/material.dart';

import '../../../design_system/immersive_surface.dart';

/// Artwork remains an untransformed 80×100 document window. The surrounding
/// gallery material owns depth; saved thumbnail pixels and aspect stay intact.
class LibraryDocumentCard extends StatelessWidget {
  const LibraryDocumentCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });
  final Widget leading, title, subtitle, trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final artwork = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.secondary.withValues(alpha: .22),
            colors.primary.withValues(alpha: .08),
          ],
        ),
        border: Border.all(color: colors.secondary.withValues(alpha: .3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: leading,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ImmersiveSurface(
        padding: EdgeInsets.zero,
        radius: 26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    MediaQuery.textScalerOf(context).scale(14) > 21 &&
                    constraints.maxWidth < 460;
                final metadata = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleMedium!
                          .copyWith(fontWeight: FontWeight.w700),
                      child: title,
                    ),
                    const SizedBox(height: 10),
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                      child: subtitle,
                    ),
                  ],
                );
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [artwork, const Spacer(), trailing],
                          ),
                          const SizedBox(height: 18),
                          metadata,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          artwork,
                          const SizedBox(width: 18),
                          Expanded(child: metadata),
                          const SizedBox(width: 4),
                          trailing,
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}
