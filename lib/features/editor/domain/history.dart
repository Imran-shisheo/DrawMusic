import 'dart:math' as math;

import '../../../creative_document/document.dart';

class DocumentHistory {
  DocumentHistory(this.document);
  ProjectDocument document;
  final List<ProjectDocument> _undo = [], _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool commit(ProjectDocument next) {
    if (_sameContent(next, document)) return false;
    _undo.add(document);
    _redo.clear();
    document = next;
    // Bound retained point geometry as well as command count (~20 MB budget).
    while (_undo.length > 100 ||
        (_undo.length > 1 &&
            _undo.fold<int>(0, (n, d) => n + d.pointCount) > 400000)) {
      _undo.removeAt(0);
    }
    return true;
  }

  void undo() {
    if (canUndo) {
      _redo.add(document);
      document = _undo.removeLast().copyWith(revision: document.revision + 1);
    }
  }

  void redo() {
    if (canRedo) {
      _undo.add(document);
      document = _redo.removeLast().copyWith(revision: document.revision + 1);
    }
  }
}

// Revision and save timestamps are bookkeeping, not user edits. Shared immutable
// geometry makes ordinary title/tempo commits cheap; decoded clones compare by
// actual content without allocating two large JSON strings.
bool _sameContent(ProjectDocument a, ProjectDocument b) {
  if (identical(a, b)) return true;
  if (a.id != b.id ||
      a.title != b.title ||
      a.tempo != b.tempo ||
      a.scale != b.scale ||
      a.background != b.background ||
      a.style != b.style ||
      a.createdAt != b.createdAt ||
      a.strokes.length != b.strokes.length) {
    return false;
  }
  for (var i = 0; i < a.strokes.length; i++) {
    final x = a.strokes[i], y = b.strokes[i];
    if (identical(x, y)) continue;
    if (x.id != y.id ||
        x.instrument != y.instrument ||
        x.width != y.width ||
        x.points.length != y.points.length) {
      return false;
    }
    for (var j = 0; j < x.points.length; j++) {
      final p = x.points[j], q = y.points[j];
      if (p.u != q.u || p.v != q.v || p.ms != q.ms) return false;
    }
  }
  return true;
}

// Clip segments against an eraser disk. Split intersections exactly so an erased
// horizontal span becomes a real score gap, independent of sample density.
List<Stroke> eraseAt(
  List<Stroke> strokes,
  InkPoint center,
  double radius, {
  double aspect = .8,
}) {
  final result = <Stroke>[];
  var changed = false;
  for (final stroke in strokes) {
    if (stroke.points.length > 1 && radius.isFinite && aspect.isFinite) {
      final bounds = stroke.bounds;
      final horizontal = aspect == 0
          ? double.infinity
          : radius.abs() / aspect.abs();
      if (bounds.maxU < center.u - horizontal ||
          bounds.minU > center.u + horizontal ||
          bounds.maxV < center.v - radius.abs() ||
          bounds.minV > center.v + radius.abs()) {
        result.add(stroke);
        continue;
      }
    }
    // Track per-stroke changes: erasing an earlier stroke must not rewrite
    // untouched later strokes (which also invalidates their cached geometry).
    var strokeChanged = false;
    final fragments = <List<InkPoint>>[];
    var current = <InkPoint>[];
    double distance(InkPoint p) =>
        math.pow((p.u - center.u) * aspect, 2).toDouble() +
        math.pow(p.v - center.v, 2).toDouble();
    if (stroke.points.length == 1) {
      if (distance(stroke.points.first) > radius * radius) {
        result.add(stroke);
      } else {
        changed = true;
      }
      continue;
    }
    for (var i = 1; i < stroke.points.length; i++) {
      final a = stroke.points[i - 1], b = stroke.points[i];
      final dx = (b.u - a.u) * aspect, dy = b.v - a.v;
      final fx = (a.u - center.u) * aspect, fy = a.v - center.v;
      final aa = dx * dx + dy * dy,
          bb = 2 * (fx * dx + fy * dy),
          cc = fx * fx + fy * fy - radius * radius;
      final cuts = <double>[0, 1];
      final disc = bb * bb - 4 * aa * cc;
      if (aa > 1e-20 && disc > 0) {
        for (final t in [
          (-bb - math.sqrt(disc)) / (2 * aa),
          (-bb + math.sqrt(disc)) / (2 * aa),
        ]) {
          if (t > 0 && t < 1) cuts.add(t);
        }
      }
      cuts.sort();
      InkPoint at(double t) => InkPoint(
        a.u + (b.u - a.u) * t,
        a.v + (b.v - a.v) * t,
        (a.ms + (b.ms - a.ms) * t).round(),
      );
      for (var c = 1; c < cuts.length; c++) {
        final t0 = cuts[c - 1], t1 = cuts[c];
        if (distance(at((t0 + t1) / 2)) > radius * radius) {
          if (current.isEmpty) current.add(at(t0));
          current.add(at(t1));
        } else {
          changed = true;
          strokeChanged = true;
          if (current.isNotEmpty) fragments.add(current);
          current = [];
        }
      }
    }
    if (current.isNotEmpty) fragments.add(current);
    if (!strokeChanged) {
      result.add(stroke);
    } else {
      for (var i = 0; i < fragments.length; i++) {
        result.add(
          Stroke(
            id: '${stroke.id}_$i',
            instrument: stroke.instrument,
            points: fragments[i],
            width: stroke.width,
          ),
        );
      }
    }
  }
  return changed ? result : strokes;
}
