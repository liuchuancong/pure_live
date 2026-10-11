import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:live_storage/src/contracts/preferences_store.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';
import 'package:live_storage/src/database/pure_live_database.dart';

/// [PreferencesStore] backed by the drift preferences table.
///
/// Writes commit inside a database transaction and maintain the
/// `updated_at_ms` bookkeeping column. Every mutation publishes on
/// [changes]; drift also broadcasts table updates from other
/// connections, so a second window stays in sync.
final class DbPreferencesStore implements PreferencesStore {
  /// A store over [database].
  new(this.database);

  /// The owning database.
  final PureLiveDatabase database;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Object?> read(String key) async {
    final row = await database
        .customSelect(
          'SELECT value FROM ${LiveStorageTables.preferences} WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _decode(row.data['value'] as String, key);
  }

  @override
  Future<void> write(String key, Object? value) async {
    final encoded = _encode(value);
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.runInTransaction(() async {
      await database.customStatement(
        'INSERT INTO ${LiveStorageTables.preferences} (key, value, updated_at_ms) '
        'VALUES (?, ?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at_ms = excluded.updated_at_ms',
        [key, encoded, now],
      );
    });
    _changes.add(null);
  }

  @override
  Future<void> remove(String key) async {
    await database.customStatement('DELETE FROM ${LiveStorageTables.preferences} WHERE key = ?', [key]);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    await database.customStatement('DELETE FROM ${LiveStorageTables.preferences}');
    _changes.add(null);
  }

  Object? _decode(String raw, String key) {
    try {
      return jsonDecode(raw) as Object?;
    } on FormatException catch (error) {
      throw StorageCorruptedException('preferences key "$key" holds invalid JSON', cause: error);
    }
  }

  String _encode(Object? value) {
    // A non-encodable value is a programming error at the call site; the
    // JsonUnsupportedObjectError propagates unchanged.
    return jsonEncode(value);
  }
}
