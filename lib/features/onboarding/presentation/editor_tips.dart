import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';

import '../../../design_system/motion.dart';

class EditorTip {
  const EditorTip(this.title, this.description, this.target);
  final String title, description;
  final GlobalKey target;
}

// Original guidance, positioned against actual controls. The modal barrier
// absorbs all input outside the card, including the highlighted control.
Future<bool?> showEditorTips(BuildContext context, List<EditorTip> tips) async {
  if (tips.isEmpty) return false;
  final previousFocus = FocusManager.instance.primaryFocus;
  try {
    return await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: context.strings.editorTips,
      barrierColor: Colors.transparent,
      transitionDuration: CreativeMotion.duration(
        context,
        CreativeMotion.selection,
      ),
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: CreativeMotion.curve,
            ),
            child: child,
          ),
      pageBuilder: (_, _, _) => _TipOverlay(tips: tips),
    );
  } finally {
    if (previousFocus?.context?.mounted == true) previousFocus!.requestFocus();
  }
}

class _TipOverlay extends StatefulWidget {
  const _TipOverlay({required this.tips});
  final List<EditorTip> tips;
  @override
  State<_TipOverlay> createState() => _TipOverlayState();
}

class _TipOverlayState extends State<_TipOverlay> with WidgetsBindingObserver {
  int _index = 0;
  bool _moving = false, _refreshPending = false;
  Rect? _rect;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRect();
  }

  @override
  void didChangeMetrics() => _scheduleRect();
  Rect? _targetRect(GlobalKey key) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    return object.localToGlobal(Offset.zero) & object.size;
  }

  void _scheduleRect() {
    if (_refreshPending) return;
    _refreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPending = false;
      if (!mounted) return;
      final next = _targetRect(widget.tips[_index].target);
      if (next != _rect) setState(() => _rect = next);
    });
  }

  Future<void> _next() async {
    if (_moving) return;
    if (_index == widget.tips.length - 1) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _moving = true);
    final target = widget.tips[_index + 1].target.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: CreativeMotion.duration(context, CreativeMotion.selection),
        curve: CreativeMotion.curve,
      );
    }
    if (!mounted) return;
    setState(() {
      _index++;
      _moving = false;
    });
    _scheduleRect();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final bottom = _rect == null || _rect!.center.dy < size.height / 2;
    final available =
        (size.height - media.padding.vertical - media.viewInsets.bottom - 32)
            .clamp(80, double.infinity)
            .toDouble();
    final landscape = size.width > size.height;
    final colors = Theme.of(context).colorScheme;
    _scheduleRect();
    Widget skip() => TextButton(
      onPressed: () => Navigator.pop(context, true),
      child: Text(context.strings.skipTips, textAlign: TextAlign.center),
    );
    Widget next() => FilledButton(
      onPressed: _moving ? null : _next,
      child: Text(
        _index == widget.tips.length - 1
            ? context.strings.done
            : context.strings.nextTip,
        textAlign: TextAlign.center,
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('editor-tip-spotlight'),
                painter: _Spotlight(_rect),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + media.viewInsets.bottom,
              ),
              child: AnimatedAlign(
                duration: CreativeMotion.duration(
                  context,
                  CreativeMotion.selection,
                ),
                curve: CreativeMotion.curve,
                alignment: bottom
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: landscape ? available : available * .58,
                  ),
                  child: FocusTraversalGroup(
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: colors.primary, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: SingleChildScrollView(
                                child: Semantics(
                                  liveRegion: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.strings.tipCounter(
                                          context.formatNumber(_index + 1),
                                          context.formatNumber(
                                            widget.tips.length,
                                          ),
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(color: colors.primary),
                                      ),
                                      const SizedBox(height: 10),
                                      ExcludeSemantics(
                                        child: Wrap(
                                          spacing: 5,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < widget.tips.length;
                                              i++
                                            )
                                              AnimatedContainer(
                                                duration:
                                                    CreativeMotion.duration(
                                                      context,
                                                      CreativeMotion.selection,
                                                    ),
                                                curve: CreativeMotion.curve,
                                                width: i == _index ? 22 : 6,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: i == _index
                                                      ? colors.primary
                                                      : colors.outlineVariant,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          widget.tips[_index].title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        widget.tips[_index].description,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) =>
                                  constraints.maxWidth < 340 ||
                                      media.textScaler.scale(14) > 22
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        skip(),
                                        const SizedBox(height: 6),
                                        next(),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Flexible(child: skip()),
                                        const SizedBox(width: 12),
                                        Flexible(child: next()),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _Spotlight extends CustomPainter {
  _Spotlight(this.rect);
  final Rect? rect;
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final target = rect;
    if (target != null) {
      final clipped = target.inflate(5).intersect(Offset.zero & size);
      if (!clipped.isEmpty) {
        final hole = Path()
          ..addRRect(
            RRect.fromRectAndRadius(clipped, const Radius.circular(12)),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, full, hole),
          Paint()..color = const Color(0xb322302c),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(clipped, const Radius.circular(12)),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        return;
      }
    }
    canvas.drawPath(full, Paint()..color = const Color(0xb322302c));
  }

  @override
  bool shouldRepaint(_Spotlight old) => old.rect != rect;
}
