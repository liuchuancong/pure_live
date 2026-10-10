// Module: lib/src/record.dart
// Purpose: The log level vocabulary and the immutable record every sink receives.
// Author: liuchuancong
// Created: 2026-10-08
//
// Records are values, not strings: a sink decides how to render, and a structured field stays queryable.
// Timestamps are normalized to UTC because logs get merged across devices and time zones.

import 'redaction.dart';

/// Severity of a log record.
enum LogLevel { debug, info, warning, error, fatal }

/// A single log entry.
final class LogRecord {
  LogRecord({
    required DateTime timestamp,
    required this.level,
    required this.logger,
    required this.message,
    this.error,
    this.stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) : timestamp = timestamp.toUtc(),
       fields = redactFields(fields);

  /// When the record was produced; always UTC.
  final DateTime timestamp;
  final LogLevel level;

  /// Dotted logger path, for example `network.dio`.
  final String logger;
  final String message;

  /// The object that was thrown, kept as a value so a sink can decide how much to render.
  final Object? error;
  final StackTrace? stackTrace;

  /// Structured context. Credentials are scrubbed at construction, not at render time, so a sink cannot
  /// forget to do it and a file written on a device never carries a token.
  final Map<String, Object?> fields;

  bool get isErrorOrWorse => level.index >= LogLevel.error.index;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.name,
      'logger': logger,
      'message': message,
      if (error != null) 'error': '$error',
      if (stackTrace != null) 'stackTrace': '$stackTrace',
      if (fields.isNotEmpty) 'fields': fields,
    };
  }
}

/// Parses a level name, returning null for anything unrecognized rather than guessing.
LogLevel? logLevelFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final level in LogLevel.values) {
    if (level.name == name.toLowerCase()) {
      return level;
    }
  }
  return null;
}
