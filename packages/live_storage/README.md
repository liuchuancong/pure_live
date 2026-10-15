
# live_storage

Shared storage infrastructure for PureLive, built on Hive CE.

## Responsibilities

- Initialize the storage engine.
- Coordinate application adapter registration.
- Manage storage configuration and box lifecycle.
- Provide storage migration infrastructure.
- Resolve platform-specific storage paths.
- Expose storage diagnostics.
- Expose the simple typed settings facade (`StoragePrefs`) and its write-through reactive values for ad-hoc flags that do not deserve a repository.

## Dependencies

- `hive_ce`: Core storage engine.
- `hive_ce_flutter`: Flutter platform integration.
- `hive_box_manager`: Box management utilities.
- `hive_ce_generator`: Adapter code generation.

## Architecture Rules

- Business packages own their data models and adapters.
- `live_storage` owns shared storage infrastructure only.
- Business packages use Hive CE APIs directly for data operations.
- The application composition root coordinates storage initialization.
- Storage initialization must complete before dependent data is accessed.
- Adapter registration must finish before opening boxes that use custom types.
- Storage migrations must be explicit and versioned.
- Platform-specific paths must not be hard-coded in business packages.

## Code Generation

Run the following command from the workspace root:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generate adapters for application models using the project's Hive CE generator conventions.

## Usage

Initialize storage during application startup, register the required adapters, and then allow feature packages to access their boxes.

See the implementation in `lib/src/` for the supported initialization and management APIs.

### Simple settings

Ad-hoc flags that do not deserve a repository go through the `StoragePrefs` facade: one string-keyed box (`settings.kv`), static one-line typed reads and writes. Call `StoragePrefs.init()` once after `StorageBootstrap.initialize`.

```dart
await StoragePrefs.setString('lastPlatform', 'huya');
StoragePrefs.getString('lastPlatform'); // synchronous read
await StoragePrefs.persistBatch(() {
  StoragePrefs.setBool('danmakuOn', true);
  StoragePrefs.setInt('fontSize', 18);
}); // one commit
```

`prefBool`, `prefString` and the other factories hand back write-through `PrefValue`s — assign `v`, the value persists and notifies listeners synchronously.
