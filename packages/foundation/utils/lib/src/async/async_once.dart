// Module: lib/src/async/async_once.dart
// Purpose: Run a computation at most once per key and keep the answer, without a clock or an expiry.
// Author: liuchuancong
// Created: 2026-10-10
//
// Next to [AsyncMemoizer] this looks redundant, and the difference is the point: a memoizer is a cache, so
// it needs a ttl, a clock and an eviction policy, and a value can vanish between two reads. This is a
// latch - "has this key been produced yet?" has one answer for the life of the object - which is what a
// bootstrap or a one-time migration wants, and wants without an injectable clock standing between it and
// the caller.
//
// A failed computation is not remembered, so the next call tries again: a latch that latches on failure
// turns one transient io error into a permanently unavailable feature.

import 'dart:async';

/// Keeps one successful computation per key.
final class AsyncOnce<T> {
  AsyncOnce({this.maxEntries = 64});

  /// How many completed values are kept; the oldest is dropped first.
  ///
  /// Bounded by default because the keys here are content references and urls, which a user can grow
  /// without limit by scrolling - see doc/design-decisions.md on why nothing in this package is unbounded.
  final int maxEntries;

  final Map<Object, Future<T>> _entries = <Object, Future<T>>{};
  final List<Object> _order = <Object>[];

  /// How many completed values are held.
  int get length => _entries.length;

  /// True when [key] already has a stored value.
  bool contains(Object key) => _entries.containsKey(key);

  /// Returns the stored value for [key], computing it once when absent.
  ///
  /// Concurrent callers share one computation. An error is not stored: it reaches every caller waiting on
  /// this attempt, and the following call starts a fresh one.
  Future<T> run(Object key, Future<T> Function() computation) {
    final stored = _entries[key];
    if (stored != null) {
      return stored;
    }
    final completion = Future<T>.microtask(computation).then<T>(
      (value) {
        _touch(key);
        return value;
      },
      onError: (Object error, StackTrace stack) {
        // Drop the placeholder so a later call may retry; the error still propagates to this caller.
        _entries.remove(key);
        _order.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _entries[key] = completion;
    _touch(key);
    _evict();
    return completion;
  }

  /// Forgets [key] so the next [run] computes it again.
  void reset(Object key) {
    _entries.remove(key);
    _order.remove(key);
  }

  /// Forgets everything.
  void resetAll() {
    _entries.clear();
    _order.clear();
  }

  /// The value already stored for [key], or null.
  Future<T>? peek(Object key) => _entries[key];

  void _touch(Object key) {
    _order.remove(key);
    _order.add(key);
  }

  void _evict() {
    while (_order.length > maxEntries) {
      final oldest = _order.removeAt(0);
      _entries.remove(oldest);
    }
  }
}
