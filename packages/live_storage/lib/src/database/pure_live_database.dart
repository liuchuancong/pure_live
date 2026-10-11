import 'package:drift/drift.dart';
import 'package:live_storage/src/contracts/storage_exception.dart';

/// Table names, used for change notifications and diagnostics.
abstract final class LiveStorageTables {
  /// Typed settings values (JSON-encoded).
  static const preferences = 'preferences';
}

/// The v1 schema, written out explicitly: one CREATE TABLE per table, in
/// registration order.
const List<String> _schema = [
  'CREATE TABLE preferences (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at_ms INTEGER NOT NULL)',
];

/// The versioned database skeleton business tables hang off.
///
/// Migration policy per the storage spec: migrations are registered
/// explicitly as steps, a missing step fails loudly with
/// [StorageMigrationException], and nothing here ever deletes the
/// database to "recover" — a damaged database surfaces as
/// [StorageCorruptedException] so the app can offer the user a real
/// choice (restore backup / start over), not a silent wipe.
///
/// Following the established PureLive store pattern, tables are plain
/// SQL (names in [LiveStorageTables]) and access goes through
/// `customSelect`/`customStatement`; no codegen is involved.
final class PureLiveDatabase extends GeneratedDatabase {
  /// Opens the database over [executor] (NativeDatabase in-memory or
  /// file-backed).
  new(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final statement in _schema) {
        await customStatement(statement);
      }
    },
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
