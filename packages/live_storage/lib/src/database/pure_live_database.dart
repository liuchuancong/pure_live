import 'package:drift/drift.dart';
import 'package:live_storage/src/contracts/keyed_store.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';
import 'package:live_storage/src/database/db_keyed_store.dart';

/// Table names this package seeds; callers own the names of every other
/// table they open through [PureLiveDatabase.openStore].
abstract final class LiveStorageTables {
  /// Typed settings values (JSON documents).
  static const preferences = 'preferences';
}

/// The versioned database the keyed stores hang off.
///
/// The database itself registers no tables — [openStore] creates a
/// table on first use from the name the caller passes, loads it into
/// memory and hands back a Hive-like keyed store. Migration policy per
/// the storage spec: schema steps are registered explicitly, a missing
/// step fails loudly with [StorageMigrationException], and nothing here
/// ever deletes the database to "recover" — a damaged database surfaces
/// as [StorageCorruptedException] so the app can offer the user a real
/// choice (restore backup / start over), not a silent wipe.
///
/// Tables are plain SQL and access goes through
/// `customSelect`/`customStatement`; no codegen is involved.
final class PureLiveDatabase extends GeneratedDatabase {
  /// Opens the database over [executor] (NativeDatabase in-memory or
  /// file-backed).
  new(super.executor);

  final Map<String, Future<KeyedStore>> _opening = {};

  /// Opens the keyed store for the table [name] — creating the table
  /// when missing, loading its rows, one store instance per name shared
  /// by every caller.
  ///
  /// [name] is interpolated into CREATE/SELECT/DELETE text, so it must
  /// be a plain identifier; anything else is rejected here before it
  /// can become an injection.
  Future<KeyedStore> openStore(String name) {
    DbKeyedStore.checkTableName(name);
    return _opening.putIfAbsent(name, () => DbKeyedStore.open(database: this, tableName: name));
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
