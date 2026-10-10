// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_music_feature.dart
// Purpose: Public barrel of pure_live_music_feature; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The bridge interface is exported because the app implements it: it is the seam where the lx script host
/// (a provider) becomes something this domain may ask a question of. The queue and the repository are the
/// two things a music surface actually renders against.
library;

export 'src/data/lx_music_repository.dart';
export 'src/domain/music_queue.dart';
export 'src/domain/music_source_bridge.dart';
