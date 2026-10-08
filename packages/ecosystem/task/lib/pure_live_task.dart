// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_task.dart
// Purpose: Public barrel of pure_live_task; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: ecosystem. Allowed dependencies: layer L0 foundation; contract and model packages are pure Dart and must not depend on Flutter.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// One scheduler serves every ecosystem; the task itself stays opaque to it, which is what lets a source
/// refresh, an EPG update and a ticket refresh share priorities and de-duplication.
library;

export 'src/cancellation.dart';
export 'src/in_memory_task_scheduler.dart';
export 'src/task.dart';
export 'src/task_scheduler.dart';
