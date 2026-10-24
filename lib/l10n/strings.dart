import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';
export 'generated/app_localizations.dart';

extension LocalizedContext on BuildContext {
  // Reusable controls can also render in a minimal host without app delegates.
  AppLocalizations get strings =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
  String formatNumber(num value) =>
      NumberFormat.decimalPattern(strings.localeName).format(value);
  String formatDecimal(num value) => NumberFormat.decimalPatternDigits(
    locale: strings.localeName,
    decimalDigits: 2,
  ).format(value);
  String formatLocalDate(DateTime utc) =>
      DateFormat.yMMMd(strings.localeName).add_Hm().format(utc.toLocal());
}
