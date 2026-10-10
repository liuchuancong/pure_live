// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_iptv_feature.dart
// Purpose: Public barrel of pure_live_iptv_feature; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: features. Allowed dependencies: repository packages use L0, plugin_api and services; UI packages
/// use their own domain repository, services, ui and ecosystem; no same-layer cycles.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Everything here is pure and index-based: an imported playlist is a list someone else wrote, and the only
/// promises worth making are about walking it (wrap, filter without jumping, reach a typed number) and about
/// admitting what the data does not say.
library;

export 'src/domain/channel_zapper.dart';
export 'src/domain/epg_window.dart';
export 'src/domain/zap_channel.dart';
