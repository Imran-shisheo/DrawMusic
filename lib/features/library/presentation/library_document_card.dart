import 'package:flutter/material.dart';

/// An artwork-led catalog row on the persistent studio surface. The document
/// window never transforms; only the surrounding neutral frame owns depth.
class LibraryDocumentCard extends StatelessWidget {
  const LibraryDocumentCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.primaryAction,
    this.onTap,
  });
  final Widget leading, title, subtitle, trailing;
  final Widget? primaryAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final artwork = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.surfaceContainerHighest,
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: leading,
        ),
      ),
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [?primaryAction, trailing],
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 160),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  MediaQuery.textScalerOf(context).scale(14) > 21 &&
                  constraints.maxWidth < 460;
              final metadata = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.w700),
                    child: title,
                  ),
                  const SizedBox(height: 8),
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall!
                        .copyWith(color: colors.onSurfaceVariant, height: 1.45),
                    child: subtitle,
                  ),
                ],
              );
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        metadata,
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            artwork,
                            const SizedBox(width: 20),
                            Expanded(child: actions),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        artwork,
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              metadata,
                              const SizedBox(height: 16),
                              actions,
                            ],
                          ),
                        ),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}
