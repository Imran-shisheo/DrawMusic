import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'motion.dart';

/// A bounded blend of explicitly named states. Only the current child owns
/// layout and interaction; outgoing states remain mounted until their fade ends.
class ContinuitySwitcher extends StatefulWidget {
  const ContinuitySwitcher({
    super.key,
    required this.child,
    required this.stateKeys,
    this.duration = CreativeMotion.selection,
  });
  final Widget child;
  final List<LocalKey> stateKeys;
  final Duration duration;
  @override
  State<ContinuitySwitcher> createState() => _ContinuitySwitcherState();
}

class _ContinuitySwitcherState extends State<ContinuitySwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final List<Widget?> _children = List.filled(
    widget.stateKeys.length,
    null,
  );
  late List<double> _start = List.filled(widget.stateKeys.length, 0);
  late int _selected = _index();
  int _index() {
    assert(
      widget.stateKeys.isNotEmpty &&
          widget.stateKeys.toSet().length == widget.stateKeys.length,
    );
    final index = widget.stateKeys.indexOf(widget.child.key as LocalKey);
    assert(index >= 0, 'The child must have a key listed in stateKeys.');
    return index;
  }

  List<double> _weights() {
    final t = CreativeMotion.curve.transform(_blend.value);
    return [
      for (var i = 0; i < _children.length; i++)
        _start[i] * (1 - t) + (i == _selected ? t : 0),
    ];
  }

  @override
  void initState() {
    super.initState();
    _children[_selected] = widget.child;
  }

  @override
  void didUpdateWidget(ContinuitySwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      listEquals(oldWidget.stateKeys, widget.stateKeys),
      'stateKeys must remain stable.',
    );
    _blend.duration = widget.duration;
    final next = _index();
    if (next != _selected) {
      _start = _weights();
      _selected = next;
      _children[next] = widget.child;
      if (MediaQuery.disableAnimationsOf(context)) {
        _blend.value = 1;
      } else {
        _blend.forward(from: 0);
      }
    } else {
      _children[next] = widget.child;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _blend.value = 1;
  }

  @override
  void dispose() {
    _blend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _blend,
    builder: (context, _) {
      final weights = _weights();
      final slots = <Widget>[];
      for (var i = 0; i < _children.length; i++) {
        // These are transparent content fragments over an existing surface,
        // not opaque pages: each old mark must fade even where the new child
        // has no paint. Conditional page-compositing alpha would keep it solid.
        final opacity = weights[i].clamp(0.0, 1.0);
        if (weights[i] == 0 && i != _selected) _children[i] = null;
        slots.add(
          IgnorePointer(
            ignoring: i != _selected,
            child: ExcludeSemantics(
              excluding: i != _selected,
              child: ExcludeFocus(
                excluding: i != _selected,
                child: TickerMode(
                  enabled: i == _selected,
                  child: Opacity(
                    opacity: opacity,
                    alwaysIncludeSemantics: i == _selected,
                    child: _children[i] ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return _CurrentSizeLayout(
        current: _selected,
        progress: CreativeMotion.curve.transform(_blend.value),
        children: slots,
      );
    },
  );
}

class _CurrentSizeLayout extends MultiChildRenderObjectWidget {
  const _CurrentSizeLayout({
    required this.current,
    required this.progress,
    required super.children,
  });
  final int current;
  final double progress;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCurrentSize(current, progress);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCurrentSize renderObject,
  ) {
    renderObject.current = current;
    renderObject.progress = progress;
  }
}

class _SlotParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCurrentSize extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderCurrentSize(this._current, this._progress);
  int _current;
  double _progress;
  Size? _fromSize;
  set progress(double value) {
    if (value != _progress) {
      _progress = value;
      markNeedsLayout();
    }
  }

  set current(int value) {
    if (value != _current) {
      _fromSize = hasSize ? size : null;
      _current = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SlotParentData) {
      child.parentData = _SlotParentData();
    }
  }

  RenderBox get selected {
    var child = firstChild!;
    for (var i = 0; i < _current; i++) {
      child = childAfter(child)!;
    }
    return child;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size.lerp(
      _fromSize ?? selected.getDryLayout(constraints),
      selected.getDryLayout(constraints),
      _progress,
    )!,
  );
  @override
  void performLayout() {
    final active = selected;
    active.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size.lerp(_fromSize ?? active.size, active.size, _progress)!,
    );
    if (_progress == 1) _fromSize = null;
    var child = firstChild;
    while (child != null) {
      if (child != active) {
        child.layout(
          BoxConstraints(
            minWidth: active.size.width,
            maxWidth: active.size.width,
          ),
          parentUsesSize: false,
        );
      }
      (child.parentData! as ContainerBoxParentData<RenderBox>).offset =
          Offset.zero;
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Restrict transient paint to the moving layout edge, but preserve normal
    // settled shadows/ink overflow exactly as a plain content child does.
    if (_progress == 1) {
      defaultPaint(context, offset);
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _progress == 1 ? null : Offset.zero & size;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
