// Module: lib/src/crash_reporting.dart
// Purpose: A consent-gated crash pipeline: nothing leaves the device until the user says so, and the records
// held before they say it are bounded and disposable.
// Author: liuchuancong
// Created: 2026-10-11
//
// docs/diagnostics/crash-report.md sets the rule: the upload switch is a privacy control and defaults to off,
// and whether the vendor SDK is wired at all is a release-stage decision. That means this layer cannot be a
// thin call into Crashlytics - the shape it needs is a queue that survives the disagreement between "the app
// crashed" and "the user has not opened the dialog yet", plus a decision that when they decline, the buffered
// reports are destroyed rather than kept "in case they change their mind".

import 'dart:async';

import 'package:pure_live_logging/pure_live_logging.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// The user's choice about sending crash reports.
enum CrashConsent {
  /// Not asked yet, or the answer was lost. Behaves as declined for anything that leaves the device.
  unknown,

  /// Explicitly allowed.
  granted,

  /// Explicitly refused, and the deciding fact for whether buffered reports are dropped.
  declined,
}

/// Where the answer is kept, so the app can bind it to its own preference store.
abstract interface class CrashConsentStore {
  Future<CrashConsent> read();

  Future<void> write(CrashConsent consent);
}

/// The memory implementation, for a test or a build whose settings screen has not wired persistence yet.
final class InMemoryCrashConsentStore implements CrashConsentStore {
  CrashConsent _consent = CrashConsent.unknown;

  @override
  Future<CrashConsent> read() async => _consent;

  @override
  Future<void> write(CrashConsent consent) async => _consent = consent;
}

/// One report, already reduced to what is safe to send.
final class CrashReport {
  const CrashReport({
    required this.kind,
    required this.summary,
    required this.at,
    required this.appVersion,
    this.stackSample,
    this.device = '',
    this.fields = const <String, String>{},
  });

  /// The `logging` level name that produced it, so a dashboard can split error from fatal.
  final String kind;

  /// The message, already redacted by the log record.
  final String summary;
  final DateTime at;

  /// The build string, kept as text: this package must not depend on the release package for a type it only
  /// forwards.
  final String appVersion;

  /// The first few frames, not the whole stack - a stack is unbounded and mostly platform noise.
  final String? stackSample;

  /// One line of device description, already bounded by whoever built it.
  final String device;

  final Map<String, String> fields;

  /// The cap on a stack sample, in characters.
  static const int stackBudget = 2000;

  static String clipStack(StackTrace? stack) {
    if (stack == null) {
      return '';
    }
    final text = '$stack';
    return text.length <= stackBudget ? text : '${text.substring(0, stackBudget)}…';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind,
      'summary': summary,
      'at': at.toUtc().toIso8601String(),
      'appVersion': appVersion,
      if (device.isNotEmpty) 'device': device,
      if (stackSample != null && stackSample!.isNotEmpty) 'stack': stackSample,
      if (fields.isNotEmpty) 'fields': fields,
    };
  }

  @override
  String toString() => 'CrashReport($kind $summary at=$at)';
}

/// The uploader. Implementations bind Crashlytics, Sentry or a WebDAV drop, and must not throw: the caller is
/// already a failure path.
abstract interface class CrashReporter {
  Future<void> report(CrashReport report);
}

/// A reporter that does nothing, for a build compiled without a vendor SDK.
final class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> report(CrashReport report) async {}
}

/// Why a report was not sent.
enum CrashDropReason {
  /// Consent is unknown or declined.
  notConsented,

  /// The buffer was full and this is the oldest entry, evicted.
  bufferFull,

  /// The uploader failed and the report was not retried.
  uploadFailed,

  /// The report sat in the buffer past [CrashGate.maxAge], where it describes a state the device no longer
  /// holds.
  expired,
}

/// The gate between "something failed" and "something was sent".
///
/// While consent is unresolved, reports are held in a bounded buffer: a crash on first launch happens before
/// the dialog has an answer, and dropping it loses the only evidence about the crash that stopped the user
/// from ever reaching the dialog. Once the answer is **declined**, the buffer is destroyed - holding user data
/// against a possible future change of mind is exactly what the switch means no to.
final class CrashGate {
  CrashGate({
    required CrashConsentStore consent,
    required CrashReporter reporter,
    required this.appVersion,
    this.bufferLimit = 32,
    this.maxAge = const Duration(hours: 6),
    Clock? clock,
    this.device = '',
    this.onDrop,
  }) : _consent = consent,
       _reporter = reporter,
       _clock = clock ?? systemClock {
    if (bufferLimit < 1) {
      throw ArgumentError.value(bufferLimit, 'bufferLimit', 'must hold at least one report');
    }
  }

  final CrashConsentStore _consent;
  final CrashReporter _reporter;
  final String appVersion;
  final int bufferLimit;

  /// How long a buffered report is still worth sending.
  final Duration maxAge;

  final String device;
  final Clock _clock;
  final void Function(CrashReport report, CrashDropReason reason)? onDrop;

  final List<CrashReport> _buffer = <CrashReport>[];
  CrashConsent _cached = CrashConsent.unknown;
  bool _resolved = false;
  Future<void>? _flushing;

  /// Reports held and not yet sent.
  int get bufferedCount => _buffer.length;

  CrashConsent get consent => _cached;

  /// Reads the stored answer once and caches it; call after the user changes it.
  Future<CrashConsent> resolve({bool force = false}) async {
    if (_resolved && !force) {
      return _cached;
    }
    final before = _cached;
    _cached = await _consent.read();
    _resolved = true;
    if (_cached == CrashConsent.declined && before != CrashConsent.declined) {
      _discardBuffered(CrashDropReason.notConsented);
    }
    if (_cached == CrashConsent.granted) {
      await flush();
    }
    return _cached;
  }

  /// The entry point for a failure path. Never throws and never awaits a network call on the caller's behalf
  /// beyond the upload itself.
  Future<void> submit(CrashReport report) async {
    if (!_resolved) {
      await resolve();
    }
    switch (_cached) {
      case CrashConsent.granted:
        await _send(report);
      case CrashConsent.unknown:
        _hold(report);
      case CrashConsent.declined:
        onDrop?.call(report, CrashDropReason.notConsented);
    }
  }

  /// The recorded answer, written through the store so a later launch keeps it.
  Future<void> setConsent(CrashConsent consent) async {
    _cached = consent;
    _resolved = true;
    await _consent.write(consent);
    if (consent == CrashConsent.declined) {
      _discardBuffered(CrashDropReason.notConsented);
    }
    if (consent == CrashConsent.granted) {
      await flush();
    }
  }

  /// Sends what the buffer holds, newest last, capped at [bufferLimit] so a long unknown-consent stretch does
  /// not turn into a bulk upload the user never agreed to.
  Future<int> flush() {
    final running = _flushing;
    if (running != null) {
      return running.then((_) => 0);
    }
    final job = () async {
      if (_buffer.isEmpty || _cached != CrashConsent.granted) {
        return 0;
      }
      final batch = List<CrashReport>.of(_buffer);
      _buffer.clear();
      final cutoff = _clock().subtract(maxAge);
      var sent = 0;
      for (final report in batch) {
        if (report.at.isBefore(cutoff)) {
          onDrop?.call(report, CrashDropReason.expired);
          continue;
        }
        try {
          await _reporter.report(report);
          sent++;
        } on Object {
          onDrop?.call(report, CrashDropReason.uploadFailed);
        }
      }
      return sent;
    }();
    _flushing = job.then((_) {});
    return job;
  }

  void _hold(CrashReport report) {
    if (_buffer.length >= bufferLimit) {
      final evicted = _buffer.removeAt(0);
      onDrop?.call(evicted, CrashDropReason.bufferFull);
    }
    _buffer.add(report);
  }

  void _discardBuffered(CrashDropReason reason) {
    for (final report in List<CrashReport>.of(_buffer)) {
      onDrop?.call(report, reason);
    }
    _buffer.clear();
  }

  Future<void> _send(CrashReport report) async {
    try {
      await _reporter.report(report);
    } on Object {
      // A reporter that throws must not become the second crash. The drop is recorded and the caller's own
      // failure stays the one that gets seen.
      onDrop?.call(report, CrashDropReason.uploadFailed);
    }
  }

  /// Builds a report from a log record. Only error-or-worse records qualify; a warning is not a crash.
  CrashReport reportFromRecord(LogRecord record) {
    return CrashReport(
      kind: record.level.name,
      summary: record.message,
      at: record.timestamp,
      appVersion: appVersion,
      stackSample: record.stackTrace == null ? null : CrashReport.clipStack(record.stackTrace),
      device: device,
      fields: <String, String>{for (final entry in record.fields.entries) entry.key: '${entry.value}'},
    );
  }
}

/// A [LogSink] that forwards error and fatal records into a [CrashGate].
///
/// It is a sink rather than a call site because the point is that nobody has to remember to report: the app
/// already logs its failures, and an exception path that forgets the crash reporter is the one that matters.
final class CrashLogSink implements LogSink {
  CrashLogSink({required this.gate, this.minLevel = LogLevel.error});

  final CrashGate gate;

  /// The floor a record must reach to be reported. `fatal` on its own misses the ordinary uncaught exception,
  /// which logs as `error`.
  final LogLevel minLevel;

  int _seen = 0;
  int _failed = 0;

  /// Records that reached the gate.
  int get acceptedCount => _seen;

  /// Gate submissions that threw - which should be zero, since the gate is built not to.
  int get failureCount => _failed;

  @override
  void emit(LogRecord record) {
    if (record.level.index < minLevel.index) {
      return;
    }
    _seen++;
    unawaited(
      gate.submit(gate.reportFromRecord(record)).catchError((Object _) {
        _failed++;
      }),
    );
  }
}
