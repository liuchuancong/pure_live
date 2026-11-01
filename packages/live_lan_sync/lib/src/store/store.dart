/// The persistence contract the host implements.
///
/// The engine never opens a database: every durable fact it needs — local
/// identity, trust, outbox, idempotency keys, cursors, tasks, tombstones,
/// open conflicts — goes through this interface (spec §15). A host binds
/// whatever it already has (Hive CE, SQLite, files) behind it; the package
/// ships no default store and forces none.
library;

export 'lan_sync_store.dart';
