import 'package:drift/drift.dart';

part 'storage_database.g.dart';

/// A namespaced JSON document store: follows, history, recordings, IPTV,
/// the multiview wall and any future feature-owned collection.
///
/// [createdAt] preserves insertion order; [updatedAt] records the last
/// write. The feature repositories sort their own domain fields.
class JsonEntries extends Table {
  /// The store namespace (`follows`, `history`, `iptv`, …).
  TextColumn get namespace => text()();

  /// The identity within the namespace.
  TextColumn get key => text()();

  /// The stored document as JSON.
  TextColumn get valueJson => text()();

  /// When the entry first appeared (milliseconds since epoch).
  IntColumn get createdAt => integer()();

  /// When the entry was last written (milliseconds since epoch).
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {namespace, key};
}

/// Bookkeeping that is not user data: the schema marker, migration
/// state and any future one-off flags.
class AppMeta extends Table {
  /// The metadata key.
  TextColumn get key => text()();

  /// The metadata value.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The one SQLite database in the process.
///
/// Only the engine that owns the data directory opens it; the room and
/// tool windows go through the window bridge instead. The schema stays
/// deliberately document-shaped: the app reads whole JSON records by key.
@DriftDatabase(tables: [JsonEntries, AppMeta])
class StorageDatabase extends _$StorageDatabase {
  /// Serves [e].
  new(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS json_entries_namespace_created '
        'ON json_entries (namespace, created_at)',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
