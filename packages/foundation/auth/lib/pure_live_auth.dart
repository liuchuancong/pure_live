// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_auth.dart
// Purpose: Public barrel of pure_live_auth; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only, plus the utils and logging leaves.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Providers receive a CredentialHandle, never plaintext: docs/security/credential-storage.md makes this
/// package the only reader and writer of credentials.
library;

export 'src/credential_store.dart';
export 'src/session.dart';
