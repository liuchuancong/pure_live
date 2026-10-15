# live_storage_example

A runnable tour of `live_storage`. One `dart run` walks the whole storage
story against a throw-away temp directory:

1. `StorageBootstrap` — init Hive with an app-provided path and register a
   `JsonBoxAdapter` for a demo model through the adapter registry.
2. A typed repository over a `hive_box_manager` keyed box — save, get,
   update, count, delete, and a `watch` subscription printing live events.
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
