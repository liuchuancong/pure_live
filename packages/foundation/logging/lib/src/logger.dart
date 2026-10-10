// Module: lib/src/logger.dart
// Purpose: The logger, the sink contract and the router that decides which records survive and where they go.
// Author: liuchuancong
// Created: 2026-10-08
//
// Nothing here installs a global or touches a zone: the app owns one LogRouter and hands Loggers out of
// it, so a test can build its own router with its own sinks. That is the whole reason this package exists
// instead of calling print from feature code.

import 'dart:convert';
import 'dart:io';

import 'package:pure_live_utils/pure_live_utils.dart';

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
///
/// Bounded by default: an in-memory log view that keeps every record for the lifetime of a session is the out
/// of memory report it is supposed to explain. [droppedCount] says how much of the history the view is missing.
final class MemoryLogSink implements LogSink {
  MemoryLogSink({this.capacity = 1000}) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must keep at least one record');
    }
  }

  final int capacity;

  /// Oldest first.
  final List<LogRecord> records = <LogRecord>[];

  int _dropped = 0;

  int get droppedCount => _dropped;

  bool get isTruncated => _dropped > 0;

  @override
  void emit(LogRecord record) {
    if (records.length >= capacity) {
      records.removeAt(0);
      _dropped++;
    }
    records.add(record);
  }

  void clear() {
    records.clear();
    _dropped = 0;
  }
}

/// Renders a record as one JSON object, for a parsed attachment rather than a read line.
String formatRecordJson(LogRecord record) => jsonEncode(record.toJson());

/// Decides what to keep and where it goes.
///
/// Level filters are matched by logger prefix, longest match wins, so `network` can be debug while
/// `network.dio` stays warning.
final class LogRouter {
  LogRouter({required this.sinks, this.minimumLevel = LogLevel.info, Clock? clock, this.onDispatchError})
    : _clock = clock ?? systemClock;

  final List<LogSink> sinks;
  final LogLevel minimumLevel;
  final Clock _clock;

  /// Notified when a sink throws, with the sink and the error. A sink contract says it must not throw, and a
  /// third-party one will; without this hook the only sign is a log file that quietly stopped.
  final void Function(LogSink sink, Object error)? onDispatchError;

  final Map<String, LogLevel> _prefixLevels = <String, LogLevel>{};

  /// The current time a record is stamped with. Injected so a test can assert a timestamp without sleeping.
  DateTime now() => _clock();

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
  ///
  /// One sink's failure never stops the others: the console still gets the line when the file is locked, and
  /// the throwing sink is reported through [onDispatchError] rather than reaching the caller's code path.
  void dispatch(LogRecord record) {
    for (final sink in sinks) {
      try {
        sink.emit(record);
      } on Object catch (error) {
        onDispatchError?.call(sink, error);
      }
    }
  }
}

/// A named logging entry point bound to one [LogRouter].
final class Logger {
  Logger({required this.name, required this.router, Map<String, Object?> context = const <String, Object?>{}})
    : context = Map<String, Object?>.unmodifiable(context);

  final String name;
  final LogRouter router;

  /// Fields merged into every record from this logger, for a session or a room that many lines belong to.
  final Map<String, Object?> context;

  /// A child logger whose name is this one plus [child], so level overrides and output stay hierarchical.
  Logger named(String child) => Logger(name: '$name.$child', router: router, context: context);

  /// A logger that adds [fields] to everything it writes. The context is scrubbed like any other field, so a
  /// token put here is still not logged.
  Logger withFields(Map<String, Object?> fields) {
    if (fields.isEmpty) {
      return this;
    }
    return Logger(name: name, router: router, context: <String, Object?>{...context, ...fields});
  }

  bool isEnabled(LogLevel level) => router.isEnabled(name, level);

  void debug(String message, {Map<String, Object?>? fields}) => _write(LogLevel.debug, message, fields: fields);

  void info(String message, {Map<String, Object?>? fields}) => _write(LogLevel.info, message, fields: fields);

  void warning(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      _write(LogLevel.warning, message, fields: fields, error: error, stackTrace: stackTrace);

  void error(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      _write(LogLevel.error, message, fields: fields, error: error, stackTrace: stackTrace);

  void fatal(String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) =>
      _write(LogLevel.fatal, message, fields: fields, error: error, stackTrace: stackTrace);

  void _write(LogLevel level, String message, {Map<String, Object?>? fields, Object? error, StackTrace? stackTrace}) {
    if (!isEnabled(level)) {
      return;
    }
    router.dispatch(
      LogRecord(
        timestamp: router.now(),
        level: level,
        logger: name,
        message: message,
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{...context, ...?fields},
      ),
    );
  }
}
