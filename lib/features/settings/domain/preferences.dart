class UserPreferences {
  const UserPreferences({
    this.previewVolume = 1,
    this.haptics = false,
    this.reduceMotion = false,
    this.tutorialCompleted = false,
    this.editorTipsCompleted = false,
  });
  final double previewVolume;
  final bool haptics, reduceMotion, tutorialCompleted, editorTipsCompleted;
  UserPreferences copyWith({
    double? previewVolume,
    bool? haptics,
    bool? reduceMotion,
    bool? tutorialCompleted,
    bool? editorTipsCompleted,
  }) => UserPreferences(
    previewVolume: previewVolume ?? this.previewVolume,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    editorTipsCompleted: editorTipsCompleted ?? this.editorTipsCompleted,
  );
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'previewVolume': previewVolume,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
    'tutorialCompleted': tutorialCompleted,
    'editorTipsCompleted': editorTipsCompleted,
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
      haptics: json['haptics'] as bool,
      reduceMotion: json['reduceMotion'] as bool,
      tutorialCompleted: json['tutorialCompleted'] as bool,
      editorTipsCompleted: json['editorTipsCompleted'] as bool? ?? false,
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
