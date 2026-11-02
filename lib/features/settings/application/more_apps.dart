import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'external_link.dart';

// Public storefront independently verified by the owner's coordinator.
const androidDeveloperStorefrontUrl =
    'https://play.google.com/store/apps/developer?id=DevWithDelta';
// Verified region-neutral Apple URL; the storefront may localize its redirect.
const iosDeveloperStorefrontUrl =
    'https://apps.apple.com/developer/imran-khan/id6773044710';

Uri? developerStorefrontUri(
  TargetPlatform platform, {
  String? androidUrl = androidDeveloperStorefrontUrl,
  String? iosUrl = iosDeveloperStorefrontUrl,
}) {
  final url = switch (platform) {
    TargetPlatform.android => androidUrl,
    TargetPlatform.iOS => iosUrl,
    _ => null,
  };
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment) {
    return null;
  }
  return switch (platform) {
    TargetPlatform.android
        when uri.host == 'play.google.com' &&
            uri.path == '/store/apps/developer' &&
            uri.queryParameters.length == 1 &&
            (uri.queryParameters['id']?.isNotEmpty ?? false) =>
      uri,
    TargetPlatform.iOS
        when uri.host == 'apps.apple.com' &&
            RegExp(r'^/(?:[a-z]{2}/)?developer/[^/]+/id[0-9]+$')
                .hasMatch(uri.path) &&
            !uri.hasQuery =>
      uri,
    _ => null,
  };
}

final moreAppsUriProvider = Provider<Uri?>(
  (ref) => kIsWeb ? null : developerStorefrontUri(defaultTargetPlatform),
);

final moreAppsLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => ref.watch(externalLinkLauncherProvider),
);
