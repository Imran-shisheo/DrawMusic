import 'package:flutter/material.dart';

import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/immersive_surface.dart';

/// Empty/recovery states describe actual local storage, without fabricated work.
class LibraryStatePanel extends StatelessWidget {
  const LibraryStatePanel({
    super.key,
    required this.glyph,
    required this.title,
    required this.message,
    this.action,
  });
  final DoodimoGlyph glyph;
  final String title, message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ImmersiveSurface(
    glow: true,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DoodimoIcon(
          glyph,
          size: 52,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 22),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        if (action != null) ...[const SizedBox(height: 22), action!],
      ],
    ),
  );
}
