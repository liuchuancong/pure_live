// The player kernel's choice: what the store says only wins when the
// platform can serve it — the fallback rules here are the ones a black
// screen teaches, so they are pinned instead of remembered.

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/providers/player/player_backend_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await StoragePrefs.initSeeded({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('the stored engine wins while the platform serves it', () async {
    await StoragePrefs.setString('player.backend', 'better_player');
    expect(container.read(playerKernelBackendProvider), PlayerKernelBackend.betterPlayer);
  });

  test('an engine the platform cannot serve falls to the first available', () async {
    // The override must stand before the provider's first build: macOS
    // serves mpv alone, so a stored ijk must not survive it.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await StoragePrefs.setString('player.backend', 'ijk');
    final state = container.read(playerKernelBackendProvider);
    expect(state, PlayerKernelBackend.mpv);
  });

  test('an unknown stored id reads as mpv', () async {
    await StoragePrefs.setString('player.backend', 'what-kernel');
    expect(container.read(playerKernelBackendProvider), PlayerKernelBackend.mpv);
  });

  test('select refuses an engine the platform cannot serve', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await container.read(playerKernelBackendProvider.notifier).select(PlayerKernelBackend.ijk);
    expect(container.read(playerKernelBackendProvider), PlayerKernelBackend.mpv);
  });

  test('select adopts the chosen engine', () async {
    await container.read(playerKernelBackendProvider.notifier).select(PlayerKernelBackend.betterPlayer);
    expect(container.read(playerKernelBackendProvider), PlayerKernelBackend.betterPlayer);
  });
}
