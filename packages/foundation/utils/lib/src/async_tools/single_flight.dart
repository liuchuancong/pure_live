// Module: lib/src/async_tools/single_flight.dart
// Purpose: Run one operation per key at a time and share its result with callers that arrive meanwhile.
// Author: liuchuancong
// Created: 2026-10-08
//
// The platform issues the same request repeatedly - several widgets opening one room, or a line switch
// retrying a dead url. Sharing the in-flight future removes the stampede without any caller having to
// coordinate, and without caching the result afterwards (that is AsyncMemoizer's job).

/// Runs one operation per key at a time, sharing the result with callers that arrive while it is in flight.
final class SingleFlight<T> {
  final Map<Object, Future<T>> _inFlight = <Object, Future<T>>{};

  /// Number of operations currently running.
  int get pendingCount => _inFlight.length;

  /// Returns the shared future for [key], starting [operation] when none is running.
  ///
  /// A failing operation still shares its error: the point is to avoid a stampede, not to hide failures.
  Future<T> run(Object key, Future<T> Function() operation) {
    final running = _inFlight[key];
    if (running != null) {
      return running;
    }
    late final Future<T> started;
    started = Future<T>.microtask(operation).whenComplete(() {
      // Only drop the entry if it is still ours; a newer call may already have replaced it.
      if (identical(_inFlight[key], started)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = started;
    return started;
  }
}
