import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart';
import 'package:live_net/live_net.dart' show ClientProfile;

import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/boot/storage_providers.dart' show appPathsProvider;
import 'package:pure_live/app/providers/cache/cache_settings.dart';
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;

/// The process's one cache manager.
///
/// The folder is read once: moving the cache folder is a restart-time choice
/// (the settings row says so), so a running manager never swaps trees. The
/// transport comes from the app's own factory, so every image follows the
/// proxy in force and lands in the network log like any other request.
final liveCacheManagerProvider = Provider<LiveCacheManager>((ref) {
  final folders = ref.read(appPathsProvider);
  final http = ref.read(networkFactoryProvider).create(profile: ClientProfile.media);
  final manager = LiveCacheManager(
    directory: folders.liveCache,
    http: http,
    config: LiveCacheSettings.read().toConfig(),
    log: appLog.forCategory('cache'),
  );
  ref.onDispose(() => unawaited(manager.dispose()));
  return manager;
});

/// The cache choices the settings pane edits.
final liveCacheSettingsProvider = NotifierProvider<LiveCacheSettingsController, LiveCacheSettings>(
  LiveCacheSettingsController.new,
);

/// Owns the stored cache choices; a write lands in the store and the running
/// manager reads the new limits on its next request.
final class LiveCacheSettingsController extends Notifier<LiveCacheSettings> {
  @override
  LiveCacheSettings build() => LiveCacheSettings.read();

  /// Turns disk caching on or off.
  Future<void> setDiskCacheEnabled({required bool value}) => _apply(state.copyWith(diskCacheEnabled: value));

  /// Sets the disk cap in megabytes.
  Future<void> setMaxMb(int value) => _apply(state.copyWith(maxMb: value));

  /// Sets how eagerly fresh copies are fetched.
  Future<void> setFreshness(CacheFreshness value) => _apply(state.copyWith(freshness: value));

  /// Turns automatic cleanup on or off.
  Future<void> setAutoClean({required bool value}) => _apply(state.copyWith(autoClean: value));

  Future<void> _apply(LiveCacheSettings next) async {
    if (next == state) {
      return;
    }
    state = next;
    await next.write();
  }
}

/// Keeps the running manager in step with the stored choices.
///
/// The root reads this once, and `refreshSettings` invalidates the settings
/// provider after a restore, which rebuilds this one and applies the restored
/// limits without a restart.
final liveCacheConfigSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(liveCacheSettingsProvider);
  final manager = ref.read(liveCacheManagerProvider);
  unawaited(manager.updateConfig(settings.toConfig()));
});

/// A snapshot of the cache's counters for the settings pane.
///
/// Invalidate it after a cleanup; it never scans the folder on its own beyond
/// the index the manager already keeps.
final cacheStatisticsProvider = FutureProvider<CacheStatistics>((ref) async {
  final manager = ref.watch(liveCacheManagerProvider);
  await manager.initialize();
  return manager.statistics();
});
