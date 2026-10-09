// Module: lib/src/player_kernel_host.dart
// Purpose: The host-facing playback edge: one kernel over the media_kit backend, opened from tickets.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/media/media-contract.md and docs/adr/0020-media-core-owns-recovery.md. This file is the only
// place the engine package appears in a public signature; hosts above this layer see tickets going in and
// handles plus a surface widget coming out. Planning, backend selection and recovery stay inside media_core.

import 'package:flutter/widgets.dart';
import 'package:media_core/media_core.dart' as core;
import 'package:media_core_media_kit/media_core_media_kit.dart' as engine;
import 'package:pure_live_platform/pure_live_platform.dart' as platform;

import 'ticket_source.dart';

// The handle type is part of this package's public contract: hosts hold handles from [MediaKernelHost.open]
// and render them with [MediaSurface], without ever importing the engine package themselves.
export 'package:media_core/media_core.dart' show PlayerAdapter, PlayerHandle;

/// The process's playback kernel with the media_kit backend registered.
///
/// One host per app process (the composition root constructs it): the kernel owns backend selection, the
/// recovery ladder and the player pool, so a second kernel would be a second recovery brain competing for
/// the same audio focus.
final class MediaKernelHost {
  MediaKernelHost() : _kernel = core.PlayerKernel() {
    _kernel.registerBackend(const engine.MediaKitAdapterFactory().registration());
  }

  final core.PlayerKernel _kernel;

  /// Engine start-up that must happen before the first surface is built.
  /// Call once from the app entry point, after the Flutter binding is ready.
  static void ensureInitialized() => engine.MediaKitPlayerAdapter.ensureInitialized();

  /// Opens a resolved ticket on this kernel and returns the live handle.
  ///
  /// Autoplay is on: a ticket exists because the user asked for playback, and the kernel's config default
  /// matches that intent. The caller owns the returned handle and must [core.PlayerHandle.dispose] it.
  Future<core.PlayerHandle> open(platform.MediaTicket ticket) {
    return _kernel.createFromMedia(toCoreSource(ticket));
  }

  /// Tears the kernel down. Every handle opened from it must be disposed first.
  Future<void> dispose() => _kernel.dispose();
}

/// Renders the video surface of a handle opened from [MediaKernelHost].
///
/// The engine type check is deliberately explicit: with one registered backend every handle carries the
/// media_kit adapter, and a future second backend must add its own surface branch here rather than have a
/// blind cast decide what the user sees.
final class MediaSurface extends StatelessWidget {
  const MediaSurface({required this.handle, super.key});

  final core.PlayerHandle handle;

  @override
  Widget build(BuildContext context) {
    final adapter = handle.adapter;
    if (adapter is engine.MediaKitPlayerAdapter) {
      return engine.MediaKitVideoView(adapter: adapter);
    }
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          '当前内核后端不支持视频渲染: ${adapter.runtimeType}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}
