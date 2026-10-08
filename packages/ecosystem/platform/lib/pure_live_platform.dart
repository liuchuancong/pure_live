// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_platform.dart
// Purpose: Public barrel of pure_live_platform; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: ecosystem. Allowed dependencies: layer L0 foundation; contract and model packages are pure
/// Dart and must not depend on Flutter.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The first slice is docs/contracts/platform-models.md section 19: the models the TVBox playback path
/// needs. ContentIdentity, Task, PermissionGrant, aggregation, EPG and music models land with their own
/// waves, and this barrel grows with them.
library;

export 'src/models/content/content_ref.dart';
export 'src/models/content/paging.dart';
export 'src/models/diagnostics/diagnostic_event.dart';
export 'src/models/error/platform_error_info.dart';
export 'src/models/extension/extension_descriptor.dart';
export 'src/models/extension/extension_type.dart';
export 'src/models/identifiers.dart';
export 'src/models/media/media_ticket.dart';
export 'src/models/network/cookie.dart';
export 'src/models/network/network_request.dart';
export 'src/models/permission/permission_grant.dart';
export 'src/models/repository/repository_descriptor.dart';
export 'src/models/resolver/resolve_request.dart';
export 'src/models/runtime/runtime_descriptor.dart';
export 'src/models/source/source_descriptor.dart';
export 'src/models/task/task_models.dart';
