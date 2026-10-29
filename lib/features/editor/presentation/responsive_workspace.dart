import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Controls never animate layout. The live canvas retains its GlobalKey while
/// phone, landscape and tablet chrome adapt around it. History has its own
/// viewport so opening a scrolled tool panel never scrolls Undo out of reach.
class ResponsiveEditorLayout extends StatelessWidget {
  const ResponsiveEditorLayout({
    super.key,
    required this.toolbar,
    required this.summary,
    required this.transport,
    required this.canvas,
    required this.alerts,
    this.toolbarNaturalHeight = 0,
    this.transportFirstRowHeightForWidth,
  });
  final Widget toolbar, summary, transport, canvas, alerts;
  final double toolbarNaturalHeight;
  final double Function(double availableWidth)? transportFirstRowHeightForWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rail =
          constraints.maxWidth >= 900 ||
          (constraints.maxWidth >= 520 && constraints.maxHeight < 440);
      if (rail) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: constraints.maxHeight < 440 ? 330 : 304,
              child: constraints.maxHeight < 200
                  ? SingleChildScrollView(
                      key: const ValueKey('editor-tools-scroll'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [toolbar, summary, transport, alerts],
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: math.max(
                            constraints.maxHeight >= 440
                                ? math.min(230, constraints.maxHeight * .38)
                                : math.min(118, constraints.maxHeight * .32),
                            transportFirstRowHeightForWidth?.call(
                                  constraints.maxHeight < 440 ? 330 : 304,
                                ) ??
                                0.0,
                          ),
                          child: SingleChildScrollView(
                            key: const ValueKey('editor-transport-scroll'),
                            child: transport,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            key: const ValueKey('editor-tools-scroll'),
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [toolbar, summary, alerts],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 24),
            Expanded(child: canvas),
          ],
        );
      }
      final budget = math.max(0.0, constraints.maxHeight - 94);
      final large = MediaQuery.textScalerOf(context).scale(14) > 21;
      final toolbarLimit = math.max(
        budget * .24,
        math.min(toolbarNaturalHeight, budget * .48),
      );
      final consoleLimit = math.max(
        0.0,
        budget * .58 - (toolbarLimit - budget * .24),
      );
      final transportHeight = math.max(
        large ? consoleLimit : math.min(118.0, constraints.maxHeight * .24),
        transportFirstRowHeightForWidth?.call(constraints.maxWidth) ?? 0.0,
      );
      // A 4:5 paper with 72dp minimum width needs 90dp height, plus the
      // existing 8dp frame on each edge. Rebalance only real layout space;
      // playback state cannot change these reservations.
      const minimumCanvasWorkspaceHeight = 106.0;
      final gaps = large ? 22.0 : 20.0;
      if (constraints.maxHeight <
          transportHeight + minimumCanvasWorkspaceHeight + gaps + 48) {
        return SingleChildScrollView(
          key: const ValueKey('editor-short-workspace-scroll'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              alerts,
              SizedBox(height: minimumCanvasWorkspaceHeight, child: canvas),
              const SizedBox(height: 12),
              transport,
              const SizedBox(height: 8),
              toolbar,
              summary,
            ],
          ),
        );
      }
      final paletteHeight = math.min(
        large ? toolbarLimit : math.min(220.0, constraints.maxHeight * .31),
        math.max(
          48.0,
          constraints.maxHeight -
              transportHeight -
              gaps -
              minimumCanvasWorkspaceHeight,
        ),
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
          if (large) ...[
            SizedBox(
              height: paletteHeight,
              child: SingleChildScrollView(
                key: const ValueKey('editor-tools-scroll'),
                child: toolbar,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(child: canvas),
          const SizedBox(height: 12),
          SizedBox(
            height: transportHeight,
            child: SingleChildScrollView(
              key: const ValueKey('editor-transport-scroll'),
              child: transport,
            ),
          ),
          if (!large) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: paletteHeight,
              child: SingleChildScrollView(
                key: const ValueKey('editor-tools-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [toolbar, summary],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}
