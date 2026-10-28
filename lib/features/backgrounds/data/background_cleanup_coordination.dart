import 'dart:async';

/// A one-process startup barrier. Cleanup cannot start after UI/editor creation,
/// and all reference-changing repository operations share this coordinator.
class BackgroundStorageCoordinator {
  static final application = BackgroundStorageCoordinator();
  bool _started = false, _cleaning = false;
  int _writers = 0, _waiting = 0;
  bool get hasWaitingWriters => _waiting != 0;
  Completer<void>? _released;
  bool beginStartupCleanup() {
    if (_started || _cleaning || _writers != 0) return false;
    _cleaning = true;
    _released = Completer<void>();
    return true;
  }

  void finishStartupCleanup() {
    _cleaning = false;
    final released = _released;
    _released = null;
    if (released != null && !released.isCompleted) released.complete();
  }

  void applicationStarted() {
    if (_cleaning) throw StateError('Startup cleanup has not finished');
    _started = true;
  }

  Future<T> write<T>(Future<T> Function() action) async {
    while (_cleaning) {
      _waiting++;
      try {
        await _released!.future;
      } finally {
        _waiting--;
      }
    }
    _writers++;
    try {
      return await action();
    } finally {
      _writers--;
    }
  }
}
