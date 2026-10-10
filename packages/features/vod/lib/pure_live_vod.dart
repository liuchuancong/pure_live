// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_vod.dart
// Purpose: Public barrel of pure_live_vod; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Two decisions live here and nowhere else: when a saved position is worth seeking to, and what plays after
/// the current episode. Both are answered against a proposal and a commit, because a failed open must
/// neither skip an episode nor resume at the end of one.
library;

export 'src/data/watch_progress.dart';
export 'src/domain/episode_navigator.dart';
