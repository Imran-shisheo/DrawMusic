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
  Rect? sourceBounds,
}) async {
  // Only a still-mounted caller regains focus. Nested sheets keep their own
  // focus scope and native pickers are never impersonated by this transition.
  final previousFocus = FocusManager.instance.primaryFocus;
  final callerRoute = ModalRoute.of(context);
  T? result;
  try {
    if (MediaQuery.sizeOf(context).width >= 720) {
      result = await showDialog<T>(
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
            child: _ConnectedPanel(
              sourceBounds: sourceBounds,
              child: ImmersiveSurface(
                padding: EdgeInsets.zero,
                child: builder(context),
              ),
            ),
          ),
        ),
      );
    } else {
      result = await showModalBottomSheet<T>(
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
          reverseDuration: CreativeMotion.duration(
            context,
            CreativeMotion.reverse,
          ),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .92,
            ),
            child: _ConnectedPanel(
              sourceBounds: sourceBounds,
              bottom: true,
              child: ImmersiveSurface(
                padding: EdgeInsets.zero,
                child: builder(context),
              ),
            ),
          ),
        ),
      );
    }
    return result;
  } finally {
    if (context.mounted &&
        (callerRoute == null || callerRoute.isCurrent) &&
        previousFocus?.context?.mounted == true &&
        previousFocus!.canRequestFocus) {
      previousFocus.requestFocus();
    }
  }
}

/// A finite presentation layer. Route/job/controller ownership remains with
/// Flutter's Dialog/BottomSheet and the caller. The live child is built once;
/// only an isolated transform/clip is rebuilt by the route animation.
class _ConnectedPanel extends StatefulWidget {
  const _ConnectedPanel({
    required this.child,
    this.sourceBounds,
    this.bottom = false,
  });
  final Widget child;
  final Rect? sourceBounds;
  final bool bottom;
  @override
  State<_ConnectedPanel> createState() => _ConnectedPanelState();
}

class _ConnectedPanelState extends State<_ConnectedPanel> {
  bool _interacted = false;
  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final bounds = widget.sourceBounds;
    final size = MediaQuery.sizeOf(context);
    final alignment = bounds != null && bounds.isFinite && !bounds.isEmpty
        ? Alignment(
            (bounds.center.dx / size.width * 2 - 1).clamp(-1, 1),
            (bounds.center.dy / size.height * 2 - 1).clamp(-1, 1),
          )
        : widget.bottom
        ? Alignment.bottomCenter
        : Alignment.center;
    final child = RepaintBoundary(child: widget.child);
    if (animation == null) return child;
    return Listener(
      onPointerDown: (_) {
        if (!_interacted) setState(() => _interacted = true);
      },
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = reduced || _interacted
              ? 1.0
              : CreativeMotion.curve.transform(animation.value);
          return Transform.scale(
            key: const ValueKey('creative-connected-panel'),
            scale: .975 + .025 * t,
            alignment: alignment,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18 + 6 * t),
              child: child,
            ),
          );
        },
      ),
    );
  }
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
        final close = IconButton.outlined(
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
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                      : const EdgeInsets.all(CreativeSpace.lg),
                  child: OverflowBar(
                    spacing: 12,
                    overflowSpacing: 8,
                    children: actions,
                  ),
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
