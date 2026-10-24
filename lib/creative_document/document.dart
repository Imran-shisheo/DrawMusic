import 'dart:convert';
import 'dart:math' as math;

enum Instrument { keys, mallet, bell }

enum MusicalScale { major, minor }

class InkPoint {
  InkPoint(double u, double v, [this.ms = 0])
    : u = _coordinate(u),
      v = _coordinate(v);
  final double u, v;
  final int ms;
  static double _coordinate(double n) {
    if (!n.isFinite) throw const FormatException('Invalid drawing coordinate');
    return n.clamp(0, 1);
  }

  List<num> toJson() => [u, v, ms];
  factory InkPoint.fromJson(List<dynamic> j) =>
      InkPoint((j[0] as num).toDouble(), (j[1] as num).toDouble(), j[2] as int);
}

class Stroke {
  Stroke({
    required this.id,
    required this.instrument,
    required Iterable<InkPoint> points,
    this.width = .009,
  }) : points = List.unmodifiable(points) {
    if (this.points.isEmpty || !width.isFinite || width <= 0 || width > .1) {
      throw const FormatException('Invalid stroke');
    }
  }
  final String id;
  final Instrument instrument;
  final List<InkPoint> points;
  final double width;
  Map<String, dynamic> toJson() => {
    'id': id,
    'instrument': instrument.name,
    'width': width,
    'points': points.map((p) => p.toJson()).toList(),
  };
  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
    id: j['id'] as String,
    instrument: Instrument.values.byName(j['instrument'] as String),
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
    this.background = 0xfff7f5eb,
    this.revision = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : strokes = List.unmodifiable(strokes),
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? DateTime.now().toUtc() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
        title.trim().isEmpty ||
        title.length > 60 ||
        tempo < 60 ||
        tempo > 200 ||
        pointCount > 100000 ||
        revision < 0) {
      throw const FormatException('Invalid project');
    }
  }
  static const schemaVersion = 1, engineVersion = 1;
  final String id, title;
  final List<Stroke> strokes;
  final int tempo, background, revision;
  final MusicalScale scale;
  final DateTime createdAt, updatedAt;
  int get pointCount => strokes.fold(0, (n, s) => n + s.points.length);
  ProjectDocument copyWith({
    String? id,
    String? title,
    List<Stroke>? strokes,
    int? tempo,
    MusicalScale? scale,
    int? background,
    int? revision,
  }) => ProjectDocument(
    id: id ?? this.id,
    title: title ?? this.title,
    strokes: strokes ?? this.strokes,
    tempo: tempo ?? this.tempo,
    scale: scale ?? this.scale,
    background: background ?? this.background,
    revision: revision ?? this.revision + 1,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'engineVersion': engineVersion,
    'id': id,
    'title': title,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'tempo': tempo,
    'scale': scale.name,
    'background': background,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  String encode() => jsonEncode(toJson());
  factory ProjectDocument.decode(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['schemaVersion'] != schemaVersion ||
        j['engineVersion'] != engineVersion) {
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
      scale: MusicalScale.values.byName(j['scale'] as String),
      background: j['background'] as int,
      revision: j['revision'] as int,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${math.Random.secure().nextInt(1 << 32)}';
