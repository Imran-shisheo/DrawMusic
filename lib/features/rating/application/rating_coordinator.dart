import '../domain/rating_state.dart';

enum RatingOutcome {
  notEligible,
  unavailable,
  busy,
  dismissed,
  requested,
  storageUnavailable,
  failed,
}

/// Called only after an explicitly successful user Save/export. Autosave,
/// failures, canceled jobs and playback are never eligible task events.
class RatingCoordinator {
  RatingCoordinator(this.store, this.platform, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final RatingStore store;
  final RatingPlatform platform;
  final DateTime Function() _clock;
  Future<void> _queue = Future.value();
  var _offering = false;
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> recordSuccessfulTask() => _serialize(() async {
    try {
      final state = await store.load();
      final next = state.successfulTask();
      if (next.successfulTasks != state.successfulTasks) await store.save(next);
      return true;
    } catch (_) {
      // An optional review never turns a successful creative task into failure.
      return false;
    }
  });

  /// The caller's safety predicate must verify mounted/current route, no active
  /// pointer, paused transport, no export, no saving and no other modal. It is
  /// rechecked after asynchronous boundaries, including before native launch.
  Future<RatingOutcome> offerIfEligible({
    required bool Function() isSafe,
    required Future<bool> Function() confirm,
  }) {
    if (_offering) return Future.value(RatingOutcome.busy);
    _offering = true;
    return _serialize(() async {
      try {
        if (!_safe(isSafe)) return RatingOutcome.busy;
        late RatingState state;
        try {
          state = await store.load();
        } catch (_) {
          return RatingOutcome.storageUnavailable;
        }
        if (!state.eligible(_clock())) return RatingOutcome.notEligible;
        try {
          if (!await platform.isAvailable()) return RatingOutcome.unavailable;
        } catch (_) {
          return RatingOutcome.unavailable;
        }
        if (!_safe(isSafe)) return RatingOutcome.busy;
        try {
          // Commit before any app or OS prompt. Back, process death, platform
          // errors and unobservable OS quotas cannot cause immediate re-prompt.
          await store.save(state.offered(_clock()));
        } catch (_) {
          return RatingOutcome.storageUnavailable;
        }
        if (!_safe(isSafe)) return RatingOutcome.busy;
        final accepted = await confirm();
        if (!accepted) return RatingOutcome.dismissed;
        if (!_safe(isSafe)) return RatingOutcome.busy;
        await platform.requestReview();
        // The system may suppress the sheet; no submission/result is inferred.
        return RatingOutcome.requested;
      } catch (_) {
        return RatingOutcome.failed;
      } finally {
        _offering = false;
      }
    });
  }

  bool _safe(bool Function() check) {
    try {
      return check();
    } catch (_) {
      return false;
    }
  }
}
