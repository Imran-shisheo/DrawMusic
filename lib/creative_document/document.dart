import 'dart:convert';
import 'dart:math' as math;

import 'music_catalog.dart';
import 'accompaniment.dart';
export 'accompaniment.dart';
import '../features/backgrounds/domain/background.dart';
export 'music_catalog.dart';

enum DrawingStyle { smooth, pixel }

/// Geometry-only playback is the default; expressive velocity is explicit and
/// versioned. Input metadata alone never changes a legacy project's sound.
enum ExpressionMode { geometry, expressive }

/// Stable append-only numeric codes in the optional point metadata extension.
enum InputKind { touch, mouse, stylus, invertedStylus, unknown }

class InkPoint {
  InkPoint(double u, double v, [int ms = 0]) : this.input(u, v, ms: ms);
  InkPoint.input(
    double u,
    double v, {
    this.ms = 0,
    this.pressure,
    this.tilt,
    this.kind = InputKind.touch,
    int? sourceKindCode,
  }) : u = _coordinate(u),
       v = _coordinate(v),
       _sourceKindCode = sourceKindCode {
    if ((pressure != null &&
            (!pressure!.isFinite || pressure! < 0 || pressure! > 1)) ||
        (tilt != null &&
            (!tilt!.isFinite || tilt! < 0 || tilt! > math.pi / 2)) ||
        (sourceKindCode != null &&
            (sourceKindCode < 0 || sourceKindCode > 255))) {
      throw const FormatException('Invalid drawing input metadata');
    }
  }
  final double u, v;
  final int ms;
  final double? pressure, tilt;
  final InputKind kind;
  final int? _sourceKindCode;
  int get kindCode => _sourceKindCode ?? kind.index;
  bool get hasInputMetadata =>
      pressure != null || tilt != null || kindCode != InputKind.touch.index;

  static double _coordinate(double n) {
    if (!n.isFinite) throw const FormatException('Invalid drawing coordinate');
    return n.clamp(0, 1);
  }

  /// Existing points remain exactly the three-number version-1 representation.
  /// Optional v2 metadata is [pressure or -1, tilt or -1, stable device code].
  List<num> toJson() => [
    u,
    v,
    ms,
    if (hasInputMetadata) ...[pressure ?? -1, tilt ?? -1, kindCode],
  ];

  factory InkPoint.fromJson(List<dynamic> j) {
    if (j.length != 3 && j.length != 6) {
      throw const FormatException('Invalid drawing point');
    }
    if (j.length == 3) {
      return InkPoint(
        (j[0] as num).toDouble(),
        (j[1] as num).toDouble(),
        j[2] as int,
      );
    }
    final code = j[5] as int;
    return InkPoint.input(
      (j[0] as num).toDouble(),
      (j[1] as num).toDouble(),
      ms: j[2] as int,
      pressure: j[3] == -1 ? null : (j[3] as num).toDouble(),
      tilt: j[4] == -1 ? null : (j[4] as num).toDouble(),
      kind: code >= 0 && code < InputKind.values.length
          ? InputKind.values[code]
          : InputKind.unknown,
      sourceKindCode: code,
    );
  }

  /// Clip endpoints retain pressure/tilt/timing without converting geometry-only
  /// points into expressive input. Erasure does not change the playback mode.
  static InkPoint interpolate(InkPoint a, InkPoint b, double t) {
    final source = t < .5 ? a : b;
    double? blend(double? x, double? y) =>
        x == null || y == null ? (t < .5 ? x : y) : x + (y - x) * t;
    return InkPoint.input(
      a.u + (b.u - a.u) * t,
      a.v + (b.v - a.v) * t,
      ms: (a.ms + (b.ms - a.ms) * t).round(),
      pressure: blend(a.pressure, b.pressure),
      tilt: blend(a.tilt, b.tilt),
      kind: source.kind,
      sourceKindCode: source.kindCode,
    );
  }
}

class Stroke {
  Stroke({
    required this.id,
    required this.instrument,
    required Iterable<InkPoint> points,
    this.width = .009,
    this.sourceInstrumentId,
    Map<String, dynamic> extraFields = const {},
  }) : extraFields = _freezeMetadata(extraFields),
       points = List.unmodifiable(points) {
    if (this.points.isEmpty || !width.isFinite || width <= 0 || width > .1) {
      throw const FormatException('Invalid stroke');
    }
  }
  final String id;
  final Instrument instrument;
  final String? sourceInstrumentId;
  final Map<String, dynamic> extraFields;
  String get instrumentId => sourceInstrumentId ?? instrument.name;
  bool get hasInstrumentFallback => instrumentId != instrument.name;
  Stroke copyWith({
    String? id,
    Instrument? instrument,
    Iterable<InkPoint>? points,
    double? width,
  }) => Stroke(
    id: id ?? this.id,
    instrument: instrument ?? this.instrument,
    points: points ?? this.points,
    width: width ?? this.width,
    sourceInstrumentId: instrument == null ? sourceInstrumentId : null,
    extraFields: extraFields,
  );
  final List<InkPoint> points;
  final double width;
  late final Set<int> displayPixels = displayPixelCells(points);
  // Geometry is immutable; cache bounds for conservative eraser rejection.
  late final ({double minU, double maxU, double minV, double maxV}) bounds =
      _bounds();
  ({double minU, double maxU, double minV, double maxV}) _bounds() {
    var minU = points.first.u, maxU = minU;
    var minV = points.first.v, maxV = minV;
    for (final point in points.skip(1)) {
      minU = math.min(minU, point.u);
      maxU = math.max(maxU, point.u);
      minV = math.min(minV, point.v);
      maxV = math.max(maxV, point.v);
    }
    return (minU: minU, maxU: maxU, minV: minV, maxV: maxV);
  }

  Map<String, dynamic> toJson() => {
    ...extraFields,
    'id': id,
    'instrument': instrumentId,
    'width': width,
    'points': points.map((p) => p.toJson()).toList(),
  };
  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
    id: j['id'] as String,
    instrument: Instrument.resolve(j['instrument'] as String),
    sourceInstrumentId: j['instrument'] as String,
    extraFields: {
      for (final e in j.entries)
        if (!const ['id', 'instrument', 'width', 'points'].contains(e.key))
          e.key: e.value,
    },
    width: (j['width'] as num).toDouble(),
    points: (j['points'] as List).map((p) => InkPoint.fromJson(p as List)),
  );
}

class ProjectDocument {
  ProjectDocument({
    required this.id,
    this.title = 'Untitled drawing',
    Iterable<Stroke> strokes = const [],
    this.tempo = 120,
    this.scale = MusicalScale.major,
    this.root = RootKey.c,
    this.paper,
    this.mix = const AccompanimentMix(),
    this.sourceScaleId,
    this.sourceRootId,
    int formatVersion = 1,
    int soundVersion = 1,
    Map<String, dynamic> extraFields = const {},
    this.background = 0xfff7f5eb,
    this.style = DrawingStyle.smooth,
    this.expressionMode = ExpressionMode.geometry,
    this.revision = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : _formatVersion = formatVersion,
       _soundVersion = soundVersion,
       extraFields = _freezeMetadata(extraFields),
       strokes = List.unmodifiable(strokes),
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? DateTime.now().toUtc() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
        title.trim().isEmpty ||
        title.length > 60 ||
        tempo < 60 ||
        tempo > 200 ||
        background < 0 ||
        background > 0xffffffff ||
        pointCount > 100000 ||
        revision < 0 ||
        !const [1, 2].contains(formatVersion) ||
        !const [1, 2].contains(soundVersion)) {
      throw const FormatException('Invalid project');
    }
  }
  static const schemaVersion = 1, engineVersion = 1;
  final String id, title;
  final List<Stroke> strokes;
  final int tempo, background, revision;
  final MusicalScale scale;
  final RootKey root;
  final BackgroundDefinition? paper;
  final AccompanimentMix mix;
  BackgroundDefinition get effectiveBackground =>
      paper ?? BackgroundDefinition.solid(background);
  final String? sourceScaleId, sourceRootId;
  final int _formatVersion, _soundVersion;
  final Map<String, dynamic> extraFields;
  String get scaleId => sourceScaleId ?? scale.name;
  String get rootId => sourceRootId ?? root.name;
  bool get hasScaleFallback => scaleId != scale.name;
  bool get hasRootFallback => rootId != root.name;
  List<String> get unknownInstrumentIds => strokes
      .where((s) => s.hasInstrumentFallback)
      .map((s) => s.instrumentId)
      .toSet()
      .toList(growable: false);
  bool get hasCompatibilityFallbacks =>
      hasScaleFallback ||
      hasRootFallback ||
      strokes.any((s) => s.hasInstrumentFallback);
  bool get _expandedMusic =>
      expressionMode == ExpressionMode.expressive ||
      mix.isConfigured ||
      root != RootKey.c ||
      scale.index > 1 ||
      strokes.any((s) => s.instrument.index > 2);
  // Existing v1 content retains its exact schema/engine. New catalog use is
  // explicit version 2; merely opening and saving a v1 file does not upgrade it.
  late final bool hasInputMetadata = strokes.any(
    (s) => s.points.any((p) => p.hasInputMetadata),
  );
  int get formatVersion => (_expandedMusic || paper != null || hasInputMetadata)
      ? math.max(2, _formatVersion)
      : _formatVersion;
  int get soundVersion =>
      _expandedMusic ? math.max(2, _soundVersion) : _soundVersion;
  final DrawingStyle style;
  final ExpressionMode expressionMode;
  final DateTime createdAt, updatedAt;
  late final int pointCount = strokes.fold(0, (n, s) => n + s.points.length);
  ProjectDocument copyWith({
    String? id,
    String? title,
    List<Stroke>? strokes,
    int? tempo,
    MusicalScale? scale,
    RootKey? root,
    BackgroundDefinition? paper,
    bool clearPaper = false,
    AccompanimentMix? mix,
    int? background,
    DrawingStyle? style,
    ExpressionMode? expressionMode,
    int? revision,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProjectDocument(
    id: id ?? this.id,
    title: title ?? this.title,
    strokes: strokes ?? this.strokes,
    tempo: tempo ?? this.tempo,
    scale: scale ?? this.scale,
    root: root ?? this.root,
    paper: clearPaper ? null : paper ?? this.paper,
    mix: mix ?? this.mix,
    sourceScaleId: scale == null ? sourceScaleId : null,
    sourceRootId: root == null ? sourceRootId : null,
    formatVersion: formatVersion,
    soundVersion: soundVersion,
    extraFields: extraFields,
    background: background ?? this.background,
    style: style ?? this.style,
    expressionMode: expressionMode ?? this.expressionMode,
    revision: revision ?? this.revision + 1,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
  );
  Map<String, dynamic> toJson() => {
    ...extraFields,
    'schemaVersion': formatVersion,
    'engineVersion': soundVersion,
    'id': id,
    'title': title,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'tempo': tempo,
    'scale': scaleId,
    if (formatVersion >= 2 || rootId != 'c') 'root': rootId,
    'background': background,
    if (paper != null) 'paper': paper!.toJson(),
    if (mix.isConfigured) 'mix': mix.toJson(),
    'style': style.name,
    if (expressionMode != ExpressionMode.geometry)
      'expressionMode': expressionMode.name,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  String encode() => jsonEncode(toJson());
  factory ProjectDocument.decode(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (!const [1, 2].contains(j['schemaVersion']) ||
        !const [1, 2].contains(j['engineVersion'])) {
      throw const FormatException(
        'Unsupported project version; original file preserved',
      );
    }
    return ProjectDocument(
      id: j['id'] as String,
      title: j['title'] as String,
      strokes: (j['strokes'] as List).map(
        (s) => Stroke.fromJson(s as Map<String, dynamic>),
      ),
      tempo: j['tempo'] as int,
      scale: MusicalScale.resolve(j['scale'] as String),
      mix: j['mix'] == null
          ? const AccompanimentMix()
          : AccompanimentMix.fromJson(j['mix'] as Map<String, dynamic>),
      paper: j['paper'] == null
          ? null
          : BackgroundDefinition.fromJson(j['paper'] as Map<String, dynamic>),
      root: RootKey.resolve(j['root'] as String? ?? 'c'),
      sourceScaleId: j['scale'] as String,
      sourceRootId: j['root'] as String?,
      formatVersion: j['schemaVersion'] as int,
      soundVersion: j['engineVersion'] as int,
      extraFields: {
        for (final e in j.entries)
          if (!const [
            'schemaVersion',
            'engineVersion',
            'id',
            'title',
            'strokes',
            'tempo',
            'scale',
            'root',
            'background',
            'style',
            'expressionMode',
            'revision',
            'createdAt',
            'updatedAt',
            'paper',
            'mix',
          ].contains(e.key))
            e.key: e.value,
      },
      background: j['background'] as int,
      style: DrawingStyle.values.byName(j['style'] as String? ?? 'smooth'),
      expressionMode: ExpressionMode.values.byName(
        j['expressionMode'] as String? ?? 'geometry',
      ),
      revision: j['revision'] as int,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random.secure().nextInt(1 << 32)}';

// Android video has no alpha channel. Composite paper over white identically
// in editor, thumbnails and native export, using integer rounding.
int opaquePaperColor(int argb) {
  final alpha = (argb >>> 24) & 255;
  int channel(int shift) =>
      ((((argb >>> shift) & 255) * alpha + 255 * (255 - alpha) + 127) ~/ 255);
  return 0xff000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}

// Original display policy: fixed 40 × 50 cells, independent of viewport size.
// Integer interpolation is symmetric under reversal and bounds output to 2,000
// cells. The score always uses the untouched normalized source points.
Set<int> displayPixelCells(List<InkPoint> points) {
  if (points.isEmpty) return const {};
  final cells = <int>{};
  int column(InkPoint p) => (p.u * 40).floor().clamp(0, 39);
  int row(InkPoint p) => (p.v * 50).floor().clamp(0, 49);
  var ax = column(points.first), ay = row(points.first);
  cells.add(ay * 40 + ax);
  for (final point in points.skip(1)) {
    final bx = column(point), by = row(point);
    final steps = math.max((bx - ax).abs(), (by - ay).abs());
    for (var i = 1; i <= steps; i++) {
      final x = ((ax * (steps - i) + bx * i) / steps).round();
      final y = ((ay * (steps - i) + by * i) / steps).round();
      cells.add(y * 40 + x);
    }
    ax = bx;
    ay = by;
  }
  return Set.unmodifiable(cells);
}

// Extension metadata remains inert JSON, deeply immutable and round-trippable.
Map<String, dynamic> _freezeMetadata(Map<String, dynamic> input) {
  dynamic freeze(dynamic value) => switch (value) {
    Map<String, dynamic> map => Map<String, dynamic>.unmodifiable(
      map.map((key, value) => MapEntry(key, freeze(value))),
    ),
    List<dynamic> list => List<dynamic>.unmodifiable(list.map(freeze)),
    _ => value,
  };
  return freeze(input) as Map<String, dynamic>;
}
