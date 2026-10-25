import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';

class EditorTip {
  const EditorTip(this.title, this.description, this.target);
  final String title, description;
  final GlobalKey target;
}

// Original guidance, positioned against actual controls. The modal barrier
// absorbs all input outside the card, including the highlighted control.
Future<bool?> showEditorTips(BuildContext context, List<EditorTip> tips) =>
    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: context.strings.editorTips,
      barrierColor: Colors.transparent,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => _TipOverlay(tips: tips),
    );

class _TipOverlay extends StatefulWidget {
  const _TipOverlay({required this.tips});
  final List<EditorTip> tips;
  @override
  State<_TipOverlay> createState() => _TipOverlayState();
}

class _TipOverlayState extends State<_TipOverlay> {
  int _index = 0;
  bool _moving = false;
  Rect? _targetRect(GlobalKey key) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    return object.localToGlobal(Offset.zero) & object.size;
  }

  Future<void> _next() async {
    if (_moving) return;
    if (_index == widget.tips.length - 1) {
      Navigator.pop(context, true);
      return;
    }
    _moving = true;
    final target = widget.tips[_index + 1].target.currentContext;
    if (target != null) await Scrollable.ensureVisible(target);
    if (!mounted) return;
    setState(() {
      _index++;
      _moving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rect = _targetRect(widget.tips[_index].target);
    final bottom = rect == null || rect.center.dy < size.height / 2;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _Spotlight(rect))),
          ),
          SafeArea(
            child: Align(
              alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: size.height * .48,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              child: Semantics(
                                liveRegion: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          .labelLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        widget.tips[_index].title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(widget.tips[_index].description),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(context.strings.skipTips),
                              ),
                              FilledButton(
                                onPressed: _moving ? null : _next,
                                child: Text(
                                  _index == widget.tips.length - 1
                                      ? context.strings.done
                                      : context.strings.nextTip,
                                ),
                              ),
                            ],
                          ),
                        ],
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
