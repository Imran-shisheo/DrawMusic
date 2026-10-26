/// Original, portable background contract. Coordinates refer to the normalized
/// source image before quarter-turn rotation. Backgrounds never enter the score.
enum BackgroundKind { solid, linear, radial, photo }

class CropWindow {
  const CropWindow({
    this.left = 0,
    this.top = 0,
    this.width = 1,
    this.height = 1,
  });
  final double left, top, width, height;
  bool get valid =>
      [left, top, width, height].every((n) => n.isFinite) &&
      left >= 0 &&
      top >= 0 &&
      width >= .05 &&
      height >= .05 &&
      left + width <= 1.000001 &&
      top + height <= 1.000001;
  List<double> toJson() => [left, top, width, height];
  factory CropWindow.fromJson(List<dynamic> j) {
    if (j.length != 4) throw const FormatException('Invalid image crop');
    final crop = CropWindow(
      left: (j[0] as num).toDouble(),
      top: (j[1] as num).toDouble(),
      width: (j[2] as num).toDouble(),
      height: (j[3] as num).toDouble(),
    );
    if (!crop.valid) throw const FormatException('Invalid image crop');
    return crop;
  }
}

class BackgroundDefinition {
  BackgroundDefinition({
    required this.kind,
    Iterable<int> colors = const [0xfff7f5eb],
    this.opacity = 1,
    this.assetId,
    this.crop = const CropWindow(),
    this.quarterTurns = 0,
    this.mirror = false,
    this.unknownKind,
  }) : colors = List.unmodifiable(colors) {
    if (this.colors.isEmpty ||
        this.colors.length > 4 ||
        this.colors.any((c) => c < 0 || c > 0xffffffff) ||
        !opacity.isFinite ||
        opacity < 0 ||
        opacity > 1 ||
        !crop.valid ||
        quarterTurns < 0 ||
        quarterTurns > 3 ||
        (assetId != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(assetId!)) ||
        (kind == BackgroundKind.photo && assetId == null)) {
      throw const FormatException('Invalid background');
    }
  }
  factory BackgroundDefinition.solid(int argb) => BackgroundDefinition(
    kind: BackgroundKind.solid,
    colors: [0xff000000 | (argb & 0xffffff)],
    opacity: ((argb >>> 24) & 255) / 255,
  );
  final BackgroundKind kind;
  final List<int> colors;
  final double opacity;
  final String? assetId, unknownKind;
  final CropWindow crop;
  final int quarterTurns;
  final bool mirror;
  BackgroundDefinition copyWith({
    BackgroundKind? kind,
    List<int>? colors,
    double? opacity,
    String? assetId,
    CropWindow? crop,
    int? quarterTurns,
    bool? mirror,
  }) => BackgroundDefinition(
    kind: kind ?? this.kind,
    colors: colors ?? this.colors,
    opacity: opacity ?? this.opacity,
    assetId: assetId ?? this.assetId,
    crop: crop ?? this.crop,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    mirror: mirror ?? this.mirror,
    unknownKind: kind == null ? unknownKind : null,
  );
  Map<String, dynamic> toJson() => {
    'kind': unknownKind ?? kind.name,
    'colors': colors,
    'opacity': opacity,
    if (assetId != null) 'assetId': assetId,
    'crop': crop.toJson(),
    'quarterTurns': quarterTurns,
    'mirror': mirror,
  };
  factory BackgroundDefinition.fromJson(Map<String, dynamic> j) {
    final id = j['kind'] as String;
    final kind = BackgroundKind.values.where((v) => v.name == id).firstOrNull;
    return BackgroundDefinition(
      kind: kind ?? BackgroundKind.solid,
      colors: (j['colors'] as List).cast<int>(),
      opacity: (j['opacity'] as num).toDouble(),
      assetId: j['assetId'] as String?,
      crop: j['crop'] == null
          ? const CropWindow()
          : CropWindow.fromJson(j['crop'] as List),
      quarterTurns: j['quarterTurns'] as int? ?? 0,
      mirror: j['mirror'] as bool? ?? false,
      unknownKind: kind == null ? id : null,
    );
  }
}
