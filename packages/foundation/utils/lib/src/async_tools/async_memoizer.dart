// Module: lib/src/async_tools/async_memoizer.dart
// Purpose: Cache an async computation per key, with an optional lifetime, without a second stampede layer.
// Author: liuchuancong
// Created: 2026-10-10
//
// SingleFlight deduplicates concurrent calls but keeps nothing afterwards; a plain map keeps forever and
// never expires. This sits between them: one in-flight operation per key plus a bounded, time-limited
// result cache. The clock is injected because "did the entry expire" is exactly the question a test must be
// able to answer without waiting.

import 'dart:async';

import '../time/time_source.dart';
import 'single_flight.dart';

/// Memoizes async computations by key for [ttl], sharing in-flight work between concurrent callers.
final class AsyncMemoizer<T> {
  AsyncMemoizer({this.ttl = Duration.zero, this.maxEntries = 64, Clock? clock})
    : _clock = clock ?? systemClock;

  /// How long a completed value stays reusable. [Duration.zero] means "never expires" (still bounded by
  /// [maxEntries]).
  final Duration ttl;

  /// Completed entries kept at once; the oldest is dropped first.
  ///
  /// A cache with no bound is a memory leak with a nicer name: the keys here are content references and
  /// urls, which a user can grow without limit by scrolling.
  final int maxEntries;

  final Clock _clock;
  final SingleFlight<T> _flight = SingleFlight<T>();
  final Map<Object, _Memo<T>> _entries = <Object, _Memo<T>>{};

  /// The cached or freshly computed value for [key].
  Future<T> run(Object key, Future<T> Function() computation) async {
    final cached = _entries[key];
    if (cached != null && !_expired(cached)) {
      return cached.value;
    }
    if (cached != null) {
      _entries.remove(key);
    }
    return _flight.run(key, () async {
      // Re-check inside the flight: a sibling caller may have completed while this one queued.
      final settled = _entries[key];
      if (settled != null && !_expired(settled)) {
        return settled.value;
      }
      final value = await computation();
      _store(key, value);
      return value;
    });
  }

  /// Drops one key, or every key when [key] is null.
  void invalidate({Object? key}) {
    if (key == null) {
      _entries.clear();
      return;
    }
    _entries.remove(key);
  }

  /// How many completed values are currently held.
  int get length => _entries.length;

  void _store(Object key, T value) {
    _entries[key] = _Memo<T>(value, _clock());
    while (_entries.length > maxEntries) {
      final oldest = _entries.entries.reduce((a, b) => a.value.storedAt.isBefore(b.value.storedAt) ? a : b);
      _entries.remove(oldest.key);
    }
  }

  bool _expired(_Memo<T> entry) =>
      ttl > Duration.zero && !_clock().toUtc().isBefore(entry.storedAt.toUtc().add(ttl));
}

final class _Memo<T> {
  _Memo(this.value, this.storedAt);

  final T value;
  final DateTime storedAt;
}
