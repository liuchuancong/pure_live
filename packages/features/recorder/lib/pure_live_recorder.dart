// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_recorder.dart
// Purpose: Public barrel of pure_live_recorder; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Only the lifecycle model lives here on purpose: writing a file is the recorder wave's encoder wiring, and
/// a task list that can already refuse an impossible transition is worth having before the thing it guards
/// exists.
library;

export 'src/domain/recording_task.dart';
