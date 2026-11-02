import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../creative_document/document.dart' show newId;
import '../design_system/artwork_flight.dart';
import '../l10n/strings.dart';
import 'providers.dart';

enum _OpeningOutcome { ready, failed, cancelled }

// Only a pending source-read owns this cancellation slot. Once a real route is
// pushed, its provider lifetime and flight are owned by that route/source pair.
final _pendingArtworkOpenings = Expando<VoidCallback>('pending-artwork-open');
final _activeEditorPushes = Expando<Object>('active-editor-push');

/// Load the real destination before requesting its artwork flight, so its Hero
/// and permanently anchored live canvas exist on the first destination frame.
/// This waits for actual I/O only; no animation/readiness delay is manufactured.
Future<void> openEditorWithArtworkFlight(
  BuildContext context,
  String routeId,
  ArtworkFlightIntent? intent, {
  bool replayTips = false,
}) async {
  if (!context.mounted) return;
  final router = GoRouter.of(context);
  if (_activeEditorPushes[router] != null) return;
  _pendingArtworkOpenings[router]?.call();
  _pendingArtworkOpenings[router] = null;
  final request = EditorLoadRequest(projectId: routeId, sessionId: newId());
  final location = Uri(
    pathSegments: ['', 'editor', routeId],
    queryParameters: {
      'session': request.sessionId,
      if (replayTips) 'tips': '1',
    },
  ).toString();
  Future<void> push(ArtworkFlightIntent? flight) async {
    if (_activeEditorPushes[router] != null) return;
    final owner = Object();
    _activeEditorPushes[router] = owner;
    try {
      await router.push<void>(location, extra: flight);
    } finally {
      if (identical(_activeEditorPushes[router], owner)) {
        _activeEditorPushes[router] = null;
      }
    }
  }

  if (intent == null) {
    await push(null);
    return;
  }
  if (intent.cancelled) return;

  final container = ProviderScope.containerOf(context, listen: false);
  final provider = editorLoadProvider(request);
  // Keep this precise provider alive while preloading AND until the pushed
  // route completes. In particular, a template must not be recreated with a
  // different ID between readiness and EditorPage's first watch.
  final subscription = container.listen(provider, (previous, next) {});
  final startUri = router.routeInformationProvider.value.uri;
  final startConfiguration = router.routerDelegate.currentConfiguration;
  final cancelled = Completer<_OpeningOutcome>();
  Timer? feedbackTimer;
  OverlayEntry? feedback;
  var listening = false;

  void removeFeedback() {
    feedbackTimer?.cancel();
    feedbackTimer = null;
    feedback?.remove();
    feedback?.dispose();
    feedback = null;
  }

  void cancel() {
    removeFeedback();
    if (cancelled.isCompleted) return;
    cancelled.complete(_OpeningOutcome.cancelled);
    intent.cancelPresentation();
  }

  final VoidCallback cancelPending = cancel;

  void intentChanged() {
    if (intent.cancelled) cancel();
  }

  void navigationChanged() {
    if (router.routeInformationProvider.value.uri != startUri ||
        !identical(
          router.routerDelegate.currentConfiguration,
          startConfiguration,
        )) {
      cancel();
    }
  }

  final lifecycle = _OpeningLifecycle(cancel);
  void stopListening() {
    if (listening) {
      listening = false;
      intent.removeListener(intentChanged);
      router.routeInformationProvider.removeListener(navigationChanged);
      router.routerDelegate.removeListener(navigationChanged);
      WidgetsBinding.instance.removeObserver(lifecycle);
    }
    if (identical(_pendingArtworkOpenings[router], cancelPending)) {
      _pendingArtworkOpenings[router] = null;
    }
    removeFeedback();
  }

  try {
    _pendingArtworkOpenings[router] = cancelPending;
    intent.addListener(intentChanged);
    router.routeInformationProvider.addListener(navigationChanged);
    router.routerDelegate.addListener(navigationChanged);
    WidgetsBinding.instance.addObserver(lifecycle);
    listening = true;
    final state = WidgetsBinding.instance.lifecycleState;
    if (intent.cancelled ||
        (state != null && state != AppLifecycleState.resumed)) {
      cancel();
    }
    feedbackTimer = Timer(const Duration(milliseconds: 150), () {
      if (cancelled.isCompleted || !context.mounted || intent.cancelled) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      final label = context.strings.openingDrawing;
      final top = MediaQuery.viewPaddingOf(context).top + 12;
      feedback = OverlayEntry(
        builder: (context) => Positioned(
          top: top,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Semantics(
                  key: const ValueKey('opening-drawing-feedback'),
                  liveRegion: true,
                  child: Material(
                    elevation: 6,
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(label)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(feedback!);
    });
    // Convert errors to an outcome immediately so cancelled late I/O errors are
    // observed too. AsyncError stays in the held provider for the real error UI.
    final readiness = container
        .read(provider.future)
        .then<_OpeningOutcome>(
          (_) => _OpeningOutcome.ready,
          onError: (Object error, StackTrace stack) => _OpeningOutcome.failed,
        );
    final outcome = await Future.any([readiness, cancelled.future]);
    if (outcome == _OpeningOutcome.cancelled ||
        !context.mounted ||
        intent.cancelled) {
      return;
    }
    // Own URI changes and pointer cancellation during editing must not be
    // mistaken for cancellation of this now-completed readiness operation.
    stopListening();
    if (outcome == _OpeningOutcome.failed) intent.cancelPresentation();
    await push(outcome == _OpeningOutcome.ready ? intent : null);
  } finally {
    stopListening();
    subscription.close();
  }
}

class _OpeningLifecycle extends WidgetsBindingObserver {
  _OpeningLifecycle(this.cancel);
  final VoidCallback cancel;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) cancel();
  }
}
