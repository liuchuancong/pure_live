// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_account.dart
// Purpose: Public barrel of pure_live_account; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The credential itself never appears here: docs/security/credential-storage.md keeps it inside the auth
/// package, and this package's whole job is the shape a signed-in site takes *around* it.
library;

export 'src/data/credential_site_accounts.dart';
export 'src/domain/site_account.dart';
