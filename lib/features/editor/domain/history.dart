import 'dart:collection';
import 'dart:math' as math;

import '../../../creative_document/document.dart';

/// Additional retained history is charged in bytes, with shared immutable
/// geometry counted once and current-document ownership excluded. This is a
/// conservative accounting policy, not a promise about VM heap or process RSS.
const historyMemoryBudgetBytes = 20 * 1024 * 1024;

class DocumentHistory {
  DocumentHistory(
    this.document, {
    this.maxHistoryBytes = historyMemoryBudgetBytes,
  });
  final int maxHistoryBytes;
  ProjectDocument document;
  final List<ProjectDocument> _undo = [], _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;
  int get redoCount => _redo.length;
  HistoryMemorySnapshot get memory => _measure();

  bool commit(ProjectDocument next) {
    if (_sameContent(next, document)) return false;
    _undo.add(document);
    _redo.clear();
    document = next;
    _trim();
    return true;
  }

  void undo() {
    if (canUndo) {
      _redo.add(document);
      document = _undo.removeLast().copyWith(revision: document.revision + 1);
      _trim();
    }
  }

  void redo() {
    if (canRedo) {
      _undo.add(document);
      document = _redo.removeLast().copyWith(revision: document.revision + 1);
      _trim();
    }
  }

  void _trim() {
    while (_undo.isNotEmpty || _redo.isNotEmpty) {
      if (_undo.length + _redo.length <= 100 &&
          _measure(stopAfter: maxHistoryBytes).retainedBytes <=
              maxHistoryBytes) {
        return;
      }
      // Drop the furthest reachable commands. The current document is never
      // trimmed, rewritten, simplified or substituted by history eviction.
      if (_undo.isNotEmpty) {
        _undo.removeAt(0);
      } else {
        _redo.removeAt(0);
      }
    }
  }

  HistoryMemorySnapshot _measure({int? stopAfter}) {
    final ledger = _MemoryLedger();
    ledger.document(document);
    final current = ledger.bytes;
    for (final previous in [..._undo, ..._redo]) {
      ledger.document(previous);
      if (stopAfter != null && ledger.bytes - current > stopAfter) break;
    }
    return HistoryMemorySnapshot(current, ledger.bytes - current);
  }
}

/// Additional ownership required to retain [previous] as one Undo command.
/// Automatic geometry changes use this before committing so the policy cannot
/// immediately evict the very snapshot needed to undo the simplification.
int additionalHistoryBytes(ProjectDocument previous, ProjectDocument current) {
  final ledger = _MemoryLedger();
  ledger.document(current);
  final currentBytes = ledger.bytes;
  ledger.document(previous);
  return ledger.bytes - currentBytes;
}

class HistoryMemorySnapshot {
  const HistoryMemorySnapshot(this.currentDocumentBytes, this.retainedBytes);
  final int currentDocumentBytes, retainedBytes;
}

class _MemoryLedger {
  final _seen = HashSet<Object>.identity();
  var bytes = 0;
  bool add(Object object, int count) {
    if (!_seen.add(object)) return false;
    bytes += count;
    return true;
  }

  void document(ProjectDocument doc) {
    if (!add(doc, 512)) return;
    jsonValue(doc.id);
    jsonValue(doc.title);
    jsonValue(doc.extraFields);
    jsonValue(doc.scaleId);
    jsonValue(doc.rootId);
    final paper = doc.paper;
    if (paper != null && add(paper, 192)) {
      add(paper.crop, 64);
      jsonValue(paper.colors);
      jsonValue(paper.assetId);
      jsonValue(paper.unknownKind);
    }
    if (add(doc.mix, 64) &&
        add(doc.mix.layers, 64 + 64 * doc.mix.layers.length)) {
      for (final layer in doc.mix.layers.values) {
        add(layer, 64);
      }
    }
    if (add(doc.strokes, 64 + 16 * doc.strokes.length)) {
      for (final stroke in doc.strokes) {
        if (!add(stroke, 256)) continue;
        jsonValue(stroke.id);
        jsonValue(stroke.instrumentId);
        jsonValue(stroke.extraFields);
        // Reserve bounds and the maximum possible lazily built pixel cache.
        // One segment crosses at most 50 grid steps; the whole grid has 2000
        // cells. Reserving now avoids allocations escaping the history policy
        // when the user later switches display style.
        final cells = math.min(2000, 1 + 50 * (stroke.points.length - 1));
        bytes += 128 + 64 * cells;
        if (add(stroke.points, 64 + 16 * stroke.points.length)) {
          for (final point in stroke.points) {
            add(point, 128);
          }
        }
      }
    }
  }

  void jsonValue(Object? root) {
    final pending = <Object?>[root];
    while (pending.isNotEmpty) {
      final value = pending.removeLast();
      if (value == null || value is bool || value is num) continue;
      if (value is String) {
        add(value, 32 + value.length * 2);
      } else if (value is Map) {
        if (add(value, 64 + value.length * 64)) {
          pending.addAll(value.keys);
          pending.addAll(value.values);
        }
      } else if (value is List) {
        if (add(value, 64 + value.length * 16)) pending.addAll(value);
      }
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
      a.scaleId != b.scaleId ||
      a.rootId != b.rootId ||
      a.formatVersion != b.formatVersion ||
      a.soundVersion != b.soundVersion ||
      !_sameJson(a.extraFields, b.extraFields) ||
      a.background != b.background ||
      !_sameJson(a.paper?.toJson(), b.paper?.toJson()) ||
      !_sameJson(a.mix.toJson(), b.mix.toJson()) ||
      a.style != b.style ||
      a.expressionMode != b.expressionMode ||
      a.createdAt != b.createdAt ||
      a.strokes.length != b.strokes.length) {
    return false;
  }
  for (var i = 0; i < a.strokes.length; i++) {
    final x = a.strokes[i], y = b.strokes[i];
    if (identical(x, y)) continue;
    if (x.id != y.id ||
        x.instrumentId != y.instrumentId ||
        !_sameJson(x.extraFields, y.extraFields) ||
        x.width != y.width ||
        x.points.length != y.points.length) {
      return false;
    }
    for (var j = 0; j < x.points.length; j++) {
      final p = x.points[j], q = y.points[j];
      if (p.u != q.u ||
          p.v != q.v ||
          p.ms != q.ms ||
          p.pressure != q.pressure ||
          p.tilt != q.tilt ||
          p.kindCode != q.kindCode) {
        return false;
      }
    }
  }
  return true;
}

bool _sameJson(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
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
      InkPoint at(double t) => InkPoint.interpolate(a, b, t);
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
          stroke.copyWith(id: '${stroke.id}_$i', points: fragments[i]),
        );
      }
    }
  }
  return changed ? result : strokes;
}
