// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_network.dart
// Purpose: Public barrel of pure_live_network; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only; foundation packages do not depend on
/// each other except the utils and logging leaves.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Providers, the plugin host and the app's update check all need the same transport rules; the failure
/// vocabulary here is the network namespace of docs/contracts/platform-models.md section 14.
library;

export 'src/classification.dart';
export 'src/client.dart';
export 'src/failure.dart';
export 'src/headers.dart';
export 'src/limiter.dart';
export 'src/request_body.dart';
export 'src/responses.dart';
export 'src/retry_policy.dart';
export 'src/settings.dart';
export 'src/url_reference.dart';
