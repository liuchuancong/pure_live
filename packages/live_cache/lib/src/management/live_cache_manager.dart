import 'dart:io';

import 'package:live_cache/src/image/image_cache_policy.dart';
import 'package:live_cache/src/image/image_request.dart';
import 'package:live_cache/src/image/live_image_cache.dart';
import 'package:live_cache/src/memory/memory_cache.dart';
import 'package:live_cache/src/models/cache_config.dart';
import 'package:live_cache/src/models/cache_statistics.dart';
import 'package:live_cache/src/storage/cache_directory.dart';
import 'package:live_cache/src/storage/cache_storage.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_net/live_net.dart' show LiveHttp;

/// The host-facing facade over the image cache and the API memory cache.
///
/// The composition root creates one, calls [initialize] before the first
/// image and [dispose] on shutdown. There is deliberately no global
/// singleton.
final class LiveCacheManager {
  /// Creates a manager over [directory], fetching through [http].
  new({
    required Directory directory,
    required LiveHttp http,
    LiveCacheConfig config = const LiveCacheConfig(),
    LiveLog? log,
  }) : _config = config,
       image = LiveImageCache(directory: CacheDirectory(directory), http: http, config: config, log: log),
       api = MemoryCache<String, Object>(config: config.apiMemory);

  /// The image cache behind `LiveCacheImage`.
  final LiveImageCache image;

  /// The optional short-lived API value cache.
  final MemoryCache<String, Object> api;

  LiveCacheConfig _config;

  /// The limits in force.
  LiveCacheConfig get config => _config;

  /// Prepares the folder and applies the configured cap.
  Future<bool> initialize() => image.initialize();

  /// Applies new limits; the image cap is enforced at once when automatic
  /// cleanup is on.
  Future<void> updateConfig(LiveCacheConfig config) async {
    _config = config;
    await image.updateConfig(config);
  }

  /// Everything the settings page prints.
  CacheStatistics statistics() => CacheStatistics(
    image: image.imageStatistics(),
    apiMemory: api.statistics,
    lastCleanupAt: image.lastCleanupAt,
    diskAvailable: image.diskAvailable,
  );

  /// Empties the image tree and the API memory cache.
  Future<CacheCleanupResult> clearAll() async {
    api.clear();
    final result = await image.clearAll();
    return result;
  }

  /// Empties the image tree, leaving partial writes and the API cache alone.
  Future<CacheCleanupResult> clearImages() => image.clearImages();

  /// Removes expired image entries and API values.
  Future<CacheCleanupResult> clearExpired() async {
    api.clearExpired();
    final result = await image.clearExpired();
    return result;
  }

  /// Removes one image category.
  Future<CacheCleanupResult> clearByCategory(String category) => image.clearByCategory(category);

  /// Empties leftover partial writes.
  Future<CacheCleanupResult> clearTemporary() => image.clearTemporary();

  /// Prunes the image cache to its cap.
  Future<CacheCleanupResult> enforceLimit() => image.enforceLimit();

  /// Reconciles the index with the folder; run while idle.
  Future<void> reconcile() => image.reconcile();

  /// Marks one image category expired without deleting it.
  Future<void> invalidateByCategory(String category) => image.invalidateByCategory(category);

  /// Marks one image expired without deleting it.
  Future<void> invalidate({
    required Uri url,
    required ImageCachePolicy policy,
    String? cacheKey,
    String? version,
    String? accountScope,
  }) => image.invalidate(
    ImageCacheRequest(url: url, policy: policy, cacheKey: cacheKey, version: version, accountScope: accountScope),
  );

  /// Flushes bookkeeping and releases the memory cache.
  Future<void> dispose() async {
    api.clear();
    await image.dispose();
  }
}
