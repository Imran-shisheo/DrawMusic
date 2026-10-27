import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'design_system/typography.dart';
import 'features/backgrounds/data/background_cleanup.dart';
import 'features/backgrounds/data/background_cleanup_coordination.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppTypography.registerLicenses();
  // No providers/editor/history/picker exist until this bounded startup gate
  // finishes or conservatively retains uncertain files.
  await cleanupBackgroundsBeforeApplication();
  BackgroundStorageCoordinator.application.applicationStarted();
  runApp(const ProviderScope(child: ScribbleSongApp(showWelcome: true)));
}
