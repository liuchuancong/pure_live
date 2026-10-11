/// Request coordination for one logical list: generation tokens plus a
/// busy flag.
///
/// Every async controller operation captures the generation when it
/// starts; refreshes and re-initializations invalidate the token, so a
/// late answer from a stale request is dropped instead of polluting the
/// new session. Cancellation of the underlying call is a transport
/// optimization the loader may do; dropping stale results here is the
/// correctness guarantee.
final class PaginationSession {
  int _generation = 0;
  bool _busy = false;

  /// The current generation token.
  int get generation => _generation;

  /// Whether an operation is in flight for the current generation.
  bool get isBusy => _busy;

  /// Claims the session for a new operation of the current generation.
  /// Returns false when another operation is already in flight — callers
  /// treat that as a duplicate request and back off.
  bool begin() {
    if (_busy) {
      return false;
    }
    _busy = true;
    return true;
  }

  /// Releases the session after the operation settled (its result was
  /// applied or dropped).
  void end() => _busy = false;

  /// Invalidates every in-flight operation and releases the busy flag:
  /// the next operation runs under a fresh generation, and older
  /// completions see a stale token and discard themselves.
  void invalidate() {
    _generation++;
    _busy = false;
  }

  /// Whether a result captured under [token] still belongs to this
  /// session.
  bool isCurrent(int token) => token == _generation;
}
