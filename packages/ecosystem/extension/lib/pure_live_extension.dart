// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_extension.dart
// Purpose: Public barrel of pure_live_extension; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: ecosystem. Allowed dependencies: layer L0 foundation, the shared model umbrella and - as the one
/// documented exception for a same-layer edge - pure_live_permission and pure_live_task, which this gateway
/// assembles into an ExtensionContext. See docs/adr/0019-gateway-service-edges.md.
library;

export 'src/context.dart';
export 'src/extension.dart';
export 'src/gateway.dart';
export 'src/managed_extension_gateway.dart';
export 'src/network_transport_bridge.dart';
export 'src/persistent_context.dart';
export 'src/runtime.dart';
export 'src/source.dart';
