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
