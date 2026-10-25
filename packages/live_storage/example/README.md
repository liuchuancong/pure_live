# live_storage_example

A runnable tour of `live_storage`. One `dart run` walks the whole storage
story against a throw-away temp directory:

1. `StorageBootstrap` — open the process's SQLite database at an
   app-provided path.
2. A namespaced `JsonStore` — save, get, update, count, delete, and a
   `watchKeys` subscription printing live events.
3. `StoragePrefs` — the simple one-line typed facade, including a
   multi-key `persistBatch`.
4. `prefBool` / `prefObject` — write-through `PrefValue`s notifying a
   listener on every assignment.

## Run

From this directory:

```bash
dart pub get
dart run
```
