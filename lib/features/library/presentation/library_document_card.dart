import 'package:flutter/material.dart';

/// A document preview is artwork, not a ListTile icon. Keep its portrait size
/// outside ListTile's 56 dp leading cap, and let large translated text stack.
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                MediaQuery.textScalerOf(context).scale(14) > 21 &&
                constraints.maxWidth < 460;
            final metadata = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleMedium!,
                  child: title,
                ),
                const SizedBox(height: 8),
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        children: [leading, const Spacer(), trailing],
                      ),
                      const SizedBox(height: 16),
                      metadata,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      const SizedBox(width: 20),
                      Expanded(child: metadata),
                      const SizedBox(width: 4),
                      trailing,
                    ],
                  );
          },
        ),
      ),
    ),
  );
}
