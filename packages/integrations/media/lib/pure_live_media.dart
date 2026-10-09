// GENERATED-BY: tool/scaffold_package.ps1
// Module: lib/pure_live_media.dart
// Purpose: Public barrel of pure_live_media; the only import surface other packages may use.
// Author: liuchuancong
// Created: 2026-10-08
///
/// Layer: integrations. Allowed dependencies: layer L0 foundation; vendor SDKs may only be referenced from this layer.
/// It also reads the shared model umbrella (docs/adr/0018-contract-package-split.md), which is the vocabulary
/// this layer maps onto the kernel.
/// See docs/architecture/dependency-rules.md and the package README.
///
/// This package is where the platform boundary crosses into media_core: nothing below the ticket knows about
/// ContentRef, and nothing above it knows about PlayerHandle.
library;

export 'package:media_core_mediasession/media_core_mediasession.dart' show MediaSessionBootstrap;

export 'src/media_track_mapping.dart';
export 'src/playback_trace.dart';
export 'src/player_kernel_host.dart';
export 'src/ticket_policy.dart';
export 'src/ticket_source.dart';
export 'src/ticket_swap.dart';
export 'src/watchdog.dart';
