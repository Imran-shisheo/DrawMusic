import 'package:flutter/material.dart';

import '../../../l10n/strings.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/creative_components.dart';
import '../../../design_system/brand_colors.dart';
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
              FilledButton.icon(
                icon: const DoodimoIcon(DoodimoGlyph.arrowUpRight),
                onPressed: () => Navigator.pop(context, true),
                label: Text(context.strings.reviewContinue),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: DoodimoColors.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SketchMark(size: 72),
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
