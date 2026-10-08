// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_permission.dart
// Purpose: Public barrel of pure_live_permission; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: ecosystem. Allowed dependencies: layer L0 foundation; contract and model packages are pure Dart and must not depend on Flutter.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// This is the behavioural half of the permission subsystem; the data it reasons about
/// (Permission, PermissionGrant, PermissionScope, NetworkRequest, Cookie) belongs to pure_live_platform per
/// docs/adr/0018-contract-package-split.md.
library;

export 'src/extension_cookie_store.dart';
export 'src/extension_network.dart';
export 'src/permission_manager.dart';
export 'src/policy_permission_manager.dart';
export 'src/ports.dart';
