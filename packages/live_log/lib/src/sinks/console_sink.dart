import 'dart:developer' as developer;
import 'dart:io';

import 'package:live_log/src/formatter.dart';
import 'package:live_log/src/record.dart';
import 'package:live_log/src/sanitizer.dart';
import 'package:live_log/src/sink.dart';

/// Forwards formatted records to `dart:developer` `log()`.
///
/// Records show up in IDE consoles and DevTools with proper severity and
/// category filtering. Prefer this sink in Flutter sessions; it never
/// writes to process stdout.
final class DeveloperConsoleSink implements LogSink {
  /// A developer-log sink; [sanitizer] is applied to error text while
  /// formatting.
  const new({this.sanitizer = const LogSanitizer()});

  /// Applied to error text while formatting records.
  final LogSanitizer sanitizer;

  @override
  void write(LogRecord record) {
    developer.log(
      LogFormatter.plain(record, sanitizer: sanitizer),
      time: record.timestamp,
      level: record.level.severity,
      name: record.category.isEmpty ? 'live_log' : record.category,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  @override
  Future<void> close() async {
    // The developer log belongs to the VM; nothing to release.
  }
}

/// Writes formatted records to stdout, one line per record.
///
/// Use in CLI tools and desktop debug runs. Release builds usually keep
/// only the file and memory sinks.
final class StdoutConsoleSink implements LogSink {
  /// A stdout sink; [sanitizer] is applied to error text while formatting.
  const new({this.sanitizer = const LogSanitizer()});

  /// Applied to error text while formatting records.
  final LogSanitizer sanitizer;

  @override
  void write(LogRecord record) {
    stdout.writeln(LogFormatter.plain(record, sanitizer: sanitizer));
  }

  @override
  Future<void> close() async {
    // stdout belongs to the process; nothing to release.
  }
}
