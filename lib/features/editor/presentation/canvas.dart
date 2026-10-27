import 'package:scribblesong/l10n/strings.dart';

import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../domain/history.dart';
import 'playback_intersections.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../domain/simplification.dart';

final instrumentColors = [
  for (final i in Instrument.values) Color(i.definition.color),
];
String instrumentName(BuildContext context, Instrument instrument) =>
    switch (instrument) {
      Instrument.keys => context.strings.cloudKeys,
      Instrument.mallet => context.strings.woodDrops,
      Instrument.bell => context.strings.glassStars,
      Instrument.warmSynth => context.strings.warmSynth,
      Instrument.pluck => context.strings.pluck,
      Instrument.flute => context.strings.flute,
      Instrument.strings => context.strings.strings,
      Instrument.chime => context.strings.chime,
      Instrument.bass => context.strings.bass,
      Instrument.chip => context.strings.chip,
      Instrument.electronicBass => context.strings.electronicBass,
      Instrument.guitar => context.strings.guitar,
      Instrument.saxophone => context.strings.saxophone,
    };
const instrumentIcons = [
  Icons.piano,
  Icons.water_drop_outlined,
  Icons.auto_awesome,
  Icons.waves,
  Icons.spa_outlined,
  Icons.air,
  Icons.straighten,
  Icons.notifications_none,
  Icons.graphic_eq,
  Icons.memory,
  Icons.bolt,
  Icons.music_note,
  Icons.surround_sound,
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
      paintStroke(
        canvas,
        size,
        stroke.points,
        stroke.instrument,
        stroke.width,
        style: document.style,
        pixels: document.style == DrawingStyle.pixel
            ? stroke.displayPixels
            : null,
      );
    }
    paintStroke(canvas, size, active, instrument, .009, style: document.style);
  }

  static void paintStroke(
    Canvas canvas,
    Size size,
    List<InkPoint> points,
    Instrument instrument,
    double width, {
    DrawingStyle style = DrawingStyle.smooth,
    Set<int>? pixels,
  }) {
    if (points.isEmpty) return;
    if (style == DrawingStyle.pixel) {
      final paint = Paint()
        ..color = instrumentColors[instrument.index]
        ..isAntiAlias = false;
      for (final cell in pixels ?? displayPixelCells(points)) {
        final x = cell % 40, y = cell ~/ 40;
        canvas.drawRect(
          Rect.fromLTRB(
            x * size.width / 40,
            y * size.height / 50,
            (x + 1) * size.width / 40,
            (y + 1) * size.height / 50,
          ),
          paint,
        );
      }
      return;
    }
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

class EraserCursorPainter extends CustomPainter {
  EraserCursorPainter(this.point);
  final InkPoint? point;
  @override
  void paint(Canvas canvas, Size size) {
    final position = point;
    if (position == null) return;
    canvas.drawCircle(
      Offset(position.u * size.width, position.v * size.height),
      12,
      Paint()
        ..color = const Color(0xff007e73)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(EraserCursorPainter old) => old.point != point;
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
    this.onSimplified,
  });
  final ProjectDocument document;
  final Instrument instrument;
  final bool eraser;
  final ValueNotifier<double?> cursor;
  final ValueChanged<List<Stroke>> onCommit;
  final VoidCallback onLimit;
  final void Function(int before, int after)? onSimplified;
  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  bool get hasActiveGesture => _pointer != null;
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
      if (_basePointCount >= simplificationPointThreshold) {
        final result = simplifyGeometry(
          widget.document.copyWith(strokes: _baseStrokes),
        );
        if (result.changed) {
          _baseStrokes = result.strokes;
          _basePointCount = result.after;
          widget.onSimplified?.call(result.before, result.after);
        }
      }
      widget.onCommit(_baseStrokes);
    }
    _active = [];
    _erased = null;
    _lastErase = null;
    _preview.value++;
  }

  void _sample(Offset point, Size size, {PointerEvent? input}) {
    final kind = switch (input?.kind) {
      PointerDeviceKind.stylus => InputKind.stylus,
      PointerDeviceKind.invertedStylus => InputKind.invertedStylus,
      PointerDeviceKind.mouse => InputKind.mouse,
      PointerDeviceKind.touch || null => InputKind.touch,
      _ => InputKind.unknown,
    };
    final stylus = kind == InputKind.stylus || kind == InputKind.invertedStylus;
    double? pressure, tilt;
    if (stylus && input != null) {
      final range = input.pressureMax - input.pressureMin;
      if (range.isFinite && range > 0 && input.pressure.isFinite) {
        pressure = ((input.pressure - input.pressureMin) / range).clamp(
          0.0,
          1.0,
        );
      }
      if (input.tilt.isFinite) tilt = input.tilt.clamp(0.0, math.pi / 2);
    }
    final p = InkPoint.input(
      point.dx / size.width,
      point.dy / size.height,
      ms: _clock.elapsedMilliseconds,
      pressure: pressure,
      tilt: tilt,
      kind: kind,
    );
    if (widget.eraser) {
      final last = _lastErase ?? p;
      final aspect = size.width / size.height;
      final distance = math.sqrt(
        math.pow((p.u - last.u) * aspect, 2) + math.pow(p.v - last.v, 2),
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
          aspect: aspect,
        );
      }
      _lastErase = p;
    } else {
      if (_basePointCount + _active.length >= 100000) {
        finish();
        if (_basePointCount >= 100000) widget.onLimit();
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
        label: context
            .strings
            .drawingCanvasHorizontalPositionControlsTimeHeightControlsP,
        child: Listener(
          key: const ValueKey('drawing-canvas'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_pointer != null) return;
            if (!widget.eraser &&
                _basePointCount >= simplificationPointThreshold) {
              final result = simplifyGeometry(
                widget.document.copyWith(strokes: _baseStrokes),
              );
              if (result.changed) {
                _baseStrokes = result.strokes;
                _basePointCount = result.after;
                widget.onCommit(_baseStrokes);
                widget.onSimplified?.call(result.before, result.after);
                _preview.value++;
              }
            }
            _pointer = event.pointer;
            _clock
              ..reset()
              ..start();
            _sample(event.localPosition, size, input: event);
          },
          onPointerMove: (event) {
            if (event.pointer != _pointer) return;
            if (!(Offset.zero & size).contains(event.localPosition)) {
              finish();
              return;
            }
            _sample(event.localPosition, size, input: event);
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
                BackgroundSurface(paper: widget.document.effectiveBackground),
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
                        previewStrokes: [],
                      ),
                    ),
                  ),
                ),
                if (widget.document.strokes.isEmpty)
                  IgnorePointer(
                    child: Center(
                      child: Text(
                        context.strings.leaveALittleMelodyHere,
                        style: TextStyle(color: Color(0xff64746e)),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: CursorPainter(widget.cursor)),
                  ),
                ),
                IgnorePointer(
                  child: RepaintBoundary(
                    child: PlaybackIntersections(
                      document: widget.document,
                      cursor: widget.cursor,
                    ),
                  ),
                ),
                if (widget.eraser)
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: ListenableBuilder(
                        listenable: _preview,
                        builder: (_, _) => CustomPaint(
                          painter: EraserCursorPainter(_lastErase),
                        ),
                      ),
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

String scaleName(BuildContext context, MusicalScale scale) => switch (scale) {
  MusicalScale.major => context.strings.majorPentatonic,
  MusicalScale.minor => context.strings.minorPentatonic,
  MusicalScale.diatonicMajor => context.strings.diatonicMajor,
  MusicalScale.diatonicMinor => context.strings.diatonicMinor,
  MusicalScale.harmonicMinor => context.strings.harmonicMinor,
  MusicalScale.dorian => context.strings.dorian,
  MusicalScale.phrygian => context.strings.phrygian,
  MusicalScale.lydian => context.strings.lydian,
  MusicalScale.mixolydian => context.strings.mixolydian,
  MusicalScale.blues => context.strings.blues,
  MusicalScale.chromatic => context.strings.chromatic,
};
