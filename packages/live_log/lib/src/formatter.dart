import 'dart:convert';

import 'package:live_log/src/record.dart';
import 'package:live_log/src/sanitizer.dart';

/// Renders [LogRecord]s for the sinks.
///
/// [plain] produces the human-readable console/file line;
/// [jsonLine] produces one JSON Lines entry for structured exports. Both
/// apply [LogSanitizer] to whatever the record still carries raw — the
/// error object and the stack trace — so nothing leaves the process
/// unsanitised.
abstract final class LogFormatter {
  /// Renders [record] as `HH:mm:ss.mmm LEVEL [category] message {fields}`,
  /// with the error and stack trace as continuation lines when present.
  ///
  /// The timestamp is shown in the local zone for readability; records
  /// themselves are stored in UTC.
  static String plain(LogRecord record, {LogSanitizer sanitizer = const LogSanitizer()}) {
    final builder = StringBuffer()
      ..write(_clock(record.timestamp.toLocal()))
      ..write(' ')
      ..write(record.level.label.padRight(5))
      ..write(' [')
      ..write(record.category)
      ..write('] ')
      ..write(record.message);
    if (record.fields.isNotEmpty) {
      builder
        ..write(' {')
        ..write(record.fields.entries.map((entry) => '${entry.key}: ${entry.value}').join(', '))
        ..write('}');
    }
    final error = record.error;
    if (error != null) {
      builder
        ..write('\n  error: ')
        ..write(sanitizer.sanitizeText(error.toString()));
    }
    final stackTrace = record.stackTrace;
    if (stackTrace != null) {
      builder
        ..write('\n')
        ..write(sanitizer.sanitizeText(stackTrace.toString().trimRight()));
    }
    return builder.toString();
  }

  /// Renders [record] as a single-line JSON object (JSON Lines convention):
  /// `ts` (UTC ISO-8601), `seq`, `level`, `category`, `message`, `fields`,
  /// plus `error` and `stack` when present.
  static String jsonLine(LogRecord record, {LogSanitizer sanitizer = const LogSanitizer()}) => jsonEncode({
    'ts': record.timestamp.toUtc().toIso8601String(),
    'seq': record.sequence,
    'level': record.level.label,
    'category': record.category,
    'message': sanitizer.sanitizeText(record.message),
    'fields': sanitizer.sanitizeValue(record.fields),
    if (record.error != null) 'error': sanitizer.sanitizeText(record.error.toString()),
    if (record.stackTrace != null) 'stack': sanitizer.sanitizeText(record.stackTrace.toString()),
  });

  static String _clock(DateTime time) {
    String pad2(int value) => value.toString().padLeft(2, '0');
    String pad3(int value) => value.toString().padLeft(3, '0');
    return '${pad2(time.hour)}:${pad2(time.minute)}'
        ':${pad2(time.second)}.${pad3(time.millisecond)}';
  }
}
