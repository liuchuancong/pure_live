import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:live_storage/src/contracts/keyed_store.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';
import 'package:live_storage/src/database/pure_live_database.dart';

/// [KeyedStore] backed by one drift table.
///
/// The table is created on first use and holds JSON-encoded documents
/// alongside an `updated_at_ms` bookkeeping column. Writes commit inside
/// a database transaction; every mutation publishes on [changes], and
/// drift also broadcasts table updates from other connections, so a
/// second window stays in sync.
final class DbKeyedStore implements KeyedStore {
  /// A store over [tableName] in [database].
  new({required this.database, required this.tableName});

  /// The owning database.
  final PureLiveDatabase database;

  /// The SQL table this store reads and writes; a plain identifier the
  /// database validated before handing the name out.
  final String tableName;

  Future<void>? _creation;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Object?> read(String key) async {
    await _ensureTable();
    final row = await database
        .customSelect('SELECT value FROM $tableName WHERE key = ?', variables: [Variable.withString(key)])
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _decode(row.data['value'] as String, key);
  }

  @override
  Future<Map<String, Object?>> readAll() async {
    await _ensureTable();
    final rows = await database.customSelect('SELECT key, value FROM $tableName ORDER BY key').get();
    return {
      for (final row in rows)
        row.data['key'] as String: _decode(row.data['value'] as String, row.data['key'] as String),
    };
  }

  @override
  Future<List<String>> keys() async {
    await _ensureTable();
    final rows = await database.customSelect('SELECT key FROM $tableName ORDER BY key').get();
    return [for (final row in rows) row.data['key'] as String];
  }

  @override
  Future<void> write(String key, Object? value) async {
    if (value == null) {
      await remove(key);
      return;
    }
    await _ensureTable();
    final encoded = _encode(value);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.runInTransaction(() async {
      await database.customStatement(
        'INSERT INTO $tableName (key, value, updated_at_ms) '
        'VALUES (?, ?, ?) '
        'ON CONFLICT(key) DO UPDATE SET '
        'value = excluded.value, updated_at_ms = excluded.updated_at_ms',
        [key, encoded, now],
      );
    });
    _changes.add(null);
  }

  @override
  Future<void> remove(String key) async {
    await _ensureTable();
    await database.customStatement('DELETE FROM $tableName WHERE key = ?', [key]);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    await _ensureTable();
    await database.customStatement('DELETE FROM $tableName');
    _changes.add(null);
  }

  /// Creates the table once per store; the result is replayed for the
  /// handle's lifetime.
  Future<void> _ensureTable() => _creation ??= database.customStatement(
    'CREATE TABLE IF NOT EXISTS $tableName ('
    'key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, '
    'updated_at_ms INTEGER NOT NULL)',
  );

  Object? _decode(String raw, String key) {
    try {
      return jsonDecode(raw) as Object?;
    } on FormatException catch (error) {
      throw StorageCorruptedException('$tableName key "$key" holds invalid JSON', cause: error);
    }
  }

  String _encode(Object? value) {
    // A non-encodable value is a programming error at the call site; the
    // JsonUnsupportedObjectError propagates unchanged.
    return jsonEncode(value);
  }
}
