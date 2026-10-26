import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';

// A bounded visual intersection index, built away from the UI isolate. This
// never schedules sound; it only explains geometry at the hardware playhead.
List<List<(int, double)>> indexIntersections(ProjectDocument doc) {
  final bins = List.generate(96, (_) => <(int, double)>[]);
  void add(int bin, int color, double v) {
    if (bins[bin].length < 32 &&
        !bins[bin].any((m) => m.$1 == color && (m.$2 - v).abs() < .006)) {
      bins[bin].add((color, v));
    }
  }

  for (final stroke in doc.strokes) {
    final color = stroke.instrument.definition.color;
    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      add((p.u * 96).floor().clamp(0, 95), color, p.v);
    }
    for (var i = 1; i < stroke.points.length; i++) {
      var a = stroke.points[i - 1], b = stroke.points[i];
      if (a.u > b.u) {
        final swap = a;
        a = b;
        b = swap;
      }
      if ((b.u - a.u).abs() < 1e-12) {
        final bin = (a.u * 96).floor().clamp(0, 95);
        add(bin, color, a.v);
        add(bin, color, b.v);
        continue;
      }
      final first = (a.u * 96).floor().clamp(0, 95),
          last = (b.u * 96).floor().clamp(0, 95);
      for (var bin = first; bin <= last; bin++) {
        final u = ((bin + .5) / 96).clamp(a.u, b.u);
        add(bin, color, a.v + (b.v - a.v) * (u - a.u) / (b.u - a.u));
      }
    }
  }
  return bins;
}

class PlaybackIntersections extends StatefulWidget {
  const PlaybackIntersections({
    super.key,
    required this.document,
    required this.cursor,
  });
  final ProjectDocument document;
  final ValueNotifier<double?> cursor;
  @override
  State<PlaybackIntersections> createState() => _PlaybackIntersectionsState();
}

class _PlaybackIntersectionsState extends State<PlaybackIntersections> {
  late Future<List<List<(int, double)>>> index = compute(
    indexIntersections,
    widget.document,
  );
  @override
  void didUpdateWidget(covariant PlaybackIntersections old) {
    super.didUpdateWidget(old);
    if (!identical(old.document.strokes, widget.document.strokes)) {
      index = compute(indexIntersections, widget.document);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return FutureBuilder(
      future: index,
      builder: (context, snapshot) => CustomPaint(
        painter: _IntersectionPainter(widget.cursor, snapshot.data ?? const []),
      ),
    );
  }
}

class _IntersectionPainter extends CustomPainter {
  _IntersectionPainter(this.cursor, this.bins) : super(repaint: cursor);
  final ValueNotifier<double?> cursor;
  final List<List<(int, double)>> bins;
  @override
  void paint(Canvas canvas, Size size) {
    final fraction = cursor.value;
    if (fraction == null || bins.isEmpty) return;
    final bin = (fraction * 96).floor().clamp(0, 95);
    for (final mark in bins[bin]) {
      final center = Offset(fraction * size.width, mark.$2 * size.height);
      canvas.drawCircle(center, 6, Paint()..color = Colors.white);
      canvas.drawCircle(center, 4, Paint()..color = Color(mark.$1));
      canvas.drawCircle(
        center,
        7,
        Paint()
          ..color = const Color(0xff243b35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IntersectionPainter old) =>
      old.bins != bins || old.cursor != cursor;
}
