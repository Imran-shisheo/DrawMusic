// Original eight-beat pattern configuration; levels are part of the document,
// independent of the device's preview-volume preference.
enum AccompanimentLayer { bass, drumKit, arpeggio, kick, snare, clap, hiHat }

class LayerMix {
  const LayerMix({this.enabled = false, this.level = .5, this.muted = false});
  final bool enabled, muted;
  final double level;
  bool get audible => enabled && !muted && level > 0;
  LayerMix copyWith({bool? enabled, bool? muted, double? level}) => LayerMix(
    enabled: enabled ?? this.enabled,
    muted: muted ?? this.muted,
    level: level ?? this.level,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'muted': muted,
    'level': level,
  };
  factory LayerMix.fromJson(Map<String, dynamic> j) {
    final level = (j['level'] as num).toDouble();
    if (!level.isFinite || level < 0 || level > 1) {
      throw const FormatException('Invalid accompaniment level');
    }
    return LayerMix(
      enabled: j['enabled'] as bool,
      muted: j['muted'] as bool,
      level: level,
    );
  }
}

class AccompanimentMix {
  const AccompanimentMix() : layers = const {};
  AccompanimentMix._(Map<AccompanimentLayer, LayerMix> values)
    : layers = Map.unmodifiable(values);
  final Map<AccompanimentLayer, LayerMix> layers;
  LayerMix operator [](AccompanimentLayer layer) =>
      layers[layer] ?? const LayerMix();
  bool get isActive => AccompanimentLayer.values.any((l) => this[l].audible);
  bool get isConfigured => layers.isNotEmpty;
  AccompanimentMix withLayer(AccompanimentLayer layer, LayerMix mix) =>
      AccompanimentMix._({...layers, layer: mix});
  Map<String, dynamic> toJson() => {
    for (final l in AccompanimentLayer.values)
      if (layers.containsKey(l)) l.name: this[l].toJson(),
  };
  factory AccompanimentMix.fromJson(Map<String, dynamic> j) =>
      AccompanimentMix._(
        Map.unmodifiable({
          for (final l in AccompanimentLayer.values)
            if (j[l.name] != null)
              l: LayerMix.fromJson(j[l.name] as Map<String, dynamic>),
        }),
      );
}
