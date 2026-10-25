import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/l10n/generated/app_localizations_en.dart';
import 'package:scribblesong/l10n/operation_messages.dart';

void main() {
  final strings = AppLocalizationsEn();
  test(
    'playback maps complexity to an actionable repair for start and updates',
    () {
      for (final updating in [false, true]) {
        expect(
          playbackFailureMessage(
            strings,
            ScoreComplexityException(),
            updating: updating,
          ),
          strings.scoreTooComplex,
        );
      }
    },
  );
  test('OS diagnostics never become playback presentation text', () {
    for (final error in <Object>[
      PlatformException(
        code: 'audio_unavailable',
        message: '/private/drawing.wav',
      ),
      StateError('private-codec-diagnostics'),
      MissingPluginException('platform path'),
    ]) {
      expect(
        playbackFailureMessage(strings, error),
        strings.playbackUnavailable,
      );
      expect(
        playbackFailureMessage(strings, error, updating: true),
        strings.playbackUpdateFailed,
      );
    }
    expect(
      settingsFailureMessage(strings, SettingsFailure.load),
      strings.preferencesLoadFailed,
    );
    expect(
      settingsFailureMessage(strings, SettingsFailure.save),
      strings.preferencesSaveFailed,
    );
  });
}
