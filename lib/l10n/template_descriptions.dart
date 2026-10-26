import 'package:flutter/widgets.dart';

import 'strings.dart';

// Template descriptions are interface guidance; editable original titles stay data.
String localizedTemplateDescription(BuildContext context, int kind) {
  final s = context.strings;
  return switch (kind) {
    0 => s.templateDescription0,
    1 => s.templateDescription1,
    2 => s.templateDescription2,
    3 => s.templateDescription3,
    4 => s.templateDescription4,
    5 => s.templateDescription5,
    6 => s.templateDescription6,
    7 => s.templateDescription7,
    8 => s.templateDescription8,
    9 => s.templateDescription9,
    10 => s.templateDescription10,
    11 => s.templateDescription11,
    12 => s.templateDescription12,
    13 => s.templateDescription13,
    14 => s.templateDescription14,
    15 => s.templateDescription15,
    16 => s.templateDescription16,
    17 => s.templateDescription17,
    18 => s.templateDescription18,
    19 => s.templateDescription19,
    _ => s.tryAStartingPoint,
  };
}
