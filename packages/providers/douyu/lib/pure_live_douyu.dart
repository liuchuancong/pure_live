// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_douyu.dart
// Purpose: Public barrel of pure_live_douyu; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-09
///
/// Layer: providers. Allowed dependencies: L0 foundation plus L1 plugin_api through the sandbox bridge
/// injected by the host; providers never depend on each other and never touch PlayerAdapter (I1 and I5).
/// See docs/architecture/dependency-rules.md and the package README.
///
/// Douyu is an anonymous web viewer in this slice: feed, category browse, search, and a signed resolve that
/// hands the player one lease. Sign-in, danmaku and line picking stay in v1 until a consumer needs them.
library;

export 'src/live/douyu_sign.dart';
export 'src/live/douyu_source.dart';
export 'src/models/douyu_row.dart';
