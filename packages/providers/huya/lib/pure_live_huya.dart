// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_huya.dart
// Purpose: Public barrel of pure_live_huya; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: providers. Allowed dependencies: L0 foundation plus L1 plugin_api through the sandbox bridge injected
/// by the host; providers never depend on each other and never touch PlayerAdapter (invariants I1 and I5).
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Layout per docs/architecture/package-architecture.md 2.1: constant/ for urls, headers and ids, api/ for the
/// anti-code and the response failures, model/ for the shapes the endpoints describe, site/ for the one class
/// that answers the capability interfaces. Only that class and the shared names are exported.
library;

export 'src/api/huya_anti_code.dart';
export 'src/api/huya_profile_request_failure.dart';
export 'src/api/huya_viewer_uid.dart';
export 'src/constant/huya_endpoints.dart';
export 'src/constant/huya_identity.dart';
export 'src/model/huya_list_row.dart';
export 'src/model/huya_room_profile.dart';
export 'src/model/huya_stream_entry.dart';
export 'src/site/huya_source.dart';
