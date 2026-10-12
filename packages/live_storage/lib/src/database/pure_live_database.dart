import 'package:drift/drift.dart';
import 'package:live_storage/src/contracts/keyed_store.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';
import 'package:live_storage/src/database/db_keyed_store.dart';

/// Table names this package seeds; callers own the names of every other
/// table they open through [PureLiveDatabase.store].
abstract final class LiveStorageTables {
  /// Typed settings values (JSON documents).
  static const preferences = 'preferences';
}

/// The versioned database the keyed stores hang off.
///
/// The database itself registers no tables — [store] creates a table on
/// first use from the name the caller passes. Migration policy per the
/// storage spec: schema steps are registered explicitly, a missing step
/// fails loudly with [StorageMigrationException], and nothing here ever
/// deletes the database to "recover" — a damaged database surfaces as
/// [StorageCorruptedException] so the app can offer the user a real
/// choice (restore backup / start over), not a silent wipe.
///
/// Tables are plain SQL and access goes through
/// `customSelect`/`customStatement`; no codegen is involved.
final class PureLiveDatabase extends GeneratedDatabase {
  /// Opens the database over [executor] (NativeDatabase in-memory or
  /// file-backed).
  new(super.executor);

  static final RegExp _tableNamePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,63}$');

  final Map<String, KeyedStore> _stores = {};

  /// The keyed store for the table [name], created on first use, one
  /// store instance per name.
  ///
  /// [name] is interpolated into CREATE/SELECT/DELETE text, so it must
  /// be a plain identifier — anything else is rejected here before it
  /// can become an injection.
  KeyedStore store(String name) {
    if (!_tableNamePattern.hasMatch(name)) {
      throw StorageValidationException('table name must be a plain identifier, got "$name"');
    }
    return _stores.putIfAbsent(name, () => DbKeyedStore(database: this, tableName: name));
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // No upgrade path is registered yet (schemaVersion is 1).
      // When the first real migration lands it must be added here as
      // an explicit step — this throw is the fail-loud guard.
      throw StorageMigrationException('no migration registered from schema v$from to v$to', from: from, to: to);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Runs [action] inside a transaction: all writes commit together or
  /// none do.
  Future<T> runInTransaction<T>(Future<T> Function() action) => transaction(action);
}
