import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// Exact public URL published and supplied by the owner’s coordinator.
// Open only on user action in the external browser.
const String publishedPrivacyPolicyUrl =
    'https://possible-catmint-fdb.notion.site/Doodimo-Privacy-Policy-40c9ba8090a4815dab64ed8c4f37e9a6';

Uri? httpsPrivacyPolicyUri(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.host.toLowerCase() != 'app.notion.com' &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

final privacyPolicyUriProvider = Provider<Uri?>(
  (ref) => httpsPrivacyPolicyUri(publishedPrivacyPolicyUrl),
);

final privacyPolicyLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
