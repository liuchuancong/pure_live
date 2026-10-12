import 'dart:async';
import 'dart:convert';

import 'package:live_storage/src/contracts/keyed_store.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';
import 'package:live_storage/src/database/pure_live_database.dart';

/// [KeyedStore] backed by one drift table plus an in-memory mirror.
///
/// Like a Hive box: the table loads fully at [open], everything after
/// that answers from memory while writes go to sqlite. Every committed
/// mutation publishes a [KeyedEvent] on [watch].
///
/// Puts are single statements in their own right — do not wrap them in
/// an outer transaction: a rollback there cannot un-ring the in-memory
/// mirror.
final class DbKeyedStore implements KeyedStore {
  new _({required this.database, required this.tableName});

  /// The plain SQL identifier a table name must be — names are
  /// interpolated into DDL/DML, so anything else is refused before it
  /// can become an injection.
  static void checkTableName(String name) {
    if (!_namePattern.hasMatch(name)) {
      throw StorageValidationException('table name must be a plain identifier, got "$name"');
    }
  }

  static final RegExp _namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,63}$');

  /// Opens [tableName], creating the table when missing and loading its
  /// rows into memory. A row that no longer decodes fails the open — a
  /// damaged table surfaces here, not as a missing value later.
  static Future<DbKeyedStore> open({required PureLiveDatabase database, required String tableName}) async {
    checkTableName(tableName);
    final store = DbKeyedStore._(database: database, tableName: tableName);
    await store._ensureTable();
    final rows = await store.database.customSelect('SELECT key, value FROM $tableName').get();
    for (final row in rows) {
      final key = row.data['key'] as String;
      store._values[key] = store._decode(row.data['value'] as String, key);
    }
    return store;
  }

  /// The owning database.
  final PureLiveDatabase database;

  /// The SQL table behind this store.
  final String tableName;

  final Map<String, Object?> _values = <String, Object?>{};
  final _changes = StreamController<KeyedEvent>.broadcast();
  Future<void>? _creation;

  @override
  Iterable<String> get keys => _values.keys;

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  T? get<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value == null) {
      return defaultValue;
    }
    return value as T;
  }

  @override
  Future<void> put(String key, Object? value) async {
    if (value == null) {
      await delete(key);
      return;
    }
    final previous = _values[key];
    _values[key] = value;
    try {
      await _ensureTable();
      await database.customStatement(
        'INSERT INTO $tableName (key, value, updated_at_ms) '
        'VALUES (?, ?, ?) '
        'ON CONFLICT(key) DO UPDATE SET '
        'value = excluded.value, updated_at_ms = excluded.updated_at_ms',
        [key, _encode(value), DateTime.now().millisecondsSinceEpoch],
      );
    } on Object {
      if (previous == null) {
        _values.remove(key);
      } else {
        _values[key] = previous;
      }
      rethrow;
    }
    _changes.add(KeyedEvent(key: key, deleted: false, value: value));
  }

  @override
  Future<void> delete(String key) async {
    if (!_values.containsKey(key)) {
      return;
    }
    final previous = _values.remove(key);
    try {
      await _ensureTable();
      await database.customStatement('DELETE FROM $tableName WHERE key = ?', [key]);
    } on Object {
      _values[key] = previous;
      rethrow;
    }
    _changes.add(KeyedEvent(key: key, deleted: true));
  }

  @override
  Future<void> clear() async {
    final saved = Map<String, Object?>.of(_values);
    if (saved.isEmpty) {
      return;
    }
    _values.clear();
    try {
      await _ensureTable();
      await database.customStatement('DELETE FROM $tableName');
    } on Object {
      _values.addAll(saved);
      rethrow;
    }
    for (final key in saved.keys) {
      _changes.add(KeyedEvent(key: key, deleted: true));
    }
  }

  @override
  Stream<KeyedEvent> watch({String? key}) =>
      key == null ? _changes.stream : _changes.stream.where((event) => event.key == key);

  /// Creates the table once per store; the result is replayed for the
  /// handle's lifetime.
  Future<void> _ensureTable() => _creation ??= database.customStatement(
    'CREATE TABLE IF NOT EXISTS $tableName '
    '(key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, '
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
