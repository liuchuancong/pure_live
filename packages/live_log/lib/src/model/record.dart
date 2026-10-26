import 'package:live_log/src/model/level.dart';

/// One immutable log entry.
///
/// Records built by `LiveLog` arrive at sinks already sanitised, with a
/// process-unique [sequence] and a UTC [timestamp].
final class LogRecord {
  /// A record captured at [timestamp] (defaults to now, stored in UTC)
  /// with a [category] dot path such as `sites.bilibili`.
  new({
    required this.level,
    required this.category,
    required this.message,
    this.fields = const {},
    DateTime? timestamp,
    this.error,
    this.stackTrace,
    this.sequence = 0,
  }) : timestamp = _utcOrNow(timestamp);

  /// Severity of the entry.
  final LogLevel level;

  /// Category path, e.g. `live_net.socket` or `sites.douyu`.
  final String category;

  /// Human-readable message, already redacted when emitted through LiveLog.
  final String message;

  /// Structured extras (requestId, taskId, …), already redacted when
  /// emitted through LiveLog.
  ///
  /// Never place whole business objects, HTTP bodies, cookies or media URLs
  /// here — they are caller-controlled payloads, not fields.
  final Map<String, Object?> fields;

  /// Capture time, stored in UTC.
  final DateTime timestamp;

  /// The error object, if this record reports one.
  final Object? error;

  /// The stack trace accompanying [error], if captured.
  final StackTrace? stackTrace;

  /// Process-unique sequence number assigned by the emitting tree.
  final int sequence;

  static DateTime _utcOrNow(DateTime? timestamp) => (timestamp ?? DateTime.now()).toUtc();

  @override
  String toString() =>
      'LogRecord(${timestamp.toIso8601String()} '
      '${level.label} [$category] $message)';
}
