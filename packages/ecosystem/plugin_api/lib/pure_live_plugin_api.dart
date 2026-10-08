// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_plugin_api.dart
// Purpose: Public barrel of pure_live_plugin_api; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: ecosystem. Allowed dependencies: layer L0 foundation and the shared model umbrella; this package
/// deliberately does not depend on pure_live_extension or pure_live_permission - the bridge it defines is the
/// plugin-facing subset, adapted to the platform services by the host that wires both sides.
/// See docs/architecture/dependency-rules.md and the package README.
library;

export 'src/host_bridge.dart';
export 'src/lifecycle.dart';
export 'src/manifest_validator.dart';
export 'src/plugin_runtime.dart';
export 'src/sandbox.dart';
