// Module: lib/src/logger.dart
// Purpose: The logger, the sink contract and the router that decides which records survive and where they go.
// Author: liuchuancong
// Created: 2026-10-08
//
// Nothing here installs a global or touches a zone: the app owns one LogRouter and hands Loggers out of
// it, so a test can build its own router with its own sinks. That is the whole reason this package exists
// instead of calling print from feature code.

import 'dart:io';

import 'record.dart';

/// A destination for records. Implementations must not throw: a broken sink must not take down a request.
abstract interface class LogSink {
  void emit(LogRecord record);
}

/// Writes one line per record to stdout, redacted fields included.
final class ConsoleLogSink implements LogSink {
  ConsoleLogSink({StringSink? output}) : _output = output ?? stdout;

  final StringSink _output;

  @override
  void emit(LogRecord record) {
    _output.writeln(formatRecord(record));
  }
}

/// Renders a record as one line. Exposed so a UI sink and the console agree on the shape.
String formatRecord(LogRecord record) {
  final buffer = StringBuffer()
    ..write(record.timestamp.toUtc().toIso8601String())
    ..write(' ')
    ..write(record.level.name.toUpperCase())
    ..write(' [')
    ..write(record.logger)
    ..write('] ')
    ..write(record.message);
  if (record.fields.isNotEmpty) {
    buffer.write(' ${record.fields}');
  }
  if (record.error != null) {
    buffer.write(' error=${record.error}');
  }
  return buffer.toString();
}

/// Collects records in memory; used by tests and by the in-app log view.
final class MemoryLogSink implements LogSink {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void emit(LogRecord record) {
    records.add(record);
  }
}

/// Decides what to keep and where it goes.
///
/// Level filters are matched by logger prefix, longest match wins, so `network` can be debug while
/// `network.dio` stays warning.
final class LogRouter {
  LogRouter({required this.sinks, this.minimumLevel = LogLevel.info});

  final List<LogSink> sinks;
  final LogLevel minimumLevel;
  final Map<String, LogLevel> _prefixLevels = <String, LogLevel>{};

  /// Overrides the threshold for [prefix] and everything below it.
  void setLevel(String prefix, LogLevel level) {
    _prefixLevels[prefix] = level;
  }

  /// The threshold that applies to [loggerName].
  LogLevel levelFor(String loggerName) {
    var bestPrefix = '';
    var best = minimumLevel;
    for (final entry in _prefixLevels.entries) {
      if (loggerName.startsWith(entry.key) && entry.key.length > bestPrefix.length) {
        bestPrefix = entry.key;
        best = entry.value;
      }
    }
    return best;
  }

  bool isEnabled(String loggerName, LogLevel level) => level.index >= levelFor(loggerName).index;

  /// Creates a logger named [name].
  Logger logger(String name) => Logger(name: name, router: this);

  /// Sends [record] to every sink. Callers should check [isEnabled] first; this method does not filter.
  void dispatch(LogRecord record) {
    for (final sink in sinks) {
      sink.emit(record);
    }
  }
}

/// A named logging entry point bound to one [LogRouter].
final class Logger {
  Logger({required this.name, required this.router});

  final String name;
  final LogRouter router;

  /// A child logger whose name is this one plus [child], so level overrides and output stay hierarchical.
  Logger named(String child) => Logger(name: '$name.$child', router: router);

  bool isEnabled(LogLevel level) => router.isEnabled(name, level);

  void debug(String message, {Map<String, Object?>? fields}) =>
      _write(LogLevel.debug, message, fields: fields);

  void info(String message, {Map<String, Object?>? fields}) =>
      _write(LogLevel.info, message, fields: fields);

  void warning(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      _write(LogLevel.warning, message, fields: fields, error: error, stackTrace: stackTrace);

  void error(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      _write(LogLevel.error, message, fields: fields, error: error, stackTrace: stackTrace);

  void fatal(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      _write(LogLevel.fatal, message, fields: fields, error: error, stackTrace: stackTrace);

  void _write(
    LogLevel level,
    String message, {
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isEnabled(level)) {
      return;
    }
    router.dispatch(
      LogRecord(
        timestamp: DateTime.now().toUtc(),
        level: level,
        logger: name,
        message: message,
        error: error,
        stackTrace: stackTrace,
        fields: fields ?? const <String, Object?>{},
      ),
    );
  }
}
