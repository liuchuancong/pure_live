// Module: lib/src/limiter.dart
// Purpose: Bounds how many requests one client runs at once and how fast it may re-ask one host.
// Author: liuchuancong
// Created: 2026-10-11
//
// A fan-out search hits twenty sites at once and a playlist page fetches a segment per episode; with no bound
// the phone runs out of sockets, the failure mode is a wall of timeouts, and the site that got ten requests in
// a second rate-limits the app for the next hour. Both limits have to be explicit and both have to be honest
// when they refuse: queueing forever hides the fact that the caller asked for more than the transport can do.

import 'dart:async';

import 'package:pure_live_utils/pure_live_utils.dart';

/// The queue was already full when a caller asked for a slot.
final class LimiterOverflow implements Exception {
  const LimiterOverflow({required this.queueLimit, required this.waiting});

  final int queueLimit;
  final int waiting;

  @override
  String toString() => 'LimiterOverflow($waiting waiting, limit $queueLimit)';
}

/// The limiter was closed while work was still queued.
final class LimiterClosed implements Exception {
  const LimiterClosed({this.released = 0});

  /// How many waiters were woken up to be told no.
  final int released;

  @override
  String toString() => 'LimiterClosed($released waiters released)';
}

/// Runs at most [maxConcurrent] actions at a time, then queues.
///
/// The queue is bounded on purpose: an unbounded queue converts "we are slower than the caller" into a memory
/// problem that shows up minutes later, far from the cause.
final class ConcurrencyLimiter {
  ConcurrencyLimiter({required int maxConcurrent, this.queueLimit = 64})
    : assert(maxConcurrent >= 1, 'a limiter that allows zero concurrency blocks forever'),
      assert(queueLimit >= 0, 'a negative queue limit cannot be met'),
      _maxConcurrent = maxConcurrent;

  final int _maxConcurrent;
  final int queueLimit;

  int _running = 0;
  bool _closed = false;
  final List<CompleterSlot> _waiting = <CompleterSlot>[];

  int get maxConcurrent => _maxConcurrent;

  /// Actions currently executing.
  int get inFlight => _running;

  /// Callers waiting for a slot.
  int get waiting => _waiting.length;

  bool get isClosed => _closed;

  /// Runs [action] once a slot is free.
  Future<T> run<T>(Future<T> Function() action) async {
    if (_closed) {
      throw const LimiterClosed();
    }
    if (_running >= _maxConcurrent) {
      if (_waiting.length >= queueLimit) {
        throw LimiterOverflow(queueLimit: queueLimit, waiting: _waiting.length);
      }
      final slot = CompleterSlot();
      _waiting.add(slot);
      await slot.granted;
      // A close while waiting means this caller must not start work it was told to abandon.
      if (slot.cancelled) {
        throw const LimiterClosed();
      }
    } else {
      _running++;
    }
    try {
      return await action();
    } finally {
      _release();
    }
  }

  void _release() {
    if (_waiting.isEmpty) {
      _running--;
      return;
    }
    // The slot moves to the next waiter, so the running count does not change.
    final next = _waiting.removeAt(0);
    next.grant();
  }

  /// Refuses new work and wakes every waiter with [LimiterClosed]. Running actions finish normally.
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    final pending = List<CompleterSlot>.of(_waiting);
    _waiting.clear();
    for (final slot in pending) {
      slot.reject();
    }
  }
}

/// One queued caller's wake-up.
final class CompleterSlot {
  final Completer<void> _completer = Completer<void>();

  bool _cancelled = false;

  Future<void> get granted => _completer.future;

  bool get cancelled => _cancelled;

  void grant() => _completer.complete();

  void reject() {
    _cancelled = true;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

/// Keeps a minimum spacing between requests to the same host.
///
/// The slot is *reserved* when the caller asks, not when it wakes: two concurrent requests to one host must
/// still leave a full interval apart, or the interval only spaces the first of each pair.
final class HostThrottle {
  HostThrottle({required this.minimumInterval, Clock? clock}) : _clock = clock ?? systemClock {
    if (minimumInterval.isNegative) {
      throw ArgumentError.value(minimumInterval, 'minimumInterval', 'cannot be negative');
    }
  }

  final Duration minimumInterval;
  final Clock _clock;
  final Map<String, DateTime> _nextAllowed = <String, DateTime>{};

  /// How many hosts are currently spaced.
  int get trackedHosts => _nextAllowed.length;

  /// Awaits until [host] may be asked again.
  Future<void> waitFor(String host) {
    final delay = reserve(host);
    if (delay == null) {
      return Future<void>.value();
    }
    return Future<void>.delayed(delay);
  }

  /// Reserves the next slot for [host] and returns how long the caller must still wait (null for "now").
  Duration? reserve(String host) {
    final key = host.trim().toLowerCase();
    if (key.isEmpty || minimumInterval == Duration.zero) {
      return null;
    }
    final now = _clock();
    final earliest = _nextAllowed[key];
    final start = earliest != null && earliest.isAfter(now) ? earliest : now;
    _nextAllowed[key] = start.add(minimumInterval);
    final wait = start.difference(now);
    return wait <= Duration.zero ? null : wait;
  }

  /// How long [host] still owes before its next request.
  Duration pending(String host) {
    final earliest = _nextAllowed[host.trim().toLowerCase()];
    if (earliest == null) {
      return Duration.zero;
    }
    final wait = earliest.difference(_clock());
    return wait.isNegative ? Duration.zero : wait;
  }

  void reset(String host) => _nextAllowed.remove(host.trim().toLowerCase());

  void clear() => _nextAllowed.clear();
}
