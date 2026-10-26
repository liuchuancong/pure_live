/// Severity of a log record.
///
/// Levels are ordered: [trace] < [debug] < [info] < [warning] < [error] <
/// [fatal] < [off]. Filter with [isAtLeast]; never compare enum indexes
/// directly.
enum LogLevel {
  /// Very high volume internal flow — relay hand-offs, socket frames.
  trace(0, 'TRACE'),

  /// Developer-facing detail useful when diagnosing a specific issue.
  debug(1, 'DEBUG'),

  /// Notable regular operation — startup, config applied, task finished.
  info(2, 'INFO'),

  /// Something unexpected that the code recovered from on its own.
  warning(3, 'WARN'),

  /// An operation failed and needs attention; user-visible impact likely.
  error(4, 'ERROR'),

  /// The process or a major subsystem cannot continue.
  fatal(5, 'FATAL'),

  /// Not a record level: the threshold that silences a tree entirely.
  /// Never emit a record at [off]; use it only as a minimum level
  /// (`setMinLevel(LogLevel.off)`) when nothing should reach the sinks.
  off(6, 'OFF');

  new(this.severity, this.label);

  /// Numeric severity, ascending with seriousness. [off] sits above every
  /// record level so no record can pass a threshold set to it.
  final int severity;

  /// Fixed-width upper-case label used by the text formatters.
  final String label;

  /// Whether this level is at least as severe as [other].
  bool isAtLeast(LogLevel other) => severity >= other.severity;

  /// Whether records may be emitted at this level. Only [off] is
  /// threshold-only.
  bool get isRecordLevel => this != off;
}
