import '../../../design_system/immersive_surface.dart';

import 'package:flutter/material.dart';

import '../../../l10n/strings.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/creative_components.dart';
import '../../../design_system/doodimo_icon.dart';

/// Informational opt-in only: no star controls, sentiment filtering, store URL
/// or assertion that a review was/will be submitted. Back/outside means Not now.
Future<bool> showRatingOffer(BuildContext context) async {
  if (!context.mounted) return false;
  final previousFocus = FocusManager.instance.primaryFocus;
  try {
    return await showCreativePanel<bool>(
          context: context,
          builder: (context) => CreativePanel(
            title: context.strings.reviewOptionalTitle,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.strings.reviewNotNow),
              ),
              PrismAction(
                icon: const DoodimoIcon(DoodimoGlyph.arrowUpRight),
                onPressed: () => Navigator.pop(context, true),
                label: context.strings.reviewContinue,
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ImmersiveSurface(
                    accent: Theme.of(context).colorScheme.outlineVariant,
                    radius: 22,
                    child: Row(
                      children: [
                        const SketchMark(size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const DoodimoIcon(DoodimoGlyph.sound, size: 32),
                      ],
                    ),
                  ),
                ),
                Text(
                  context.strings.reviewOptionalBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ) ??
        false;
  } finally {
    if (previousFocus?.context?.mounted == true) previousFocus!.requestFocus();
  }
}
