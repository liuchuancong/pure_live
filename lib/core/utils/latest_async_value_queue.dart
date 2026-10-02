import 'dart:async';

/// Serializes an asynchronous state transition and coalesces requests that
/// arrive while it is running to the latest requested value.
class LatestAsyncValueQueue<T> {
  LatestAsyncValueQueue(this._apply);

  final Future<void> Function(T value) _apply;

  bool _running = false;
  bool _hasPending = false;
  bool _hasActive = false;
  T? _pending;
  T? _active;
  Completer<void>? _activeCompleter;

  bool get isRunning => _running;

  Future<void> submit(T value) {
    if (_running && !_hasPending && _hasActive && _active == value) {
      return _activeCompleter!.future;
    }
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
    Object? latestError;
    StackTrace? latestStackTrace;
    try {
      while (_hasPending) {
        final value = _pending as T;
        _hasPending = false;
        _active = value;
        _hasActive = true;
        try {
          await _apply(value);
          latestError = null;
          latestStackTrace = null;
        } catch (error, stackTrace) {
          // A value queued while the failed transition was running supersedes
          // that failure. Continue draining so a stale room/page request can
          // never discard the latest requested state.
          latestError = error;
          latestStackTrace = stackTrace;
        } finally {
          _active = null;
          _hasActive = false;
        }
      }
      if (latestError != null) {
        completer.completeError(latestError, latestStackTrace!);
      } else {
        completer.complete();
      }
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _pending = null;
      _active = null;
      _hasPending = false;
      _hasActive = false;
      _running = false;
      _activeCompleter = null;
    }
  }
}
