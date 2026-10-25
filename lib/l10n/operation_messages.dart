import '../features/composition/domain/score.dart';
import '../features/settings/application/settings_controller.dart';
import 'generated/app_localizations.dart';

String settingsFailureMessage(
  AppLocalizations strings,
  SettingsFailure failure,
) => switch (failure) {
  SettingsFailure.load => strings.preferencesLoadFailed,
  SettingsFailure.save => strings.preferencesSaveFailed,
};

// Native/OS diagnostics are not presentation text. Keep messages useful and
// translatable without exposing paths, codec details or arbitrary exceptions.
String playbackFailureMessage(
  AppLocalizations strings,
  Object error, {
  bool updating = false,
}) => error is ScoreComplexityException
    ? strings.scoreTooComplex
    : updating
    ? strings.playbackUpdateFailed
    : strings.playbackUnavailable;
