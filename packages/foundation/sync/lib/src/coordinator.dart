// Module: lib/src/coordinator.dart
// Purpose: Drives the engine on a schedule: one pass at a time, backed off after a failure, debounced on a
// burst of local changes.
// Author: liuchuancong
// Created: 2026-10-11
//
// The engine is a single pass with no opinion about *when*. The real triggers are a user who edits five
// settings in a row, a device that wakes up, and a network that is down - and each one of those turns into a
// stampede or a hammering retry loop if the scheduler is written at the call site. Everything here is bounded:
// the backoff has a ceiling, the queue of waiting requests is one slot, and the failure ledger is a ring.

import 'dart:async';

import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'sync_engine.dart';

/// Why a pass did not run, or ended in failure.
final class SyncFailure implements Exception {
  const SyncFailure({required this.phase, required this.cause, required this.at, this.willRetry});

  /// `pull`, `push` or `pullAll`.
  final String phase;
  final Object cause;
  final DateTime at;

  /// When the coordinator intends to try again, or null when it is waiting for a trigger.
  final DateTime? willRetry;

  bool get isRetryScheduled => willRetry != null;

  @override
  String toString() => 'SyncFailure($phase at=$at cause=$cause${willRetry == null ? '' : ', retryAt=$willRetry'})';
}

/// How the coordinator spaces its attempts.
final class SyncSchedule {
  const SyncSchedule({
    this.debounce = const Duration(seconds: 2),
    this.minInterval = const Duration(seconds: 5),
    this.baseBackoff = const Duration(seconds: 10),
    this.maxBackoff = const Duration(minutes: 10),
    this.backoffFactor = 2.0,
  });

  /// Local changes arriving inside this window collapse into one pass.
  final Duration debounce;

  /// Two successful passes never run closer than this.
  final Duration minInterval;

  /// The wait after the first failure, multiplied by [backoffFactor] per failure up to [maxBackoff].
  final Duration baseBackoff;
  final Duration maxBackoff;
  final double backoffFactor;

  /// The wait after [failures] consecutive failures.
  Duration backoffFor(int failures) {
    if (failures <= 0) {
      return Duration.zero;
    }
    var wait = baseBackoff;
    for (var round = 1; round < failures; round++) {
      final grown = Duration(microseconds: (wait.inMicroseconds * backoffFactor).round());
      wait = grown > maxBackoff ? maxBackoff : grown;
    }
    return wait > maxBackoff ? maxBackoff : wait;
  }
}

/// Runs [SyncEngine] passes on request, one at a time.
///
/// [request] is the only way in: it coalesces, so a screen that marks five rows dirty triggers one pass, not
/// five. A failure sets the next allowed time rather than retrying on a timer, because a device in a tunnel
/// should spend its wake-up on the user's action, not on a sync loop.
final class SyncCoordinator {
  SyncCoordinator({
    required SyncEngine engine,
    required this.schedule,
    this.onReport,
    this.onFailure,
    this.onSyncFailure,
    Clock? clock,
    Logger? log,
  }) : _engine = engine,
       _clock = clock ?? systemClock,
       _log = log;

  /// How many failures the coordinator remembers.
  static const int failureLedgerLimit = 32;

  final SyncEngine _engine;
  final SyncSchedule schedule;
  final void Function(SyncReport report)? onReport;
  final void Function()? onSyncFailure;
  final void Function(SyncFailure failure)? onFailure;
  final Logger? _log;
  final Clock _clock;

  SyncCursor _cursor = SyncCursor.start;
  DateTime? _nextAllowed;
  Timer? _debounce;
  Future<SyncReport?>? _running;
  int _consecutiveFailures = 0;
  final List<SyncFailure> _failures = <SyncFailure>[];
  bool _stopped = false;
  int _passes = 0;

  /// Where the next pull will start.
  SyncCursor get cursor => _cursor;

  /// Consecutive failures so far; a success resets it.
  int get consecutiveFailures => _consecutiveFailures;

  /// Recent failures, newest first.
  List<SyncFailure> get failures => List<SyncFailure>.unmodifiable(_failures.reversed);

  int get completedPasses => _passes;

  bool get isRunning => _running != null;

  /// True once a pass is allowed to start; false during the backoff window.
  bool get isWaitingForBackoff {
    final next = _nextAllowed;
    return next != null && _clock().isBefore(next);
  }

  /// Asks for a pass. A burst inside [SyncSchedule.debounce] is one pass.
  ///
  /// Returns the report of the pass this request ended up joining, or null when it was coalesced into a pass
  /// that then failed.
  Future<SyncReport?> request() {
    if (_stopped) {
      return Future<SyncReport?>.value();
    }
    final completer = Completer<SyncReport?>();
    _pending.add(completer);
    _debounce ??= Timer(schedule.debounce, _runPending);
    return completer.future;
  }

  /// Runs a pass now, skipping the debounce but still honouring the single-flight and the backoff floor.
  Future<SyncReport?> syncNow() async {
    if (_stopped) {
      return null;
    }
    _debounce?.cancel();
    _debounce = null;
    return _pass();
  }

  /// Stops the loop, cancels the pending window and completes any waiting request with null.
  Future<void> stop() async {
    _stopped = true;
    _debounce?.cancel();
    _debounce = null;
    final waiting = List<Completer<SyncReport?>>.of(_pending);
    _pending.clear();
    for (final completer in waiting) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    // A failed in-flight pass rethrows; stopping must not turn that into an exception at the caller that
    // only asked to shut down.
    try {
      await _running;
    } on Object {
      // The failure is already in the ledger.
    }
  }

  /// Forgets the backoff state, for the user who pressed "sync now" after a long offline stretch.
  void resetBackoff() {
    _consecutiveFailures = 0;
    _nextAllowed = null;
  }

  final List<Completer<SyncReport?>> _pending = <Completer<SyncReport?>>[];

  void _runPending() {
    _debounce = null;
    final waiting = List<Completer<SyncReport?>>.of(_pending);
    _pending.clear();
    final pass = _pass();
    for (final completer in waiting) {
      if (!completer.isCompleted) {
        pass.then(completer.complete, onError: (Object _, StackTrace __) => completer.complete());
      }
    }
  }

  Future<SyncReport?> _pass() async {
    final running = _running;
    if (running != null) {
      return running;
    }
    final now = _clock();
    final blockedUntil = _nextAllowed;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      return null;
    }
    if (blockedUntil != null) {
      _nextAllowed = null;
    }
    final started = _clock();
    final attempt = Future<SyncReport?>(() async {
      final pulled = await _engine.pullAll(from: _cursor);
      final pushed = await _engine.push(known: pulled.cursorAfter(_cursor));
      return pulled.merge(pushed);
    });
    _running = attempt;
    try {
      final report = await attempt;
      _consecutiveFailures = 0;
      _passes++;
      if (report != null) {
        _cursor = report.cursorAfter(_cursor);
        onReport?.call(report);
      }
      _nextAllowed = _clock().add(schedule.minInterval);
      return report;
    } on Object catch (error, stackTrace) {
      _consecutiveFailures++;
      final wait = schedule.backoffFor(_consecutiveFailures);
      final failure = SyncFailure(
        phase: 'pullPush',
        cause: error,
        at: started,
        willRetry: wait == Duration.zero ? null : _clock().add(wait),
      );
      _record(failure);
      _nextAllowed = wait == Duration.zero ? null : _clock().add(wait);
      _log?.warning(
        'sync pass failed',
        fields: <String, Object?>{'failures': _consecutiveFailures, 'backoffMs': wait.inMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
      onFailure?.call(failure);
      onSyncFailure?.call();
      rethrow;
    } finally {
      _running = null;
    }
  }

  void _record(SyncFailure failure) {
    _failures.add(failure);
    while (_failures.length > SyncCoordinator.failureLedgerLimit) {
      _failures.removeAt(0);
    }
  }
}
