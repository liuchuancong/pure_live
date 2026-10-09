// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_capability.dart
// Purpose: Public barrel of pure_live_capability; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: ecosystem. Allowed dependencies: layer L0 foundation; contract and model packages are pure Dart and must not depend on Flutter.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The contract assertions live in a second entrypoint, package:pure_live_capability/testing.dart, because
/// a source package must reach them from its tests without the capability interfaces pulling fixture
/// helpers into production code.
library;

export 'src/capabilities.dart';
export 'src/capability_registry.dart';
