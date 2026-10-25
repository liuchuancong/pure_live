# live_storage

Shared storage infrastructure for PureLive, built on drift + SQLite.

## Responsibilities

- Open the process's single SQLite database (the main window owns it).
- Run schema migrations and provide the namespaced JSON stores.
- Expose `JsonStore` / `JsonListStore` so feature repositories never touch
  tables or a database connection directly.
- Resolve application-provided storage paths.
- Expose the simple typed settings facade (`StoragePrefs`) over the
  `settings` namespace.
- Store cookies and passwords through `SecretStore` over the device-encrypted
  `SecretVault` the app provides (flutter_secure_storage: Keystore / Keychain /
  DPAPI).

## Dependencies

- `drift`: typed SQL and schema migrations.
- `sqlite3`: the native SQLite bindings drift opens (native assets).
- `drift_dev` / `build_runner` (dev): database code generation.

## Architecture Rules

- `live_storage` owns the database, its schema, transactions and stores.
- Feature repositories own their domain JSON and call a `JsonStore`.
- No feature or business package opens SQLite, Hive or a database file.
- The main window opens the database; room and tool windows read the
  projection the window bridge feeds them and send writes back as commands.
- Storage migrations are versioned in the drift `MigrationStrategy`.
- Platform-specific paths are injected by the app through
  `StoragePathProvider`.

## Code Generation

Run this in `packages/live_storage`, not at the workspace root (the app's
slang output lives elsewhere):

```bash
dart run build_runner build
```

The generated `lib/src/database/storage_database.g.dart` is committed.

## Usage

```dart
final bootstrap = StorageBootstrap(
  pathProvider: StoragePathProvider(resolver: () async => dataDirectory),
);
await bootstrap.initialize(); // opens <data>/storage.sqlite
await StoragePrefs.init();
```

Feature data uses a namespaced store; the main window opens it, a room
window gets the same data through its seed/projection instead:

```dart
final store = await StorageStores.instance.openStore('follows');
await store.put(identityKey, room.toJson());
store.get(identityKey); // synchronous, from the memory snapshot
store.watchKeys();     // the window bridge's change source
```

### Simple settings

Ad-hoc flags go through the `StoragePrefs` facade over the `settings`
namespace; reads are synchronous, writes are queued SQLite upserts.

```dart
await StoragePrefs.setString('lastPlatform', 'huya');
StoragePrefs.getString('lastPlatform');
await StoragePrefs.persistBatch(() {
  StoragePrefs.setBool('danmakuOn', true);
  StoragePrefs.setInt('fontSize', 18);
});
```

`prefBool`, `prefString` and the other factories hand back write-through
`PrefValue`s — assign `v`, the value persists and notifies listeners.
