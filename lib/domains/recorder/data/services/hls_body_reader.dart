import 'dart:async';

/// Owns an HTTP response body even before its first read. StreamIterator.cancel
/// alone does not subscribe/cancel its original stream before moveNext; response
/// rejection would otherwise leave the upstream socket unread and retained.
final class HlsBodyReader implements StreamIterator<List<int>> {
  HlsBodyReader(this._source) : _iterator = StreamIterator<List<int>>(_source);
  final Stream<List<int>> _source;
  final StreamIterator<List<int>> _iterator;
  bool _subscribed = false;
  bool _cancelRequested = false;
  Future<void>? _cancelling;

  @override
  List<int> get current => _iterator.current;
  @override
  Future<bool> moveNext() {
    if (_cancelRequested) return Future.value(false);
    _subscribed = true;
    return _iterator.moveNext();
  }

  @override
  Future<void> cancel() {
    _cancelRequested = true;
    return _cancelling ??= _cancelOwned();
  }

  Future<void> _cancelOwned() async {
    if (!_subscribed) {
      _subscribed = true;
      try {
        await _source.listen(null).cancel();
      } finally {
        await _iterator.cancel();
      }
    } else {
      await _iterator.cancel();
    }
  }
}

/// Application policy for receiving a complete HLS response, not an FFmpeg
/// protocol promise. A response gets at most four idle intervals in total,
/// shared across redirect headers/bodies and final manifest/media staging.
/// Pending connection creation still belongs to HttpClient's connection timeout;
/// check before/after it, without abandoning a late request or pooled socket.
class HlsResponseBudget {
  HlsResponseBudget(this.idle);
  final Duration idle;
  final Stopwatch clock = Stopwatch()..start();
  static Duration totalFor(Duration idle) => idle * 4;
  Duration get remaining => totalFor(idle) - clock.elapsed;

  void check() {
    if (remaining <= Duration.zero) throw TimeoutException('HLS complete response deadline exceeded');
  }

  Future<T> wait<T>(Future<T> Function() action, {void Function()? abort}) async {
    try {
      check();
      final left = remaining;
      return await action().timeout(left < idle ? left : idle);
    } on TimeoutException {
      abort?.call();
      rethrow;
    }
  }
}
