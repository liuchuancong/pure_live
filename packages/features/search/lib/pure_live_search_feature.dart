// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_search_feature.dart
// Purpose: Public barrel of pure_live_search_feature; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The domain types are exported because an app composes them: the vocabulary of a search - what a term is,
/// how history is ordered, how results rank - is the contract the ui and the app both have to agree on. The
/// kv-backed store is exported too, since an app is the only place that knows which store to hand it.
library;

export 'src/data/stored_search_history.dart';
export 'src/domain/search_controller.dart';
export 'src/domain/search_history.dart';
export 'src/domain/search_result_order.dart';
export 'src/domain/search_term.dart';
