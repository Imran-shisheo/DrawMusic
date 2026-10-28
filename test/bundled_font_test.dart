import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/typography.dart';

// Independent OpenType cmap inspection: actual bundled glyph indices, rather
// than assuming that a font-family label proves coverage. TTC uses face zero,
// the default face used by this bundled fallback asset.
class _FontFace {
  _FontFace(File file) : bytes = file.readAsBytesSync() {
    data = ByteData.sublistView(bytes);
    final offset =
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'ttcf'
        ? data.getUint32(12)
        : 0;
    final count = data.getUint16(offset + 4);
    var cmap = -1;
    for (var i = 0; i < count; i++) {
      final at = offset + 12 + i * 16;
      if (ascii.decode(bytes.sublist(at, at + 4), allowInvalid: true) ==
          'cmap') {
        cmap = data.getUint32(at + 8);
      }
    }
    if (cmap < 0) throw const FormatException('Font has no cmap');
    for (var i = 0; i < data.getUint16(cmap + 2); i++) {
      final at = cmap + 4 + i * 8;
      final platform = data.getUint16(at), encoding = data.getUint16(at + 2);
      if (platform == 0 || platform == 3 && (encoding == 1 || encoding == 10)) {
        tables.add(cmap + data.getUint32(at + 4));
      }
    }
  }
  final Uint8List bytes;
  late final ByteData data;
  final tables = <int>[];

  bool covers(int cp) {
    for (final start in tables) {
      final format = data.getUint16(start);
      if (format == 12) {
        final count = data.getUint32(start + 12);
        var low = 0, high = count - 1;
        while (low <= high) {
          final mid = (low + high) ~/ 2, at = start + 16 + mid * 12;
          final first = data.getUint32(at), last = data.getUint32(at + 4);
          if (cp < first) {
            high = mid - 1;
          } else if (cp > last) {
            low = mid + 1;
          } else {
            return data.getUint32(at + 8) + cp - first != 0;
          }
        }
      } else if (format == 4 && cp <= 0xffff) {
        final segments = data.getUint16(start + 6) ~/ 2;
        final ends = start + 14, starts = ends + segments * 2 + 2;
        final deltas = starts + segments * 2, ranges = deltas + segments * 2;
        for (var i = 0; i < segments; i++) {
          if (cp > data.getUint16(ends + i * 2)) continue;
          final first = data.getUint16(starts + i * 2);
          if (cp < first) break;
          final delta = data.getInt16(deltas + i * 2);
          final range = data.getUint16(ranges + i * 2);
          if (range == 0) {
            if ((cp + delta) & 0xffff != 0) return true;
          } else {
            final glyph = data.getUint16(
              ranges + i * 2 + range + (cp - first) * 2,
            );
            if (glyph != 0 && (glyph + delta) & 0xffff != 0) return true;
          }
          break;
        }
      }
    }
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offline font stack covers every shipped UI character and Arabic RTL fixture', () {
    final fonts = [
      for (final (family, file) in [
        ('NunitoSans', 'NunitoSans-Regular.ttf'),
        ('SpaceGrotesk', 'SpaceGrotesk-SemiBold.ttf'),
        ('NotoSansDevanagari', 'NotoSansDevanagari-Regular.ttf'),
        ('NotoSansThai', 'NotoSansThai-Regular.ttf'),
        ('NotoSansArabic', 'NotoSansArabic-Regular.ttf'),
        ('NotoSansCJK', 'NotoSansCJK-Regular.ttc'),
      ])
        _FontFace(File('assets/fonts/$family/$file')),
    ];
    final requested = <int>{...'موسيقى هادئة — العربية'.runes};
    for (final file in Directory(
      'lib/l10n',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
      final messages =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in messages.entries) {
        if (!entry.key.startsWith('@') && entry.value is String) {
          requested.addAll((entry.value as String).runes);
        }
      }
    }
    final missing = [
      for (final cp in requested)
        if (cp >= 32 &&
            cp != 0x200c &&
            cp != 0x200d &&
            !fonts.any((font) => font.covers(cp)))
          'U+${cp.toRadixString(16).toUpperCase()} ${String.fromCharCode(cp)}',
    ];
    expect(
      missing,
      isEmpty,
      reason: 'A font name is not proof of actual script glyph coverage.',
    );
    expect(AppTypography.fontFamily, 'NunitoSans');
    expect(AppTypography.displayFamily, 'SpaceGrotesk');
    expect(AppTypography.displayFallbacks.first, AppTypography.fontFamily);
    expect(
      AppTypography.fallbacks,
      containsAll([
        'NotoSansDevanagari',
        'NotoSansThai',
        'NotoSansArabic',
        'NotoSansCJK',
      ]),
    );
  });

  test('font licenses ship with the app and register once for the native license page', () async {
    AppTypography.registerLicenses();
    AppTypography.registerLicenses();
    final licenses = await LicenseRegistry.licenses.toList();
    for (final family in [
      'Nunito Sans',
      'Space Grotesk',
      'Noto Sans Devanagari',
      'Noto Sans Thai',
      'Noto Sans Arabic',
      'Noto Sans CJK',
    ]) {
      final entries = licenses
          .where((entry) => entry.packages.contains(family))
          .toList();
      expect(entries, hasLength(1), reason: family);
      expect(
        entries.single.paragraphs.map((p) => p.text).join('\n'),
        contains('SIL OPEN FONT LICENSE'),
      );
    }
  });
  test('bundled font bytes match the reviewed license/source manifest', () {
    final manifest =
        jsonDecode(File('docs/FONT-MANIFEST.json').readAsStringSync()) as Map;
    var total = 0;
    for (final entry in manifest['files'] as List) {
      final bytes = File(entry['path'] as String).readAsBytesSync();
      expect(bytes.length, entry['bytes'], reason: entry['path'] as String);
      expect(
        sha256.convert(bytes).toString(),
        entry['sha256'],
        reason: entry['path'] as String,
      );
      total += bytes.length;
    }
    expect(total, manifest['totalBundledBytes']);
  });
}
