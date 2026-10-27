import 'package:flutter/material.dart';

/// A wide workspace keeps both control groups beside the full-aspect drawing.
/// Phone layouts retain their independently scrolling tool/transport regions.
class ResponsiveEditorLayout extends StatelessWidget {
  const ResponsiveEditorLayout({
    super.key,
    required this.children,
    required this.width,
  });
  final List<Widget> children;
  final double width;
  @override
  Widget build(BuildContext context) {
    if (width < 900) return Column(children: children);
    final tools = children.first as ConstrainedBox;
    final transport = children.last as ConstrainedBox;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Expanded(child: tools.child!),
              const SizedBox(height: 16),
              Expanded(child: transport.child!),
            ],
          ),
        ),
        const SizedBox(width: 16),
        children[2],
      ],
    );
  }
}
