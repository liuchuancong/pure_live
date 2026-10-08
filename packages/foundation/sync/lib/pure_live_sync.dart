// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_sync.dart
// Purpose: Public barrel of pure_live_sync; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only, plus the utils and logging leaves.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The remote is a port. docs/architecture/dependency-rules.md section 4 lists sync -> firebase as an
/// approved exception, but the vendor SDK is bound by the application so this package stays testable.
library;

export 'src/sync_engine.dart';
