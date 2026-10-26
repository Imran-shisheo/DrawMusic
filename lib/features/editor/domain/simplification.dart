import '../../../creative_document/document.dart';
import '../../composition/domain/score.dart';
import 'history.dart';

/// Original geometry policy: at most .75 dp on a fixed 800 × 1000 reference
/// document, independent of viewport size. A musical equivalence check must
/// accept every replacement. This is never an event/polyphony truncation.
const simplificationReferenceWidth = 800.0;
const simplificationReferenceHeight = 1000.0;
const simplificationToleranceDp = .75;
const simplificationPointThreshold = 80000;

class GeometrySimplification {
  const GeometrySimplification(this.strokes, this.before, this.after);
  final List<Stroke> strokes;
  final int before, after;
  bool get changed => after < before;
}

/// Work is bounded even for adversarial zigzags. Exhausted strokes retain their
/// exact geometry; complexity errors still reach the normal explicit UI path.
GeometrySimplification simplifyGeometry(
  ProjectDocument document, {
  int maxDistanceChecks = 2000000,
}) {
  final budget = _WorkBudget(maxDistanceChecks);
  var after = 0;
  final strokes = <Stroke>[];
  for (final stroke in document.strokes) {
    var next = stroke;
    if (stroke.points.length > 2 && budget.remaining > 0) {
      final points = _simplify(stroke.points, budget);
      if (points.length < stroke.points.length) {
        final candidate = stroke.copyWith(points: points);
        if (_sameScore(document, stroke, candidate) &&
            (document.style != DrawingStyle.pixel ||
                _sameCells(stroke.displayPixels, candidate.displayPixels))) {
          next = candidate;
        }
      }
    }
    strokes.add(next);
    after += next.points.length;
  }
  if (after < document.pointCount &&
      additionalHistoryBytes(document, document.copyWith(strokes: strokes)) >
          historyMemoryBudgetBytes) {
    // A large exclusive pre-change cache/geometry owner must remain recoverable.
    return GeometrySimplification(
      document.strokes,
      document.pointCount,
      document.pointCount,
    );
  }
  return GeometrySimplification(
    after == document.pointCount
        ? document.strokes
        : List.unmodifiable(strokes),
    document.pointCount,
    after,
  );
}

bool _sameCells(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameScore(ProjectDocument document, Stroke a, Stroke b) {
  try {
    final before = compileScore(document.copyWith(strokes: [a])).notes;
    final after = compileScore(document.copyWith(strokes: [b])).notes;
    if (before.length != after.length) return false;
    for (var i = 0; i < before.length; i++) {
      final x = before[i], y = after[i];
      if (x.instrument != y.instrument ||
          x.pitch != y.pitch ||
          x.startBin != y.startBin ||
          x.endBin != y.endBin ||
          x.velocity != y.velocity ||
          x.gain != y.gain ||
          x.percussion != y.percussion ||
          x.midiChannelOverride != y.midiChannelOverride) {
        return false;
      }
    }
    return true;
  } on ScoreComplexityException {
    // Do not substitute a simplified score for an already unsafe source.
    return false;
  }
}

class _WorkBudget {
  _WorkBudget(this.remaining);
  int remaining;
}

List<InkPoint> _simplify(List<InkPoint> input, _WorkBudget budget) {
  // Canonical orientation makes tie-breaking invariant under reversed input.
  var reverse = false;
  for (var i = 0; i < input.length; i++) {
    final a = input[i], b = input[input.length - 1 - i];
    final order = a.u.compareTo(b.u);
    final comparison = order == 0 ? a.v.compareTo(b.v) : order;
    if (comparison != 0) {
      reverse = comparison > 0;
      break;
    }
  }
  InkPoint at(int i) => input[reverse ? input.length - 1 - i : i];
  final keep = <int>{0, input.length - 1};
  // Preserve the exact original segment straddling each horizontal score-bin
  // boundary, plus coordinate extrema. Within each monotonic/bin-local piece,
  // simplifying cannot move an occupied pitch extremum or a bin crossing.
  var lastU = 0, lastV = 0;
  var lastUMove = 0, lastVMove = 0;
  for (var i = 1; i < input.length; i++) {
    final a = at(i - 1), b = at(i);
    final ua = (a.u * 96).floor().clamp(0, 95);
    final ub = (b.u * 96).floor().clamp(0, 95);
    if (ua != ub) {
      keep.add(i - 1);
      keep.add(i);
    }
    final du = (b.u - a.u).sign.toInt();
    final dv = (b.v - a.v).sign.toInt();
    if (du != 0) {
      if (lastU != 0 && du != lastU) {
        keep.add(i - 1);
        keep.add(lastUMove);
      }
      lastU = du;
      lastUMove = i;
    }
    if (dv != 0) {
      if (lastV != 0 && dv != lastV) {
        keep.add(i - 1);
        keep.add(lastVMove);
      }
      lastV = dv;
      lastVMove = i;
    }
  }
  final anchors = keep.toList()..sort();
  final pending = <(int, int)>[
    for (var i = 1; i < anchors.length; i++) (anchors[i - 1], anchors[i]),
  ];
  const tolerance = simplificationToleranceDp / simplificationReferenceHeight;
  const toleranceSquared = tolerance * tolerance;
  while (pending.isNotEmpty) {
    final (start, end) = pending.removeLast();
    final a = at(start), b = at(end);
    final ax = a.u * .8, ay = a.v;
    final dx = (b.u - a.u) * .8, dy = b.v - a.v;
    final lengthSquared = dx * dx + dy * dy;
    var furthest = -1, maximum = toleranceSquared;
    for (var i = start + 1; i < end; i++) {
      if (budget.remaining-- <= 0) return input;
      final p = at(i);
      final px = p.u * .8 - ax, py = p.v - ay;
      final projection = lengthSquared == 0
          ? 0.0
          : ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
      final ex = px - projection * dx, ey = py - projection * dy;
      final distance = ex * ex + ey * ey;
      if (distance > maximum) {
        maximum = distance;
        furthest = i;
      }
    }
    if (furthest >= 0) {
      keep.add(furthest);
      pending.add((start, furthest));
      pending.add((furthest, end));
    }
  }
  final indices = keep.toList()..sort();
  final result = [for (final i in indices) at(i)];
  return reverse ? result.reversed.toList() : result;
}
