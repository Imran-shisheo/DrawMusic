import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../domain/history.dart';

const instrumentColors = [
  Color(0xff7961c6),
  Color(0xffa46b16),
  Color(0xff287e61),
];
const instrumentNames = ['Cloud keys', 'Wood drops', 'Glass stars'];
const instrumentIcons = [
  Icons.piano,
  Icons.water_drop_outlined,
  Icons.auto_awesome,
];

class DrawingPainter extends CustomPainter {
  DrawingPainter(
    this.document, {
    this.active = const [],
    this.instrument = Instrument.keys,
    this.previewStrokes,
    super.repaint,
  });
  final ProjectDocument document;
  final List<InkPoint> active;
  final Instrument instrument;
  final List<Stroke>? previewStrokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final stroke in previewStrokes ?? document.strokes) {
      paintStroke(canvas, size, stroke.points, stroke.instrument, stroke.width);
    }
    paintStroke(canvas, size, active, instrument, .009);
  }

  static void paintStroke(
    Canvas canvas,
    Size size,
    List<InkPoint> points,
    Instrument instrument,
    double width,
  ) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = instrumentColors[instrument.index]
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * size.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset at(InkPoint p) => Offset(p.u * size.width, p.v * size.height);
    if (points.length == 1) {
      canvas.drawCircle(
        at(points.first),
        width * size.width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter old) =>
      old.document != document ||
      old.active != active ||
      old.previewStrokes != previewStrokes ||
      old.instrument != instrument;
}

class CursorPainter extends CustomPainter {
  CursorPainter(this.cursor) : super(repaint: cursor);
  final ValueNotifier<double?> cursor;
  @override
  void paint(Canvas canvas, Size size) {
    if (cursor.value == null) return;
    final x = cursor.value! * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = const Color(0xff007e73)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(x, 6),
      5,
      Paint()..color = const Color(0xff007e73),
    );
  }

  @override
  bool shouldRepaint(CursorPainter old) => old.cursor != cursor;
}

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.document,
    required this.instrument,
    required this.eraser,
    required this.cursor,
    required this.onCommit,
    required this.onLimit,
  });
  final ProjectDocument document;
  final Instrument instrument;
  final bool eraser;
  final ValueNotifier<double?> cursor;
  final ValueChanged<List<Stroke>> onCommit;
  final VoidCallback onLimit;
  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  int? _pointer;
  final _clock = Stopwatch();
  final _preview = ValueNotifier(0);
  List<InkPoint> _active = [];
  late List<Stroke> _baseStrokes;
  int _basePointCount = 0;
  @override
  void initState() {
    super.initState();
    _baseStrokes = widget.document.strokes;
    _basePointCount = widget.document.pointCount;
  }

  List<Stroke>? _erased;
  InkPoint? _lastErase;
  double _height = 1;
  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      final geometryChanged = !listEquals(
        _baseStrokes,
        widget.document.strokes,
      );
      _baseStrokes = widget.document.strokes;
      _basePointCount = widget.document.pointCount;
      if (geometryChanged) {
        _active = [];
        _erased = null;
        _lastErase = null;
        _pointer = null;
      }
    }
  }

  void finish() {
    if (_pointer == null) return;
    _pointer = null;
    if (widget.eraser) {
      if (_erased != null && !identical(_erased, _baseStrokes)) {
        _baseStrokes = _erased!;
        _basePointCount = _baseStrokes.fold(0, (n, s) => n + s.points.length);
        widget.onCommit(_baseStrokes);
      }
    } else if (_active.isNotEmpty) {
      _basePointCount += _active.length;
      _baseStrokes = [
        ..._baseStrokes,
        Stroke(id: newId(), instrument: widget.instrument, points: _active),
      ];
      widget.onCommit(_baseStrokes);
    }
    _active = [];
    _erased = null;
    _lastErase = null;
    _preview.value++;
  }

  void _sample(Offset point, Size size) {
    final p = InkPoint(
      point.dx / size.width,
      point.dy / size.height,
      _clock.elapsedMilliseconds,
    );
    if (widget.eraser) {
      final last = _lastErase ?? p;
      final distance = math.sqrt(
        math.pow((p.u - last.u) * .8, 2) + math.pow(p.v - last.v, 2),
      );
      final radius = 12 / _height;
      final steps = math.max(1, (distance / (radius * .5)).ceil());
      for (var s = 1; s <= steps; s++) {
        _erased = eraseAt(
          _erased ?? _baseStrokes,
          InkPoint(
            last.u + (p.u - last.u) * s / steps,
            last.v + (p.v - last.v) * s / steps,
          ),
          radius,
        );
      }
      _lastErase = p;
    } else {
      if (_basePointCount + _active.length >= 100000) {
        finish();
        widget.onLimit();
        return;
      }
      _active.add(p);
    }
    _preview.value++;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      _height = size.height;
      return Semantics(
        label: 'Drawing canvas. Horizontal position controls time; height controls pitch.',
        child: Listener(
          key: const ValueKey('drawing-canvas'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_pointer != null) return;
            _pointer = event.pointer;
            _clock
              ..reset()
              ..start();
            _sample(event.localPosition, size);
          },
          onPointerMove: (event) {
            if (event.pointer != _pointer) return;
            if (!(Offset.zero & size).contains(event.localPosition)) {
              finish();
              return;
            }
            _sample(event.localPosition, size);
          },
          onPointerUp: (event) {
            if (event.pointer == _pointer) finish();
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) finish();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Color(opaquePaperColor(widget.document.background)),
                ),
                RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: _preview,
                    builder: (_, _) => CustomPaint(
                      painter: DrawingPainter(
                        widget.document,
                        previewStrokes: _erased,
                      ),
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: _preview,
                    builder: (_, _) => CustomPaint(
                      painter: DrawingPainter(
                        widget.document,
                        active: _active,
                        repaint: _preview,
                        instrument: widget.instrument,
                        previewStrokes: const [],
                      ),
                    ),
                  ),
                ),
                if (widget.document.strokes.isEmpty)
                  const IgnorePointer(
                    child: Center(
                      child: Text(
                        'Leave a little melody here.',
                        style: TextStyle(color: Color(0xff64746e)),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: CursorPainter(widget.cursor)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
