import 'package:flutter/material.dart';

import '../../../design_system/motion.dart';

/// A tactile studio face: paint-only press/focus feedback never moves its target
/// or changes document layout. Native ink, keyboard activation and semantics are
/// retained beneath the original surface treatment.
class StudioControl extends StatefulWidget {
  const StudioControl({
    super.key,
    required this.label,
    required this.child,
    required this.onPressed,
    required this.fill,
    required this.foreground,
    this.selected,
    this.interactionKey,
    this.radius = 18,
    this.padding = const EdgeInsets.all(12),
    this.raised = false,
  });
  final String label;
  final Key? interactionKey;
  final Widget child;
  final VoidCallback? onPressed;
  final Color fill, foreground;
  final bool? selected;
  final bool raised;
  final double radius;
  final EdgeInsetsGeometry padding;
  @override
  State<StudioControl> createState() => _StudioControlState();
}

class _StudioControlState extends State<StudioControl> {
  bool _pressed = false, _focused = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.label,
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: widget.label,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: CreativeMotion.duration(context, CreativeMotion.press),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: _focused ? widget.foreground : Colors.transparent,
              width: 2,
            ),
            boxShadow: widget.raised
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow
                          .withValues(alpha: .16),
                      offset: Offset(0, _pressed ? 1 : 4),
                      blurRadius: _pressed ? 1 : 6,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: widget.fill,
            borderRadius: BorderRadius.circular(widget.radius - 2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: widget.interactionKey,
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(widget.radius - 2),
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onFocusChange: (value) => setState(() => _focused = value),
              splashColor: widget.foreground.withValues(alpha: .12),
              highlightColor: widget.foreground.withValues(alpha: .08),
              child: Padding(
                padding: widget.padding,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: widget.foreground),
                  child: IconTheme.merge(
                    data: IconThemeData(color: widget.foreground),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
