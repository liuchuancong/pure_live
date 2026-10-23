/// Public API for the reusable storage infrastructure.
library;

/// The typed box families the repositories and the box manager speak
/// in.
export 'package:hive_box_manager/hive_box_manager.dart' show KeyedBox, ListBox, MapBox, SetBox, SingleValueBox;

/// Storage initialization and lifecycle coordination.
export 'src/bootstrap/storage_bootstrap.dart';

/// Hive CE box lifecycle management.
export 'src/boxes/storage_box_manager.dart';

/// Shared storage configuration.
export 'src/config/storage_config.dart';

/// Storage diagnostics and health reporting.
export 'src/diagnostics/storage_diagnostics.dart';

/// The storage error model.
export 'src/diagnostics/storage_error.dart';

/// Storage migration contracts.
export 'src/migration/storage_migration.dart';

/// Storage migration execution.
export 'src/migration/storage_migration_runner.dart';

/// Application-provided storage path resolution.
export 'src/paths/storage_path_provider.dart';

/// Write-through reactive pref values.
export 'src/prefs/storage_pref_value.dart';

/// The simple typed settings facade.
export 'src/prefs/storage_prefs.dart';

/// The JSON bridge adapter for typed model storage.
export 'src/registry/json_box_adapter.dart';

/// Storage adapter registration.
export 'src/registry/storage_adapter_registry.dart';

/// Hive CE list repository implementation.
export 'src/repository/hive_storage_list_repository.dart';

/// Hive CE map repository implementation.
export 'src/repository/hive_storage_map_repository.dart';

/// Hive CE numeric repository implementation.
export 'src/repository/hive_storage_num_repository.dart';

/// Generic Hive CE repository implementation.
export 'src/repository/hive_storage_repository.dart';

/// Hive CE set repository implementation.
export 'src/repository/hive_storage_set_repository.dart';

/// Hive CE string repository implementation.
export 'src/repository/hive_storage_string_repository.dart';

/// List storage repository contract.
export 'src/repository/storage_list_repository.dart';

/// Map storage repository contract.
export 'src/repository/storage_map_repository.dart';

/// Numeric storage repository contract.
export 'src/repository/storage_num_repository.dart';

/// Common storage repository contract.
export 'src/repository/storage_repository.dart';

/// Set storage repository contract.
export 'src/repository/storage_set_repository.dart';

/// String storage repository contract.
export 'src/repository/storage_string_repository.dart';

/// Sealed secret storage.
export 'src/secrets/secret_store.dart';

/// The device secret vault contract and secret ref names.
export 'src/secrets/secret_vault.dart';
