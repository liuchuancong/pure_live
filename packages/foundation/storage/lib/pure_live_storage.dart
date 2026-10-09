// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_storage.dart
// Purpose: Public barrel of pure_live_storage; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only, plus the utils and logging leaves.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The application binds KeyValueStore and SecureStore to a real backend in its composition root, so
/// everything above foundation can be tested without Flutter.
library;

export 'src/file_key_value_store.dart';
export 'src/migration.dart';
export 'src/migration_runner.dart';
export 'src/stores.dart';
