// Module: lib/src/recording.dart
// Purpose: The mechanism behind diagnostics: a bounded ring buffer, guarded execution and timed sections.
// Author: liuchuancong
// Created: 2026-10-08
//
// This package holds mechanism only. The vocabulary that leaves the device (DiagnosticEvent,
// DiagnosticTrace, PlatformErrorInfo) is defined in pure_live_platform, because those types are shared
// with providers and the UI; keeping them out of here is what stops an L0 package from pointing upward.
//
// The buffer is bounded by construction: an unbounded "just in case" log is how a long playback session
// turns into an out-of-memory crash while trying to explain a smaller one.

import 'dart:async';

/// A fixed-capacity buffer that keeps the newest entries and counts what it dropped.
///
/// A real ring: an overwrite is O(1). The first version called `removeAt(0)` on a growable list, which
/// copies the tail on every add once full - and the whole point of this buffer is that it is written on
/// every diagnostic event for the lifetime of a session.
final class RingBuffer<T> {
  RingBuffer({required this.capacity}) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be at least 1');
    }
    _items = List<T?>.filled(capacity, null);
  }

  final int capacity;
  late final List<T?> _items;
  int _start = 0;
  int _length = 0;
  int _dropped = 0;

  /// Entries from oldest to newest.
  List<T> get entries => List<T>.generate(_length, (index) => _items[(_start + index) % capacity] as T);

  int get length => _length;

  bool get isEmpty => _length == 0;

  bool get isFull => _length == capacity;

  /// How many entries were evicted to stay inside [capacity]. A non-zero count means the view is partial.
  int get droppedCount => _dropped;

  void add(T item) {
    if (_length == capacity) {
      // Overwrite the oldest slot in place and advance the head, rather than shifting anything.
      _items[_start] = item;
      _start = (_start + 1) % capacity;
      _dropped++;
      return;
    }
    _items[(_start + _length) % capacity] = item;
    _length++;
  }

  /// Newest first, which is the order a log viewer shows.
  List<T> get newestFirst =>
      List<T>.generate(_length, (index) => _items[(_start + (_length - 1 - index)) % capacity] as T);

  void clear() {
    _items.fillRange(0, _items.length, null);
    _start = 0;
    _length = 0;
    _dropped = 0;
  }
}

/// Runs [body] so an escaping error is reported instead of killing the isolate or the zone.
///
/// Returns true when an error was caught - including an error from [onError] itself, which is reported as
/// a failure rather than allowed to leave the caller waiting.
///
/// The previous version called the handler without guarding it, so a reporter that threw - a locked
/// diagnostics file is the usual one - hung the caller inside a future that never completed. A broken
/// diagnostics path must be loud: it is the thing you consult when everything else already failed.
Future<bool> runGuarded(
  FutureOr<void> Function() body, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  var failed = false;
  // Handler failures are collected and rethrown after the guard has finished, so one bad reporter cannot
  // hide the reason the body needed reporting in the first place.
  Object? handlerError;
  StackTrace? handlerStack;

  void report(Object error, StackTrace stackTrace) {
    failed = true;
    try {
      onError(error, stackTrace);
    } catch (inner, innerStack) {
      handlerError ??= inner;
      handlerStack ??= innerStack;
    }
  }

  await runZonedGuarded<Future<void>>(() async {
    try {
      await body();
    } catch (error, stackTrace) {
      report(error, stackTrace);
    }
  }, report);

  final raised = handlerError;
  if (raised != null) {
    Error.throwWithStackTrace(raised, handlerStack!);
  }
  return failed;
}

/// Reports how long [label] took, whether or not it failed.
///
/// Timing must survive a throw: the slow path is usually the failing one, and losing the measurement there
/// is exactly when it matters.
///
/// Measured with a [Stopwatch], not two `DateTime.now()` readings: a wall clock can step backwards during
/// a session (an NTP correction, a user changing the time, a time-zone-aware device wake), and the
/// difference was then reported as a negative duration - which a dashboard reads as "instant", and a
/// threshold check as "fast enough to ignore".
Future<R> measure<R>(
  String label,
  Future<R> Function() body, {
  required void Function(String label, Duration elapsed, bool failed) onComplete,
}) async {
  final stopwatch = Stopwatch()..start();
  var failed = false;
  try {
    return await body();
  } catch (_) {
    failed = true;
    rethrow;
  } finally {
    stopwatch.stop();
    onComplete(label, stopwatch.elapsed, failed);
  }
}
