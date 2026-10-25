/// Public API for the reusable storage infrastructure.
library;

/// Storage initialization and lifecycle coordination.
export 'src/bootstrap/storage_bootstrap.dart';

/// Shared storage configuration.
export 'src/config/storage_config.dart';

/// Namespaced JSON document stores over the shared SQLite database.
export 'src/database/json_store.dart';

/// The process's database and its opened namespaces.
export 'src/database/storage_stores.dart';

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

/// Sealed secret storage.
export 'src/secrets/secret_store.dart';

/// The device secret vault contract and secret ref names.
export 'src/secrets/secret_vault.dart';
