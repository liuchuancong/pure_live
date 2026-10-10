// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_backup_feature.dart
// Purpose: Public barrel of pure_live_backup_feature; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// An app hands this package a WebDAV store, its domain sources and the credential predicate from auth; it
/// gets back reports it can render and a restore it can retry. The archive's wire format is exported too,
/// because a local file export is the same format and must not be re-derived per app.
library;

export 'src/data/backup_document.dart';
export 'src/data/webdav_backup_service.dart';
export 'src/data/webdav_snapshot_remote.dart';
export 'src/domain/backup_reports.dart';
export 'src/domain/snapshot_remote.dart';
