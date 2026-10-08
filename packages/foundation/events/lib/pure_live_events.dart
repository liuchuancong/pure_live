// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_events.dart
// Purpose: Public barrel of pure_live_events; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: foundation. Allowed dependencies: pub.dev packages only, plus the utils and logging leaves.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Subscribing here is for facts with no single owner. If one component owns the reaction, give it a
/// method instead: docs/architecture/dependency-rules.md section 6 bans replacing an interface dependency
/// with an event bus.
library;

export 'src/event_bus.dart';
