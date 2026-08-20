import 'dart:async';

/// Coalesces presentation/lifecycle recovery requests without losing one when
/// Android is still finishing a picture-in-picture transition.
///
/// A one-shot delayed callback is not sufficient here: the native Activity can
/// already report `resumed` while Flutter still considers the compact
/// presentation active. A blocked attempt is therefore retried, and a request
/// arriving during an active reconnect is replayed after that reconnect.
class DanmakuPresentationRecovery {
  DanmakuPresentationRecovery({
    required this.isBlocked,
    required this.canRecover,
    required this.recover,
    this.settleDelay = const Duration(milliseconds: 180),
    this.retryDelay = const Duration(milliseconds: 120),
  });

  final bool Function() isBlocked;
  final bool Function() canRecover;
  final Future<void> Function() recover;
  final Duration settleDelay;
  final Duration retryDelay;

  Timer? _timer;
  Future<void>? _inFlight;
  int _requestedGeneration = 0;
  int _handledGeneration = 0;
  bool _disposed = false;

  void request() {
    if (_disposed) return;
    _requestedGeneration++;
    _schedule(settleDelay);
  }

  void _schedule(Duration delay) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, _attempt);
  }

  void _attempt() {
    _timer = null;
    if (_disposed || _handledGeneration >= _requestedGeneration) return;

    if (isBlocked()) {
      _schedule(retryDelay);
      return;
    }

    if (!canRecover()) {
      _handledGeneration = _requestedGeneration;
      return;
    }

    // The completion callback below will replay a newer request. Returning
    // here avoids overlapping stop/start operations on the same socket.
    if (_inFlight != null) return;

    final generation = _requestedGeneration;
    late final Future<void> operation;
    operation = Future<void>.sync(recover).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
      if (_disposed) return;
      if (generation > _handledGeneration) _handledGeneration = generation;
      if (_requestedGeneration > _handledGeneration) {
        _schedule(Duration.zero);
      }
    });
    _inFlight = operation;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
