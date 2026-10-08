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
final class RingBuffer<T> {
  RingBuffer({required this.capacity}) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be at least 1');
    }
  }

  final int capacity;
  final List<T> _items = <T>[];
  int _dropped = 0;

  /// Entries from oldest to newest.
  List<T> get entries => List<T>.unmodifiable(_items);

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;

  /// How many entries were evicted to stay inside [capacity]. A non-zero count means the view is partial.
  int get droppedCount => _dropped;

  void add(T item) {
    _items.add(item);
    while (_items.length > capacity) {
      _items.removeAt(0);
      _dropped++;
    }
  }

  /// Newest first, which is the order a log viewer shows.
  List<T> get newestFirst => _items.reversed.toList(growable: false);

  void clear() {
    _items.clear();
    _dropped = 0;
  }
}

/// Runs [body] so an escaping error is reported instead of killing the isolate or the zone.
///
/// Returns true when an error was caught. Callers use this around work whose failure must not propagate,
/// such as writing a diagnostic file, while still leaving a record that it happened.
Future<bool> runGuarded(
  FutureOr<void> Function() body, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  final completer = Completer<bool>();
  await runZonedGuarded<Future<void>>(
    () async {
      try {
        await body();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      } catch (error, stackTrace) {
        onError(error, stackTrace);
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    },
    (error, stackTrace) {
      // An error that escaped the zone means body() forgot to await something; report it the same way.
      onError(error, stackTrace);
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    },
  );
  return completer.future;
}

/// Reports how long [label] took, whether or not it failed.
///
/// Timing must survive a throw: the slow path is usually the failing one, and losing the measurement
/// there is exactly when it matters.
Future<R> measure<R>(
  String label,
  Future<R> Function() body, {
  required void Function(String label, Duration elapsed, bool failed) onComplete,
}) async {
  final started = DateTime.now().toUtc();
  var failed = false;
  try {
    return await body();
  } catch (_) {
    failed = true;
    rethrow;
  } finally {
    onComplete(label, DateTime.now().toUtc().difference(started), failed);
  }
}
