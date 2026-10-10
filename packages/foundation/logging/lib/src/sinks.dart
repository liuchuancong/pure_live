// Module: lib/src/sinks.dart
// Purpose: The sinks a real device needs - a rotating file, a rate limiter, an async buffer and JSON lines -
// each bounded, because a log that can grow without limit is the failure it is recording.
// Author: liuchuancong
// Created: 2026-10-11
//
// Two rules run through every type here. A sink never throws: the caller is a feature in the middle of
// something failing, and a sink that throws replaces the original error with a logging one. And nothing is
// unbounded: not the file, not the queue, not the number of identical lines per second, not the memory copy.
// When a bound bites, the sink says so in its own counters rather than silently dropping.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'logger.dart';
import 'record.dart';

/// A file sink that keeps at most [maxFiles] files of [maxBytesPerFile] each.
///
/// Rotation happens on write, not on a timer, because the size is what fills the disk. The newest file keeps
/// the configured name and the older ones gain a `.1`, `.2` suffix, which is what a reader on the device
/// expects and what a bug-report picker can glob.
final class RotatingFileSink implements LogSink, Disposable {
  RotatingFileSink({
    required this.filePath,
    this.maxBytesPerFile = 512 * 1024,
    this.maxFiles = 3,
    this.formatter = formatRecord,
  }) {
    if (maxFiles < 1) {
      throw ArgumentError.value(maxFiles, 'maxFiles', 'must keep at least the active file');
    }
    if (maxBytesPerFile < 1) {
      throw ArgumentError.value(maxBytesPerFile, 'maxBytesPerFile', 'cannot be smaller than one line');
    }
  }

  final String filePath;
  final int maxBytesPerFile;
  final int maxFiles;
  final String Function(LogRecord record) formatter;

  IOSink? _sink;
  int _writtenBytes = 0;
  int _rotations = 0;
  int _dropped = 0;
  bool _closed = false;
  String? _lastFailure;

  /// How many times the active file was rolled over.
  int get rotations => _rotations;

  /// Records lost to a write failure or a closed sink. A non-zero count means the file is not a transcript.
  int get droppedCount => _dropped;

  /// The reason of the most recent write failure, if any, so a UI can show why the log stopped.
  String? get lastFailure => _lastFailure;

  int get bytesWritten => _writtenBytes;

  @override
  void emit(LogRecord record) {
    if (_closed) {
      _dropped++;
      return;
    }
    final line = '${formatter(record)}\n';
    try {
      final target = _sink ??= _open();
      target.write(line);
      _writtenBytes += utf8.encode(line).length;
      if (_writtenBytes >= maxBytesPerFile) {
        _rotate();
      }
    } on Object catch (error) {
      // A locked file, a full disk, a permission change: report it once through the counters and keep the
      // caller's own failure as the one that gets seen.
      _lastFailure = '$error';
      _dropped++;
    }
  }

  Future<void> flush() async {
    try {
      await _sink?.flush();
    } on Object catch (error) {
      _lastFailure = '$error';
    }
  }

  void _rotate() {
    unawaited(flush());
    try {
      _sink?.close();
    } on Object {
      // An already-broken sink has nothing left to close; the rename below is the part that matters.
    }
    _sink = null;
    _writtenBytes = 0;
    _rotations++;
    final oldest = '$filePath.${maxFiles - 1}';
    if (File(oldest).existsSync()) {
      File(oldest).deleteSync();
    }
    for (var index = maxFiles - 2; index >= 1; index--) {
      final from = File('$filePath.$index');
      if (from.existsSync()) {
        from.renameSync('$filePath.${index + 1}');
      }
    }
    final active = File(filePath);
    if (active.existsSync()) {
      active.renameSync('$filePath.1');
    }
  }

  IOSink _open() {
    final file = File(filePath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    _writtenBytes = file.existsSync() ? file.lengthSync() : 0;
    return file.openWrite(mode: FileMode.append);
  }

  @override
  void dispose() {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      unawaited(_sink?.close());
    } on Object catch (error) {
      _lastFailure = '$error';
    }
    _sink = null;
  }
}

/// Forwards at most [maxPerWindow] records with the same fingerprint per [window], then counts the rest.
///
/// The fingerprint is level + logger + message, deliberately without the field values: a retry loop that logs
/// the same sentence with a different url every time is one storm, and a per-field key would turn it into
/// thousands of distinct allowed records.
final class RateLimitedSink implements LogSink {
  RateLimitedSink({
    required LogSink inner,
    this.maxPerWindow = 20,
    this.window = const Duration(seconds: 10),
    this.reportSuppressedEvery = const Duration(seconds: 30),
    Clock? clock,
  }) : _inner = inner,
       _clock = clock ?? systemClock {
    if (maxPerWindow < 1) {
      throw ArgumentError.value(maxPerWindow, 'maxPerWindow', 'must let at least one record through');
    }
  }

  final LogSink _inner;
  final int maxPerWindow;
  final Duration window;
  final Duration reportSuppressedEvery;
  final Clock _clock;

  final Map<String, _Window> _windows = <String, _Window>{};
  int _suppressed = 0;
  DateTime? _lastReport;

  /// Records dropped by the limiter so far.
  int get suppressedCount => _suppressed;

  /// Distinct fingerprints currently being paced.
  int get trackedFingerprints => _windows.length;

  @override
  void emit(LogRecord record) {
    final key = '${record.level.name}|${record.logger}|${record.message}';
    final now = _clock();
    final current = _windows[key];
    if (current == null || !now.isBefore(current.until)) {
      _windows[key] = _Window(now.add(window), 1);
      if (_windows.length > _maxTracked) {
        _evictOld(now);
      }
      _inner.emit(record);
      return;
    }
    if (current.count >= maxPerWindow) {
      _suppressed++;
      _maybeReportSuppression(now, key);
      return;
    }
    _windows[key] = _Window(current.until, current.count + 1);
    _inner.emit(record);
  }

  /// A line that names the fingerprint and how many were hidden, so the log itself shows the gap instead of
  /// looking calm.
  void _maybeReportSuppression(DateTime now, String key) {
    final last = _lastReport;
    if (last != null && now.difference(last) < reportSuppressedEvery) {
      return;
    }
    _lastReport = now;
    _inner.emit(
      LogRecord(
        timestamp: now,
        level: LogLevel.warning,
        logger: 'logging.rateLimit',
        message: 'records suppressed by the rate limiter',
        fields: <String, Object?>{'suppressed': _suppressed, 'windowSeconds': window.inSeconds, 'example': key},
      ),
    );
  }

  static const int _maxTracked = 256;

  void _evictOld(DateTime now) {
    for (final entry in _windows.entries.toList(growable: false)) {
      if (entry.value.until.isBefore(now)) {
        _windows.remove(entry.key);
      }
    }
    if (_windows.length > _maxTracked) {
      _windows.clear();
    }
  }

  void reset() {
    _windows.clear();
    _suppressed = 0;
    _lastReport = null;
  }
}

final class _Window {
  const _Window(this.until, this.count);

  final DateTime until;
  final int count;
}

/// Queues records and drains them on a timer, so a slow disk is not paid for by the caller.
///
/// The queue is bounded and the newest record is kept when it overflows: whoever reads the log wants the
/// current state, and the oldest lines are usually already understood. Draining is a swap, never a merge, so
/// the original order of the records that made it is preserved.
final class BufferedSink implements LogSink, Disposable {
  BufferedSink({required LogSink inner, this.flushAfter = const Duration(seconds: 2), this.maxQueue = 512})
    : _inner = inner {
    if (maxQueue < 1) {
      throw ArgumentError.value(maxQueue, 'maxQueue', 'must hold at least one record');
    }
  }

  final LogSink _inner;
  final Duration flushAfter;
  final int maxQueue;

  final List<LogRecord> _queue = <LogRecord>[];
  Timer? _timer;
  int _dropped = 0;
  bool _closed = false;

  int get queuedCount => _queue.length;

  /// Records lost because the queue was full, or because they arrived after [dispose].
  int get droppedCount => _dropped;

  @override
  void emit(LogRecord record) {
    if (_closed) {
      _dropped++;
      return;
    }
    if (_queue.length >= maxQueue) {
      // Drop the oldest, and count it.
      _queue.removeAt(0);
      _dropped++;
    }
    _queue.add(record);
    _timer ??= Timer(flushAfter, flush);
  }

  /// Hands the queue to the inner sink. Safe to call from a timer, a shutdown hook or both.
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_queue.isEmpty) {
      return;
    }
    final batch = List<LogRecord>.of(_queue);
    _queue.clear();
    for (final record in batch) {
      try {
        _inner.emit(record);
      } on Object {
        // The inner sink contract says it must not throw; if it does, the rest of the batch still goes.
        _dropped++;
      }
    }
  }

  @override
  void dispose() {
    if (_closed) {
      return;
    }
    flush();
    _closed = true;
  }
}

/// Writes one JSON object per line, for a log view or an attachment that gets parsed rather than read.
final class JsonLineSink implements LogSink {
  JsonLineSink({required StringSink output, this.includeStackTrace = true}) : _output = output;

  final StringSink _output;

  /// Off for a device log whose stack lines would dominate the byte budget; the record keeps the object, so a
  /// caller that wants it renders it elsewhere.
  final bool includeStackTrace;

  @override
  void emit(LogRecord record) {
    final json = record.toJson();
    if (!includeStackTrace) {
      json.remove('stackTrace');
    }
    _output.writeln(jsonEncode(json));
  }
}
