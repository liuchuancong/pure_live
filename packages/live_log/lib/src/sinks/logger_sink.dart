import 'package:live_log/src/level.dart';
import 'package:live_log/src/record.dart';
import 'package:live_log/src/sanitizer.dart';
import 'package:live_log/src/sink.dart';
import 'package:logger/logger.dart' as logger;

/// Writes records through the `logger` package's [logger.PrettyPrinter].
///
/// Console output is colourised and emoji-tagged per severity, with the
/// category and structured fields rendered inline; errors and stack traces
/// get the printer's boxed multi-line layout. Records arriving here are
/// already sanitised; the sanitizer is still applied to the raw error text
/// and stack trace, which the record carries unsanitised.
final class LoggerConsoleSink implements LogSink {
  /// A pretty-printed console sink; [sanitizer] is applied to error text
  /// and stack traces, [lineLength] caps the printer's frame width.
  const new({
    this.sanitizer = const LogSanitizer(),
    this.lineLength = 120,
    this.colors = true,
    this.printEmojis = true,
  });

  /// Applied to error text and stack traces while formatting records.
  final LogSanitizer sanitizer;

  /// Maximum width of the printer's boxed output.
  final int lineLength;

  /// Whether ANSI colours are emitted; disable for consoles without
  /// colour support.
  final bool colors;

  /// Whether a per-level emoji prefixes each line.
  final bool printEmojis;

  logger.Logger get _effective => logger.Logger(
    printer: logger.PrettyPrinter(
      methodCount: 0,
      lineLength: lineLength,
      colors: colors,
      printEmojis: printEmojis,
      dateTimeFormat: logger.DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // The record already carries the level; every call goes through
    // log() directly so the filter must not drop anything.
    filter: logger.DevelopmentFilter(),
  );

  @override
  void write(LogRecord record) {
    if (!record.level.isRecordLevel) {
      return;
    }
    final buffer = StringBuffer()
      ..write('[')
      ..write(record.category)
      ..write('] ')
      ..write(record.message);
    if (record.fields.isNotEmpty) {
      buffer
        ..write(' {')
        ..write(record.fields.entries.map((entry) => '${entry.key}: ${entry.value}').join(', '))
        ..write('}');
    }
    final error = record.error;
    _effective.log(
      _severity(record.level),
      buffer.toString(),
      error: error == null
          ? null
          // Wraps the sanitised text so the printer shows exactly it, not
          // an ArgumentError wrapper label.
          : _PreformattedError(sanitizer.sanitizeText(error.toString())),
      stackTrace: record.stackTrace,
      time: record.timestamp,
    );
  }

  @override
  Future<void> close() async {
    // stdout belongs to the process; nothing to release.
  }

  logger.Level _severity(LogLevel level) => switch (level) {
    LogLevel.trace => logger.Level.trace,
    LogLevel.debug => logger.Level.debug,
    LogLevel.info => logger.Level.info,
    LogLevel.warning => logger.Level.warning,
    LogLevel.error => logger.Level.error,
    LogLevel.fatal => logger.Level.fatal,
    LogLevel.off => logger.Level.off,
  };
}

/// Presents [text] as the whole error line in the printer's error box.
final class _PreformattedError {
  const new(this.text);

  final String text;

  @override
  String toString() => text;
}
