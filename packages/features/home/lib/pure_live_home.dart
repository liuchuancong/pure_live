// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_home.dart
// Purpose: Public barrel of pure_live_home; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The app declares its tabs, the user arranges them, and this package owns the merge of those two facts.
/// A ui that re-implements the merge is a ui that moves the user's tabs on them, so the rules are exported
/// rather than kept behind a widget.
library;

export 'src/data/stored_home_layout.dart';
export 'src/domain/home_layout_repository.dart';
export 'src/domain/home_layout_service.dart';
export 'src/domain/home_tab.dart';
