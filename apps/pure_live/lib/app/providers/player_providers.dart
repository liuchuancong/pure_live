import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_better_player/media_core_better_player.dart';
import 'package:media_core_ijk_player/media_core_ijk_player.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/app/providers/presentation_providers.dart' show presentationDriverProvider;

/// The process's one player kernel: the mpv backend registered, the
/// presentation chain attached (fullscreen, window fullscreen and PiP), ready
/// to hand a controller to any room.
///
/// `MediaKitPlayerAdapter.ensureInitialized` runs once at boot (the app's
/// bootstrap calls [primePlayerEngine] before the first frame); the kernel
/// itself is cheap to hold and never disposed.
final Provider<PlayerKernel> playerKernelProvider = Provider<PlayerKernel>((ref) {
  final kernel = PlayerKernel()..registerBackend(const MediaKitAdapterFactory().registration());
  // Desktop keeps the mpv engine; the two mobile engines are real, shipped
  // adapters on Android and iOS and stay out of a desktop build.
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    kernel
      ..registerBackend(const FlvLzcPlayerAdapterFactory().registration())
      ..registerBackend(const BetterPlayerAdapterFactory().registration());
  }
  kernel.presentationDriver = ref.watch(presentationDriverProvider);
  return kernel;
});

/// The one-time native engine prime the boot path calls. Safe to call
/// twice; the adapter ignores repeats.
void primePlayerEngine() => MediaKitPlayerAdapter.ensureInitialized();

/// One live playback controller per open room: the kernel's single-slot
/// live orchestration (line × engine sweeps, watchdogs, recovery) over
/// one site's lines.
///
/// [onLinesNeeded] is the re-resolution seam: when the controller wants
/// fresh URLs (a recovery re-open, an engine fallback), it calls back and
/// the room controller asks the site again — the playback never talks to
/// a site itself.
LivePlaybackController createRoomPlayback({
  required PlayerKernel kernel,
  required Future<List<LivePlayLine>> Function() onLinesNeeded,
}) {
  return LivePlaybackController(
    kernel,
    onEngineFallbackSources: (nextEngine, current) => onLinesNeeded().then(roomSourcesOf),
    onRecoverySources: (current) => onLinesNeeded().then(roomSourcesOf),
  );
}

/// The site's playable lines as the player's source list, in the site's
/// own order: each line's own headers ride along, its identity names the
/// line so the pool and the recovery can tell sources apart.
List<PlayerSource> roomSourcesOf(List<LivePlayLine> lines) {
  return [
    for (final line in lines)
      PlayerSource(
        id: SourceId('live:${line.lineLabel ?? ''}:${line.url.hashCode}'),
        uri: Uri.parse(line.url),
        type: SourceType.live,
        protocol: SourceProtocol.fromScheme(Uri.parse(line.url).scheme),
        format: SourceFormat.fromUri(Uri.parse(line.url)),
        headers: line.headers.isEmpty ? null : SourceHeaders(line.headers.toMap()),
      ),
  ];
}

/// One room's live playback controller, keepable between rooms.
///
/// A stopped session is what the reference's "force-destroy player" off
/// state leaves behind: the next room takes it back instead of building a
/// second controller. Line recovery is delegated through [lineResolver], so a
/// reused controller asks the room that is playing now, never the room that
/// parked it.
final class RoomPlaybackSession {
  RoomPlaybackSession({required PlayerKernel kernel, required this.backendId}) {
    playback = LivePlaybackController(
      kernel,
      onEngineFallbackSources: (_, _) => lineResolver().then(roomSourcesOf),
      onRecoverySources: (_) => lineResolver().then(roomSourcesOf),
    );
  }

  /// The kernel backend the session was built for; a parked session is only
  /// reused while the viewer keeps the same engine.
  final String backendId;

  late final LivePlaybackController playback;

  /// The lines of the room that is playing now; a parked session is pointed
  /// at its new room before it is reused.
  Future<List<LivePlayLine>> Function() lineResolver = () async => const <LivePlayLine>[];

  Future<void> dispose() => playback.dispose();
}

/// The stopped live session a closed room leaves for the next one.
///
/// Holds at most one session, like the reference's `PlayerStandby`; keeping a
/// second disposes the first. Disposed with the provider tree, after which a
/// late [keep] releases its session instead of holding it.
final class RoomPlaybackStandby {
  RoomPlaybackSession? _held;
  bool _disposed = false;

  /// The parked session when it was built for [backendId]; a session built
  /// for another engine is released. Null when none fits.
  RoomPlaybackSession? take({required String backendId}) {
    final held = _held;
    if (held == null) {
      return null;
    }
    _held = null;
    if (held.backendId == backendId) {
      return held;
    }
    unawaited(held.dispose());
    return null;
  }

  /// Parks [session] for the next room.
  void keep(RoomPlaybackSession session) {
    if (_disposed) {
      unawaited(session.dispose());
      return;
    }
    final previous = _held;
    _held = session;
    if (previous != null && !identical(previous, session)) {
      unawaited(previous.dispose());
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    final held = _held;
    _held = null;
    await held?.dispose();
  }
}

/// The app's one [RoomPlaybackStandby] (one per provider scope, so tests
/// never share one).
final Provider<RoomPlaybackStandby> roomPlaybackStandbyProvider = Provider((ref) {
  final standby = RoomPlaybackStandby();
  ref.onDispose(() => unawaited(standby.dispose()));
  return standby;
});
