class UserPreferences {
  const UserPreferences({
    this.previewVolume = 1,
    this.haptics = false,
    this.reduceMotion = false,
    this.tutorialCompleted = false,
    this.editorTipsCompleted = false,
    this.languageCode = 'en',
    this.darkTheme = false,
  });
  final bool darkTheme;
  final double previewVolume;
  final String languageCode;
  final bool haptics, reduceMotion, tutorialCompleted, editorTipsCompleted;
  UserPreferences copyWith({
    double? previewVolume,
    bool? haptics,
    bool? reduceMotion,
    bool? tutorialCompleted,
    bool? editorTipsCompleted,
    String? languageCode,
    bool? darkTheme,
  }) => UserPreferences(
    previewVolume: previewVolume ?? this.previewVolume,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    editorTipsCompleted: editorTipsCompleted ?? this.editorTipsCompleted,
    languageCode: languageCode ?? this.languageCode,
    darkTheme: darkTheme ?? this.darkTheme,
  );
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'previewVolume': previewVolume,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
    'tutorialCompleted': tutorialCompleted,
    'editorTipsCompleted': editorTipsCompleted,
    'languageCode': languageCode,
    'darkTheme': darkTheme,
  };
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported settings');
    }
    final volume = (json['previewVolume'] as num).toDouble();
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw const FormatException('Invalid preview volume');
    }
    return UserPreferences(
      previewVolume: volume,
      darkTheme: json['darkTheme'] as bool? ?? false,
      haptics: json['haptics'] as bool,
      reduceMotion: json['reduceMotion'] as bool,
      tutorialCompleted: json['tutorialCompleted'] as bool,
      editorTipsCompleted: json['editorTipsCompleted'] as bool? ?? false,
      // Only shipped translations are selectable; future/unsupported values
      // fall back without discarding unrelated settings.
      languageCode:
          const [
            'en',
            'fr',
            'es',
            'it',
            'ko',
            'ja',
            'vi',
            'hi',
            'pt',
            'th',
            'fil',
            'id',
          ].contains(json['languageCode'])
          ? json['languageCode'] as String
          : 'en',
    );
  }
}

class PreferencesLoad {
  const PreferencesLoad(this.preferences, {this.recovered = false});
  final UserPreferences preferences;
  final bool recovered;
}

abstract interface class PreferencesStore {
  Future<PreferencesLoad> load();
  Future<void> save(UserPreferences preferences);
}
