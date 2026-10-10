// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_live.dart
// Purpose: Public barrel of pure_live_live; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The switching rule is the whole content of this package: a live source answers `resolve(room, {quality,
/// line})`, and the platform decides when that answer has actually taken over the screen. An app that
/// re-implements it per widget is how a late callback from an abandoned line ends up as the selection.
library;

export 'src/domain/live_session.dart';
