import 'dart:async';

/// Serializes an asynchronous state transition and coalesces requests that
/// arrive while it is running to the latest requested value.
class LatestAsyncValueQueue<T> {
  LatestAsyncValueQueue(this._apply);

  final Future<void> Function(T value) _apply;

  bool _running = false;
  bool _hasPending = false;
  T? _pending;
  Completer<void>? _activeCompleter;

  bool get isRunning => _running;

  Future<void> submit(T value) {
    _pending = value;
    _hasPending = true;

    if (_running) return _activeCompleter!.future;

    _running = true;
    final completer = Completer<void>();
    _activeCompleter = completer;
    unawaited(_drain(completer));
    return completer.future;
  }

  Future<void> _drain(Completer<void> completer) async {
    try {
      while (_hasPending) {
        final value = _pending as T;
        _hasPending = false;
        await _apply(value);
      }
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _pending = null;
      _hasPending = false;
      _running = false;
      _activeCompleter = null;
    }
  }
}
