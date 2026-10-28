import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The player backends this build can choose between.
///
/// mpv (media_kit) is the desktop engine and the fallback everywhere. The
/// mobile engines only exist on Android and iOS; on a desktop the selector
/// honestly has one choice.
enum PlayerKernelBackend {
  mpv('mpv'),
  ijk('ijk'),
  betterPlayer('better_player');

  PlayerKernelBackend(this.id);

  /// The adapter id the kernel registry knows; it is also the `player.backend`
  /// value, so a registry rename has to migrate the stored preference.
  final String id;

  static PlayerKernelBackend fromId(String? id) =>
      PlayerKernelBackend.values.firstWhere((backend) => backend.id == id, orElse: () => PlayerKernelBackend.mpv);
}

/// The engines this platform registers. Desktop has mpv only; Android and
/// iOS add the IJK (flv_lzc) and BetterPlayer engines.
List<PlayerKernelBackend> availablePlayerKernelBackends() {
  if (kIsWeb) return const [PlayerKernelBackend.mpv];
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => const [
      PlayerKernelBackend.mpv,
      PlayerKernelBackend.ijk,
      PlayerKernelBackend.betterPlayer,
    ],
    // iOS starts on BetterPlayer: it plays through AVFoundation, and its
    // platform view is the on-screen AVPlayerLayer the system
    // picture-in-picture window lifts. The other two render into a Flutter
    // texture, which the system cannot float.
    TargetPlatform.iOS => const [PlayerKernelBackend.betterPlayer, PlayerKernelBackend.mpv, PlayerKernelBackend.ijk],
    _ => const [PlayerKernelBackend.mpv],
  };
}

/// The viewer's engine choice, persisted under `player.backend` and read
/// when a room opens its playback.
final class PlayerKernelBackendController extends Notifier<PlayerKernelBackend> {
  static const String _key = 'player.backend';

  @override
  PlayerKernelBackend build() {
    final available = availablePlayerKernelBackends();
    PlayerKernelBackend stored;
    try {
      stored = PlayerKernelBackend.fromId(StoragePrefs.getString(_key));
    } on Object {
      stored = PlayerKernelBackend.mpv;
    }
    return available.contains(stored) ? stored : available.first;
  }

  /// Stores the choice; new players use it.
  Future<void> select(PlayerKernelBackend backend) async {
    if (!availablePlayerKernelBackends().contains(backend) || backend == state) return;
    state = backend;
    try {
      await StoragePrefs.setString(_key, backend.id);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The chosen player backend.
final playerKernelBackendProvider = NotifierProvider<PlayerKernelBackendController, PlayerKernelBackend>(
  PlayerKernelBackendController.new,
);
