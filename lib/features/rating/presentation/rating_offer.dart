import 'package:flutter/material.dart';

import '../../../l10n/strings.dart';

/// Informational opt-in only: no star controls, sentiment filtering, store URL
/// or assertion that a review was/will be submitted. Back/outside means Not now.
Future<bool> showRatingOffer(BuildContext context) async {
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(context.strings.reviewOptionalTitle),
          content: Text(context.strings.reviewOptionalBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings.reviewNotNow),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.strings.reviewContinue),
            ),
          ],
        ),
      ) ??
      false;
}
