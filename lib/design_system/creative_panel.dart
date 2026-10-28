import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'motion.dart';
import 'layout.dart';
import 'doodimo_icon.dart';
import 'immersive_surface.dart';

/// The caller's state and job ownership remain outside the transition builder.
Future<T?> showCreativePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  if (MediaQuery.sizeOf(context).width >= 720) {
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: isDismissible,
      animationStyle: AnimationStyle(
        duration: CreativeMotion.duration(context, CreativeMotion.sheet),
        reverseDuration: CreativeMotion.duration(
          context,
          CreativeMotion.reverse,
        ),
      ),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
          child: ImmersiveSurface(
            padding: EdgeInsets.zero,
            glow: true,
            child: builder(context),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: AnimationStyle(
      duration: CreativeMotion.duration(context, CreativeMotion.sheet),
      reverseDuration: CreativeMotion.duration(context, CreativeMotion.reverse),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: ImmersiveSurface(
          padding: EdgeInsets.zero,
          glow: true,
          child: builder(context),
        ),
      ),
    ),
  );
}

class CreativePanel extends StatelessWidget {
  const CreativePanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scrollable = true,
    this.canClose = true,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool scrollable;
  final bool canClose;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final compact = scrollable && bounds.maxHeight < 360;
        final close = IconButton(
          tooltip: context.strings.close,
          onPressed: canClose
              ? onClose ?? () => Navigator.of(context).maybePop()
              : null,
          icon: const DoodimoIcon(DoodimoGlyph.close),
        );
        final heading = Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              close,
            ],
          ),
        );
        final content = Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(subtitle!),
                ),
              child,
            ],
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: close,
                ),
              )
            else
              heading,
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(
                      child: compact
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    12,
                                  ),
                                  child: Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                content,
                              ],
                            )
                          : content,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (subtitle != null)
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              child: Text(subtitle!),
                            ),
                          ),
                        Flexible(child: child),
                      ],
                    ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                    : const EdgeInsets.all(CreativeSpace.lg),
                child: OverflowBar(
                  spacing: 12,
                  overflowSpacing: 8,
                  children: actions,
                ),
              )
            else
              SizedBox(height: compact ? 8 : 24),
          ],
        );
      },
    ),
  );
}
