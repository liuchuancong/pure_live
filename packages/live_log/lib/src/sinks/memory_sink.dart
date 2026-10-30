import 'dart:collection';

import 'package:live_log/src/model/formatter.dart';
import 'package:live_log/src/model/level.dart';
import 'package:live_log/src/model/record.dart';
import 'package:live_log/src/model/sink.dart';
import 'package:live_log/src/pipeline/sanitizer.dart';

/// Keeps the most recent records in a fixed-capacity ring buffer.
///
/// Backs the diagnostics view and crash reports: query recent records,
/// filter by level or category, and export as text or JSON Lines.
/// Bounded by design — a long-running TV session must not grow without
/// limit.
final class MemorySink implements LogSink {
  /// A sink retaining the newest [capacity] records.
  new({int capacity = 500}) : _capacity = capacity, _records = ListQueue<LogRecord>(capacity);

  /// Maximum number of retained records. Lowering it forgets the oldest
  /// records at once, so a live view shrinks with the setting.
  int get capacity => _capacity;

  set capacity(int value) {
    _capacity = value;
    while (_records.length > _capacity) {
      _records.removeFirst();
    }
  }

  int _capacity;

  final ListQueue<LogRecord> _records;

  /// The retained records, oldest first.
  List<LogRecord> get records => List.unmodifiable(_records);

  /// Returns retained records matching [minLevel] and [categoryPrefix].
  ///
  /// [categoryPrefix] matches the exact category or any descendant
  /// (`sites` matches `sites` and `sites.bilibili`).
  List<LogRecord> query({LogLevel? minLevel, String? categoryPrefix}) => [
    for (final record in _records)
      if (_matches(record, minLevel, categoryPrefix)) record,
  ];

  /// Exports matching records as JSON Lines (one JSON object per line),
  /// re-sanitised with [sanitizer] before leaving the process.
  String exportJsonLines({LogSanitizer sanitizer = const LogSanitizer(), LogLevel? minLevel, String? categoryPrefix}) {
    final selected = query(minLevel: minLevel, categoryPrefix: categoryPrefix);
    return selected.map((record) => LogFormatter.jsonLine(record, sanitizer: sanitizer)).join('\n');
  }

  /// Exports matching records as formatted text, re-sanitised with
  /// [sanitizer].
  String exportText({LogSanitizer sanitizer = const LogSanitizer(), LogLevel? minLevel, String? categoryPrefix}) {
    final selected = query(minLevel: minLevel, categoryPrefix: categoryPrefix);
    return selected.map((record) => LogFormatter.plain(record, sanitizer: sanitizer)).join('\n');
  }

  /// Drops all retained records.
  void clear() => _records.clear();

  @override
  void write(LogRecord record) {
    if (_records.length >= capacity) {
      _records.removeFirst();
    }
    _records.add(record);
  }

  @override
  Future<void> close() async {
    clear();
  }

  static bool _matches(LogRecord record, LogLevel? minLevel, String? categoryPrefix) {
    if (minLevel != null && !record.level.isAtLeast(minLevel)) {
      return false;
    }
    if (categoryPrefix != null &&
        categoryPrefix.isNotEmpty &&
        record.category != categoryPrefix &&
        !record.category.startsWith('$categoryPrefix.')) {
      return false;
    }
    return true;
  }
}
