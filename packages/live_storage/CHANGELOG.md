# Changelog

All notable changes to `live_storage` are documented in this file.

## 0.2.0

- Replace Hive CE with drift + SQLite.
- Add the namespaced `JsonStore` / `JsonListStore` over one database.
- Add schema migrations and the `StorageStores` process owner.
- Keep `StoragePrefs` and its seeded-memory backing for secondary windows.
- Remove Hive boxes, adapters and the box manager.

## 0.1.0

- Add shared storage configuration.
- Add storage initialization and adapter registration.
- Add Hive CE box lifecycle management.
- Add storage migration contracts and execution.
- Add application-configured storage path resolution.
- Add storage diagnostic models.
