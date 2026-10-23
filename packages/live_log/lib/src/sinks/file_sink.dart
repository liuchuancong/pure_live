import 'dart:async';
import 'dart:io';

import 'package:live_log/src/formatter.dart';
import 'package:live_log/src/record.dart';
import 'package:live_log/src/sanitizer.dart';
import 'package:live_log/src/sink.dart';
import 'package:path/path.dart' as p;

/// Writes formatted records to `<directory>/<baseName>.log`, rotating to
/// `<baseName>.1.log`, `<baseName>.2.log`, … when the live file passes
/// [maxFileBytes] and keeping at most [maxFiles] files including the live
/// one.
///
/// All writes go through one serial queue — concurrent `log()` calls never
/// interleave file operations. On the first I/O failure (disk full,
/// unwritable directory) the sink degrades permanently: further records
/// are dropped silently, and the failure is never re-logged, which would
/// recurse. Await [flushed] in tests and shutdown paths.
final class FileSink implements LogSink {
  /// A rotating sink under [directory] (created lazily on first write).
  ///
  /// [baseName] is the log file base name — the host application's
  /// namespace, supplied by the caller: the sink writes `<baseName>.log`
  /// and, on rotation, the `<baseName>.<index>.log` files. This package
  /// is reusable and names no product itself.
  new(
    this.directory, {
    required this.baseName,
    this.maxFileBytes = 5 * 1024 * 1024,
    this.maxFiles = 5,
    this.sanitizer = const LogSanitizer(),
  });

  /// Directory holding the log files.
  final Directory directory;

  /// File name stem; the host application's namespace. Files are
  /// `<baseName>.log`, `<baseName>.1.log`, …
  final String baseName;

  /// Size that triggers a rotation of the current file.
  final int maxFileBytes;

  /// Total files kept, the live one included.
  final int maxFiles;

  /// Applied to error text while formatting records.
  final LogSanitizer sanitizer;

  static const int _newLineBytes = 1;

  IOSink? _output;
  int _writtenBytes = 0;
  Future<void> _queue = Future<void>.value();
  bool _closed = false;
  bool _degraded = false;

  /// A future that completes when every queued write has settled.
  Future<void> get flushed => _queue;

  /// The live log file path, `<baseName>.log` inside [directory].
  File get currentFile => File(p.join(directory.path, '$baseName.log'));

  /// Whether the sink gave up after an I/O failure; degraded sinks drop
  /// everything silently.
  bool get isDegraded => _degraded;

  @override
  void write(LogRecord record) {
    if (_closed || _degraded) {
      return;
    }
    _queue = _queue.then((_) => _writeOne(record));
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _queue;
    await _releaseOutput();
  }

  Future<void> _writeOne(LogRecord record) async {
    try {
      var output = _output;
      if (output == null) {
        await directory.create(recursive: true);
        final file = currentFile;
        output = file.openWrite(mode: FileMode.append);
        _output = output;
        _writtenBytes = file.existsSync() ? file.lengthSync() : 0;
      }
      final line = LogFormatter.plain(record, sanitizer: sanitizer);
      output
        ..write(line)
        ..write('\n');
      _writtenBytes += line.length + _newLineBytes;
      if (_writtenBytes >= maxFileBytes) {
        await _rotate();
      }
    } on Object {
      await _degrade();
    }
  }

  Future<void> _rotate() async {
    await _releaseOutput();
    for (var index = maxFiles - 1; index >= 1; index--) {
      final from = _fileAt(index);
      if (!from.existsSync()) {
        continue;
      }
      if (index == maxFiles - 1) {
        // The oldest file falls off the edge.
        from.deleteSync();
        continue;
      }
      from.renameSync(_fileAt(index + 1).path);
    }
    final current = currentFile;
    if (current.existsSync()) {
      current.renameSync(_fileAt(1).path);
    }
    _writtenBytes = 0;
  }

  Future<void> _degrade() async {
    _degraded = true;
    await _releaseOutput();
  }

  /// Flushes and closes the current IOSink, swallowing secondary errors.
  Future<void> _releaseOutput() async {
    final output = _output;
    _output = null;
    _writtenBytes = 0;
    if (output == null) {
      return;
    }
    try {
      await output.flush();
      await output.close();
    } on Object {
      // Secondary failure while releasing a failing sink: ignore.
    }
  }

  File _fileAt(int index) => File(p.join(directory.path, '$baseName.$index.log'));
}
