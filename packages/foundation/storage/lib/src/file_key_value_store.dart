// Module: lib/src/file_key_value_store.dart
// Purpose: A JSON-file KeyValueStore that refuses to overwrite a file it could not read.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/services/cache.md (two-level cache) and the README rule "统一 kv 与安全存储,承载设置迁移边界".
// The composition root passes the path; this package does not resolve application directories, which stays
// pure_live_files' job, so an L0 package does not need an L0-to-L0 edge.

import 'dart:convert';
import 'dart:io';

import 'stores.dart';

/// The file exists but is not the `{"key": value}` object this store writes.
///
/// Reported instead of being treated as empty: a settings file truncated to `{}` is user data lost, and the
/// next write would have made it permanent. The host decides whether to restore a backup or start over.
final class StoreCorruptedException implements Exception {
  const StoreCorruptedException(this.filePath, this.reason);

  final String filePath;
  final String reason;

  @override
  String toString() => 'StoreCorruptedException($filePath: $reason)';
}

/// A [KeyValueStore] held in one JSON file, loaded on first use and written through on every change.
///
/// Operations are serialised through one queue: two extensions writing at the same moment would otherwise
/// interleave read-modify-write on the same file and one of them would lose its row.
final class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore({required this.filePath, this.indent = false});

  final String filePath;

  /// Pretty-printed output is for a file a human is expected to open while debugging.
  final bool indent;

  Map<String, Object?>? _entries;
  Future<void> _queue = Future<void>.value();

  @override
  Future<Object?> read(String key) => _serialised(() async => (await _load())[key]);

  @override
  Future<List<String>> keys() => _serialised(() async => (await _load()).keys.toList(growable: false));

  @override
  Future<void> write(String key, Object? value) => _serialised(() async {
    final next = Map<String, Object?>.from(await _load())..[key] = value;
    // Encoding the candidate first is what makes a bad value a no-op: nothing on disk and nothing in
    // memory changes, so a caller cannot corrupt its own store by passing one unserialisable field.
    final encoded = _encode(next);
    _entries = next;
    await _replaceFile(encoded);
  });

  @override
  Future<void> remove(String key) => _serialised(() async {
    final current = await _load();
    if (!current.containsKey(key)) {
      return;
    }
    final next = Map<String, Object?>.from(current)..remove(key);
    final encoded = _encode(next);
    _entries = next;
    await _replaceFile(encoded);
  });

  @override
  Future<void> clear() => _serialised(() async {
    if ((await _load()).isEmpty) {
      return;
    }
    final encoded = _encode(const <String, Object?>{});
    _entries = <String, Object?>{};
    await _replaceFile(encoded);
  });

  Future<T> _serialised<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    // A failed operation must not wedge the queue; the caller still gets its own error.
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, Object?>> _load() async {
    final loaded = _entries;
    if (loaded != null) {
      return loaded;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return _entries = <String, Object?>{};
    }
    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      // An empty file is what being killed mid-first-write leaves behind, and nothing was ever stored in
      // it, so reading it as empty is not a guess about someone's data.
      return _entries = <String, Object?>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw StoreCorruptedException(filePath, error.message);
    }
    if (decoded is! Map) {
      throw StoreCorruptedException(filePath, 'the top level is a ${decoded.runtimeType}, not an object');
    }
    return _entries = Map<String, Object?>.from(decoded);
  }

  String _encode(Map<String, Object?> entries) {
    final encoder = indent ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
    try {
      return encoder.convert(entries);
    } on JsonUnsupportedObjectError catch (error) {
      throw ArgumentError.value(
        error.unsupportedObject,
        'value',
        'FileKeyValueStore persists JSON-encodable values only',
      );
    }
  }

  Future<void> _replaceFile(String encoded) async {
    final file = File(filePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    // Write-then-rename: a reader either sees the whole previous file or the whole new one, and a crash
    // leaves the previous file in place instead of a half-written one.
    final temp = File('$filePath.tmp');
    await temp.writeAsString(encoded, flush: true);
    await temp.rename(file.path);
  }
}
