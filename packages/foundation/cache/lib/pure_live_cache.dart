// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_cache.dart
// Purpose: Public barrel of pure_live_cache; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only, plus the utils and logging leaves.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Business code and plugins do not create their own cache: they take a namespace from CacheHub, so quota
/// and the settings screen cleanup stay accurate.
library;

export 'src/disk_tier.dart';
export 'src/policy.dart';
export 'src/store.dart';
