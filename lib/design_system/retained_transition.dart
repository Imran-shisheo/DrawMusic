import 'package:flutter/material.dart';

import 'motion.dart';

/// Retain navigator/controller ownership while compositing a continuous blend.
/// A retarget starts from the currently painted weights, never transparency.
class RetainedBranchContainer extends StatefulWidget {
  const RetainedBranchContainer({
    super.key,
    required this.index,
    required this.children,
    this.opaquePages = true,
  });

  final int index;
  final List<Widget> children;

  /// Full-page scaffolds preserve opaque coverage; fragments over shared chrome
  /// fade their own ink without covering the persistent parent backdrop.
  final bool opaquePages;

  @override
  State<RetainedBranchContainer> createState() =>
      _RetainedBranchContainerState();
}

class _RetainedBranchContainerState extends State<RetainedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: CreativeMotion.branch,
    value: 1,
  );
  late List<double> _start = _target();

  List<double> _target() => [
    for (var i = 0; i < widget.children.length; i++) i == widget.index ? 1 : 0,
  ];

  List<double> _weights() {
    final t = CreativeMotion.curve.transform(_blend.value);
    return [
      for (var i = 0; i < widget.children.length; i++)
        _start[i] * (1 - t) + (i == widget.index ? t : 0),
    ];
  }

  @override
  void didUpdateWidget(RetainedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(oldWidget.children.length == widget.children.length);
    if (oldWidget.index == widget.index) return;
    // Sample against the OLD target before changing the interpolation endpoint.
    final t = CreativeMotion.curve.transform(_blend.value);
    _start = [
      for (var i = 0; i < widget.children.length; i++)
        _start[i] * (1 - t) + (i == oldWidget.index ? t : 0),
    ];
    if (MediaQuery.disableAnimationsOf(context)) {
      _blend.value = 1;
    } else {
      _blend.forward(from: 0);
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
    // The controller only rebuilds compositing wrappers, not live page trees.
    builder: (context, _) {
      final weights = _weights();
      var cumulative = 0.0;
      final opacities = <double>[];
      for (final weight in weights) {
        cumulative += weight;
        // Conditional source-over alpha keeps the painted blend opaque.
        opacities.add(
          widget.opaquePages
              ? (cumulative == 0 ? 0 : (weight / cumulative).clamp(0, 1))
              : weight,
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Offstage(
              offstage: weights[i] == 0 && i != widget.index,
              child: IgnorePointer(
                ignoring: i != widget.index,
                child: ExcludeSemantics(
                  excluding: i != widget.index,
                  child: ExcludeFocus(
                    excluding: i != widget.index,
                    child: TickerMode(
                      enabled: i == widget.index,
                      child: HeroMode(
                        enabled: i == widget.index,
                        child: Opacity(
                          opacity: opacities[i],
                          alwaysIncludeSemantics: i == widget.index,
                          child: RepaintBoundary(child: widget.children[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
