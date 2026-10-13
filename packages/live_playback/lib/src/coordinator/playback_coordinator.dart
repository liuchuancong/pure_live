import 'dart:async';

import 'package:live_playback/src/session/playback_session.dart';
import 'package:media_core/media_core.dart';

/// Coordinates live playback sessions.
///
/// This is the composition root that bridges business requests (rooms/sites)
/// to the [PlayerKernel] runtime.
final class PlaybackCoordinator {

  /// Creates a new [PlaybackCoordinator].
  PlaybackCoordinator({required this.kernel});

  /// The underlying media kernel.
  final PlayerKernel kernel;

  /// Starts a new live playback session.
  ///
  /// [source] is the resolved playback source (URL + headers).
  /// [qualities] are the available quality candidates for the ladder.
  Future<PlaybackSession> startSession({
    required PlayerSource source,
    required List<PlayerSource> qualities,
    PlayerConfig config = PlayerConfig.defaults,
  }) async {
    // 1. Create a player via the kernel.
    final handle = await kernel.create(
      source: source,
      config: config,
    );

    // 2. Wrap it in a business-level session.
    return PlaybackSession(
      handle: handle,
      sourceCandidates: qualities,
      kernel: kernel,
    );
  }

  /// Stops and releases a session.
  Future<void> stopSession(PlaybackSession session) async {
    await session.dispose();
    await kernel.release(session.handle.id);
  }
}
