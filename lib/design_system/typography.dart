import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled offline typography. Script fallback fonts carry their original SIL
/// Open Font Licenses under assets/fonts; no runtime font downloads occur.
abstract final class AppTypography {
  static const fontFamily = 'NunitoSans';
  static const displayFamily = 'SpaceGrotesk';
  static const displayFallbacks = <String>[fontFamily, ...fallbacks];
  static const fallbacks = <String>[
    'NotoSansDevanagari',
    'NotoSansThai',
    'NotoSansArabic',
    'NotoSansCJK',
  ];

  static bool _licensesRegistered = false;
  static void registerLicenses() {
    if (_licensesRegistered) return;
    _licensesRegistered = true;
    for (final (name, folder) in [
      ('Nunito Sans', 'NunitoSans'),
      ('Space Grotesk', 'SpaceGrotesk'),
      ('Noto Sans Devanagari', 'NotoSansDevanagari'),
      ('Noto Sans Thai', 'NotoSansThai'),
      ('Noto Sans Arabic', 'NotoSansArabic'),
      ('Noto Sans CJK', 'NotoSansCJK'),
    ]) {
      LicenseRegistry.addLicense(() async* {
        yield LicenseEntryWithLineBreaks([
          name,
        ], await rootBundle.loadString('assets/fonts/$folder/OFL.txt'));
      });
    }
  }
}
