import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../creative_document/document.dart';

/// One navigation request's actual, bounded preview pixels. Document geometry is
/// already immutable; it is never serialized, reconstructed or changed by flight.
///
/// This object is local route-extra state, not a project/document identifier.
/// Its image is leased until the source, destination and Hero shuttle are gone,
/// including the reverse animation after Navigator.push's future completes.
class ArtworkFlightIntent extends ChangeNotifier with WidgetsBindingObserver {
  ArtworkFlightIntent._(
    this._image,
    this._onReleased, {
    required this.routeId,
    required this.document,
    required this.tag,
  }) {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) _cancelled = true;
  }

  final String routeId;
  final ProjectDocument document;
  final Object tag;
  ui.Image? _image;
  VoidCallback? _onReleased;
  var _leases = 1;
  var _sourceReleased = false;
  var _cancelled = false;

  bool get cancelled => _cancelled;

  /// Finish presentation immediately; actual route/input/audio remain untouched.
  void cancelPresentation() {
    if (_cancelled || _image == null) return;
    _cancelled = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) cancelPresentation();
  }

  bool _retain() {
    if (_image == null) return false;
    _leases++;
    return true;
  }

  void _releaseSource() {
    if (_sourceReleased) return;
    _sourceReleased = true;
    _release();
  }

  void _release() {
    assert(_leases > 0);
    if (--_leases != 0) return;
    _image?.dispose();
    _image = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    final released = _onReleased;
    _onReleased = null;
    released?.call();
  }
}

typedef ArtworkFlightSourceBuilder = Widget Function(
  BuildContext context,
  Widget anchor,
  VoidCallback open,
);

/// Put [anchor] from [builder] exactly around the actual artwork, while [open]
/// may also be used by its existing labeled card/button. Await the navigation
/// future in [onOpen]. Direct entry or a source not painted yet simply opens
/// without a flight; capture never delays navigation or decodes another photo.
class ArtworkFlightSource extends StatefulWidget {
  const ArtworkFlightSource({
    super.key,
    required this.routeId,
    required this.document,
    required this.artwork,
    required this.onOpen,
    this.builder,
  });

  final String routeId;
  final ProjectDocument document;
  final Widget artwork;
  final Future<void> Function(ArtworkFlightIntent? intent) onOpen;
  final ArtworkFlightSourceBuilder? builder;

  @override
  State<ArtworkFlightSource> createState() => _ArtworkFlightSourceState();
}

class _ArtworkFlightSourceState extends State<ArtworkFlightSource> {
  final _tag = Object();
  final _paint = GlobalKey();
  ArtworkFlightIntent? _active;
  var _opening = false;

  ArtworkFlightIntent? _capture() {
    if (MediaQuery.disableAnimationsOf(context)) return null;
    final render = _paint.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary || !render.hasSize) return null;
    final size = render.size;
    if (size.isEmpty) return null;
    try {
      final ratio = math.min(
        MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0),
        640 / math.max(size.width, size.height),
      );
      late final ArtworkFlightIntent intent;
      intent = ArtworkFlightIntent._(
        render.toImageSync(pixelRatio: ratio),
        () {
          if (identical(_active, intent)) _active = null;
        },
        routeId: widget.routeId,
        document: widget.document,
        tag: _tag,
      );
      return intent;
    } catch (_) {
      // For example, a photo/first-layout frame has not painted yet. Preserve
      // immediate drawing access using the route's opaque connected fallback.
      return null;
    }
  }

  @override
  void didUpdateWidget(ArtworkFlightSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId ||
        oldWidget.document.id != widget.document.id ||
        oldWidget.document.revision != widget.document.revision ||
        oldWidget.document.strokes != widget.document.strokes ||
        oldWidget.document.paper != widget.document.paper) {
      _active?.cancelPresentation();
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    // A rapid pop→push can retain the previous Hero shuttle. Keep its ownership
    // separate, cancel its presentation and navigate immediately via fallback.
    final previous = _active;
    final reversing = previous?._image != null;
    if (reversing) previous!.cancelPresentation();
    final intent = reversing ? null : _capture();
    _active = intent;
    setState(() => _opening = true);
    try {
      await widget.onOpen(intent);
    } finally {
      intent?._releaseSource();
      if (mounted) setState(() => _opening = false);
      if (identical(_active, intent) && intent?._image == null) _active = null;
    }
  }

  @override
  void dispose() {
    _active?.cancelPresentation();
    _active?._releaseSource();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = HeroMode(
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: Hero(
        tag: _tag,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        placeholderBuilder: (context, size, child) =>
            SizedBox.fromSize(size: size, child: child),
        child: RepaintBoundary(key: _paint, child: widget.artwork),
      ),
    );
    void open() => unawaited(_open());
    return widget.builder?.call(context, anchor, open) ??
        Semantics(
          button: true,
          label: widget.document.title,
          onTap: open,
          child: ExcludeSemantics(
            child: GestureDetector(onTap: open, child: anchor),
          ),
        );
  }
}

/// The actual canvas stays outside the Hero and remains mounted, laid out and
/// hit-testable throughout forward/reverse flight. The transparent sibling is
/// only an anchor for the original preview pixels; it never owns pointer input.
class ArtworkFlightDestination extends StatefulWidget {
  const ArtworkFlightDestination({
    super.key,
    required this.document,
    required this.child,
    this.intent,
  });

  final ProjectDocument document;
  final Widget child;
  final ArtworkFlightIntent? intent;

  @override
  State<ArtworkFlightDestination> createState() =>
      _ArtworkFlightDestinationState();
}

class _ArtworkFlightDestinationState extends State<ArtworkFlightDestination> {
  ArtworkFlightIntent? _leased;

  @override
  void initState() {
    super.initState();
    _lease(widget.intent);
  }

  void _lease(ArtworkFlightIntent? intent) {
    _leased = intent?._retain() == true ? intent : null;
  }

  @override
  void didUpdateWidget(ArtworkFlightDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.intent, widget.intent)) {
      _leased?._release();
      _lease(widget.intent);
    } else if (oldWidget.document.revision != widget.document.revision ||
        oldWidget.document.strokes != widget.document.strokes ||
        oldWidget.document.paper != widget.document.paper) {
      // Never fly stale source pixels back over newly edited work.
      _leased?.cancelPresentation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _leased?.cancelPresentation();
    }
  }

  @override
  void dispose() {
    _leased?._release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intent = _leased;
    return Listener(
      onPointerDown: (_) => intent?.cancelPresentation(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (intent != null)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: HeroMode(
                    enabled: !MediaQuery.disableAnimationsOf(context),
                    child: Hero(
                      tag: intent.tag,
                      createRectTween: (begin, end) =>
                          MaterialRectArcTween(begin: begin, end: end),
                      placeholderBuilder: (context, size, child) =>
                          const SizedBox.expand(),
                      flightShuttleBuilder: (
                        context,
                        animation,
                        direction,
                        from,
                        to,
                      ) => _ArtworkShuttle(intent: intent),
                      // Always transparent when settled: this is not the live
                      // drawing, which is the permanently mounted sibling.
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtworkShuttle extends StatefulWidget {
  const _ArtworkShuttle({required this.intent});
  final ArtworkFlightIntent intent;
  @override
  State<_ArtworkShuttle> createState() => _ArtworkShuttleState();
}

class _ArtworkShuttleState extends State<_ArtworkShuttle> {
  late final bool _retained = widget.intent._retain();

  @override
  void dispose() {
    if (_retained) widget.intent._release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.intent,
        builder: (context, _) => Opacity(
          key: const ValueKey('artwork-flight-shuttle'),
          opacity: widget.intent.cancelled || !_retained ? 0 : 1,
          child: RepaintBoundary(
            child: RawImage(
              image: _retained ? widget.intent._image : null,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    ),
  );
}
