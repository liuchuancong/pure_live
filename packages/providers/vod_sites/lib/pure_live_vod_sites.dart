// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_vod_sites.dart
// Purpose: Public barrel of pure_live_vod_sites; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-11
///
/// Layer: providers. Allowed dependencies: L0 foundation plus the L1 contract packages; providers never depend
/// on each other and never touch PlayerAdapter (invariants I1 and I5).
/// See docs/architecture/dependency-rules.md and the package README.
///
/// The点播 counterpart of `pure_live_sites`, in the same shape: one directory per site, two files per site
/// (`<site>_api.dart` + `<site>_site.dart`), and the platform's shared models as the return values
/// (docs/architecture/package-architecture.md §2). It is a separate package because a video and a live room do
/// not agree on what a ticket is: a video's address can be replayed at leisure, a room's carries a lease that
/// may end an established connection, so `resolve`/`refresh` cannot serve both from one class honestly.
library;

export 'src/bilibili/bilibili_api.dart';
export 'src/bilibili/bilibili_vod_site.dart';
