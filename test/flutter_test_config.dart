import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Functional tests exercise the real system reduced-motion path by default.
/// Dedicated motion tests override this preference and use bounded pumps.
/// Production animation and application preferences are never disabled here.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  await testMain();
}
