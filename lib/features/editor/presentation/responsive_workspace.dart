import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Controls never animate their layout. The live canvas retains its GlobalKey
/// while phone, landscape and tablet chrome adapt around it.
class ResponsiveEditorLayout extends StatelessWidget {
  const ResponsiveEditorLayout({
    super.key,
    required this.toolbar,
    required this.summary,
    required this.transport,
    required this.canvas,
    required this.alerts,
    this.toolbarNaturalHeight = 0,
  });
  final Widget toolbar, summary, transport, canvas, alerts;
  final double toolbarNaturalHeight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rail =
          constraints.maxWidth >= 900 ||
          (constraints.maxWidth >= 520 && constraints.maxHeight < 440);
      if (rail) {
        final short = constraints.maxHeight < 440;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: short ? 330 : 304,
              child: SingleChildScrollView(
                key: const ValueKey('editor-tools-scroll'),
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (short) ...[transport, const SizedBox(height: 8)],
                    toolbar,
                    const SizedBox(height: 8),
                    summary,
                    const SizedBox(height: 12),
                    if (!short) transport,
                    alerts,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(child: canvas),
          ],
        );
      }
      // Reserve a real drawable surface even when alerts and 200% labels are
      // unusually long. Only the single joined console scrolls; full voice and
      // musical values are never truncated to make room for controls.
      final budget = (constraints.maxHeight - 72 - 22).clamp(
        0.0,
        double.infinity,
      );
      final large = MediaQuery.textScalerOf(context).scale(14) > 21;
      // A translated word may require full-width Draw/Erase rows. Give the
      // complete measured palette height a bounded share of the existing
      // control budget; take that share from the scrollable console, never the
      // reserved drawable surface or alert budget.
      final toolbarLimit = math.max(
        budget * .24,
        math.min(toolbarNaturalHeight, budget * .48),
      );
      final consoleLimit = math.max(
        0.0,
        budget * .58 - (toolbarLimit - budget * .24),
      );
      return Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: budget * .18),
            child: SingleChildScrollView(
              key: const ValueKey('editor-alerts-scroll'),
              child: alerts,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: toolbarLimit),
            child: SingleChildScrollView(
              key: const ValueKey('editor-tools-scroll'),
              child: toolbar,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: canvas),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: consoleLimit),
            child: SingleChildScrollView(
              key: const ValueKey('editor-transport-scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (large) ...[
                    transport,
                    const SizedBox(height: 6),
                    summary,
                  ] else ...[
                    summary,
                    const SizedBox(height: 6),
                    transport,
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
