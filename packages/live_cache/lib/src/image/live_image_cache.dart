import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_cache/src/image/image_cache_policies.dart';
import 'package:live_cache/src/image/image_cache_policy.dart';
import 'package:live_cache/src/image/image_loader.dart';
import 'package:live_cache/src/image/image_request.dart';
import 'package:live_cache/src/image/image_result.dart';
import 'package:live_cache/src/image/live_cache_memory.dart';
import 'package:live_cache/src/models/cache_config.dart';
import 'package:live_cache/src/models/cache_entry.dart';
import 'package:live_cache/src/models/cache_failure.dart';
import 'package:live_cache/src/models/cache_priority.dart';
import 'package:live_cache/src/models/cache_source.dart';
import 'package:live_cache/src/models/cache_statistics.dart';
import 'package:live_cache/src/storage/cache_directory.dart';
import 'package:live_cache/src/storage/cache_file.dart' show looksLikeImage;
import 'package:live_cache/src/storage/cache_index.dart';
import 'package:live_cache/src/storage/cache_storage.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_net/live_net.dart' show LiveHttp;

/// The image half of the cache: policies, disk reads and writes, stale
/// refreshes, request de-duplication and the counters behind the settings
/// page.
///
/// The class is a plain object, not a singleton. The host creates one and
/// hands it to the `ImageProvider` factory; the lifecycle belongs to the
/// composition root.
final class LiveImageCache {
  /// Creates a cache over [directory], fetching through [_http].
  new({
    required this.directory,
    required LiveHttp http,
    LiveCacheConfig config = const LiveCacheConfig(),
    this.log,
    LiveCacheMemory? memory,
  }) : _http = http,
       _config = config,
       memory = memory ?? LiveCacheMemory() {
    _loader = ImageCacheLoader(http: http, timeout: config.image.timeout, log: log);
  }

  /// The clearable tree this cache owns.
  final CacheDirectory directory;

  /// Optional diagnostics target.
  final LiveLog? log;

  /// The bridge to Flutter's decoded-image cache.
  final LiveCacheMemory memory;

  final LiveHttp _http;
  late LiveCacheConfig _config;
  CacheIndex? _index;
  CacheStorage? _storage;
  late ImageCacheLoader _loader;
  bool _initialized = false;
  bool _storageReady = false;

  final Map<String, Future<LiveImageResult>> _inFlight = {};
  final Map<String, Future<LiveImageResult?>> _refreshes = {};

  int _obtains = 0;
  int _loads = 0;
  int _diskHits = 0;
  int _diskMisses = 0;
  int _networkFetches = 0;
  int _failures = 0;

  /// The current limits and refresh behaviour.
  LiveCacheConfig get config => _config;

  /// Whether disk reads and writes are usable right now.
  bool get diskAvailable => _storageReady;

  /// The last explicit cleanup, when one ran.
  DateTime? get lastCleanupAt => _storage?.lastCleanupAt;

  /// Prepares the folder and index, sweeps partial writes and applies the
  /// configured cap. Idempotent; false when the disk layer is unavailable.
  Future<bool> initialize() async {
    if (_initialized) {
      return _storageReady;
    }
    _initialized = true;
    final index = CacheIndex(directory: directory, log: log);
    final storage = CacheStorage(
      directory: directory,
      index: index,
      ttlForCategory: _ttlFor,
      priorityForCategory: _priorityFor,
      maxStaleForCategory: _maxStaleFor,
      log: log,
    );
    _index = index;
    _storage = storage;
    _storageReady = await storage.initialize();
    if (_storageReady && _config.image.autoClean) {
      final now = DateTime.now().toUtc();
      await storage.clearDead(now);
      await storage.enforceLimit(
        maxBytes: _config.image.maxDiskBytes,
        targetRatio: _config.image.cleanupTargetRatio,
        now: now,
      );
    }
    return _storageReady;
  }

  /// Applies new limits. A re-enabled disk layer initializes lazily; the cap
  /// is applied at once when automatic cleanup is on.
  Future<void> updateConfig(LiveCacheConfig config) async {
    _config = config;
    if (!_initialized) {
      return;
    }
    _loader = ImageCacheLoader(http: _http, timeout: config.image.timeout, log: log);
    if (config.image.diskCacheEnabled && !_storageReady) {
      _storageReady = await _storage!.initialize();
    }
    if (_storageReady && config.image.autoClean) {
      await enforceLimit();
    }
  }

  /// Resolves [request] to bytes under its policy.
  ///
  /// Concurrent requests for the same disk key share one future. A stale
  /// copy is returned when the policy allows it; the caller starts
  /// [refresh] to replace it.
  Future<LiveImageResult> resolve(ImageCacheRequest request) {
    final key = request.diskKey;
    final pending = _inFlight[key];
    if (pending != null) {
      return pending;
    }
    final future = _resolve(request);
    final tracked = future.whenComplete(() {
      unawaited(_inFlight.remove(key));
    });
    _inFlight[key] = tracked;
    return tracked;
  }

  /// Fetches a fresh copy for [request], sending its validators when the
  /// index has them.
  ///
  /// Answers the fresh bytes, or null when nothing changed (304), the disk
  /// layer is off, or the refresh failed — a stale-while-revalidate draw
  /// keeps its old picture in every one of those cases.
  Future<LiveImageResult?> refresh(ImageCacheRequest request) {
    final key = request.diskKey;
    final pending = _refreshes[key];
    if (pending != null) {
      return pending;
    }
    final future = _refresh(request);
    final tracked = future.whenComplete(() {
      unawaited(_refreshes.remove(key));
    });
    _refreshes[key] = tracked;
    return tracked;
  }

  /// The file behind [url], fetching it first when needed.
  ///
  /// Used by modules that must hand a file to a native decoder (the HEIC
  /// converter). Null when the disk layer is off or the fetch failed.
  Future<File?> fileFor({
    required Uri url,
    required ImageCachePolicy policy,
    String? cacheKey,
    String? version,
    String? accountScope,
    Map<String, String> headers = const {},
  }) async {
    final result = await resolve(
      ImageCacheRequest(
        url: url,
        policy: policy,
        cacheKey: cacheKey,
        version: version,
        accountScope: accountScope,
        headers: headers,
      ),
    );
    final entry = result.entry;
    return entry == null ? null : directory.imageFile(entry.category, entry.key);
  }

  /// The file [identity] already has on disk, without opening a connection.
  ///
  /// Used by derived images the caller converts itself: the converted file is
  /// reused until its TTL passes, then produced again.
  Future<File?> existingFile({
    required String identity,
    required ImageCachePolicy policy,
    String? version,
    String? accountScope,
  }) async {
    await initialize();
    if (!_diskEnabled(policy)) {
      return null;
    }
    final request = ImageCacheRequest.business(
      key: identity,
      policy: policy,
      version: version,
      accountScope: accountScope,
    );
    final entry = _storage!.entryFor(request.diskKey);
    if (entry == null || entry.isExpiredAt(DateTime.now().toUtc())) {
      return null;
    }
    final file = directory.imageFile(entry.category, entry.key);
    return await file.exists() ? file : null;
  }

  /// Stores [bytes] the caller produced (a converted cover) under [identity].
  Future<File?> putBytes({
    required String identity,
    required ImageCachePolicy policy,
    required Uint8List bytes,
    String? version,
    String? accountScope,
  }) async {
    await initialize();
    if (!_diskEnabled(policy)) {
      return null;
    }
    final request = ImageCacheRequest.business(
      key: identity,
      policy: policy,
      version: version,
      accountScope: accountScope,
    );
    final now = DateTime.now().toUtc();
    final entry = CacheEntry(
      key: request.diskKey,
      category: request.categorySlug,
      size: bytes.length,
      createdAt: now,
      lastAccessedAt: now,
      expiresAt: _expiryOf(policy, now),
      priority: policy.priority,
      version: request.effectiveVersion,
    );
    try {
      await _storage!.write(entry, bytes);
      return directory.imageFile(entry.category, entry.key);
    } on CacheFailure catch (failure) {
      log?.warning('derived cache write failed', fields: {'kind': failure.kind.name});
      return null;
    }
  }

  /// Marks one entry expired; the bytes stay for a stale draw.
  Future<void> invalidate(ImageCacheRequest request) async {
    await initialize();
    _storage?.invalidate(request.diskKey, DateTime.now().toUtc());
  }

  /// Marks every entry of [category] expired and drops its decoded copies,
  /// so the next draw refreshes it.
  Future<void> invalidateByCategory(String category) async {
    await initialize();
    memory.evictCategory(category);
    _storage?.invalidateByCategory(category, DateTime.now().toUtc());
    await _storage?.flush();
  }

  /// Removes one category's files and its decoded copies.
  Future<CacheCleanupResult> clearByCategory(String category) async {
    await initialize();
    memory.evictCategory(category);
    return await _storage!.clearByCategory(category, DateTime.now().toUtc());
  }

  /// Empties every image this cache owns, leaving partial writes alone.
  Future<CacheCleanupResult> clearImages() async {
    await initialize();
    memory.clear();
    return await _storage!.clearImages(DateTime.now().toUtc());
  }

  /// Empties every image and temporary file this cache owns.
  Future<CacheCleanupResult> clearAll() async {
    await initialize();
    memory.clear();
    return await _storage!.clearAll(DateTime.now().toUtc());
  }

  /// Removes every expired entry.
  Future<CacheCleanupResult> clearExpired() async {
    await initialize();
    return await _storage!.clearExpired(DateTime.now().toUtc());
  }

  /// Removes entries past their stale window; automatic cleanup's sweep.
  Future<CacheCleanupResult> clearDead() async {
    await initialize();
    return await _storage!.clearDead(DateTime.now().toUtc());
  }

  /// Empties leftover partial writes.
  Future<CacheCleanupResult> clearTemporary() async {
    await initialize();
    return await _storage!.clearTemporary();
  }

  /// Prunes to the configured cap.
  Future<CacheCleanupResult> enforceLimit() async {
    await initialize();
    if (!_storageReady) {
      return CacheCleanupResult.empty;
    }
    return await _storage!.enforceLimit(
      maxBytes: _config.image.maxDiskBytes,
      targetRatio: _config.image.cleanupTargetRatio,
      now: DateTime.now().toUtc(),
    );
  }

  /// Reconciles the index with the folder; the slow path for idle time.
  Future<void> reconcile() async {
    await initialize();
    if (!_storageReady) {
      return;
    }
    await _storage!.reconcile(DateTime.now().toUtc());
  }

  /// Records that a provider was resolved — the request side of the hit
  /// rate. The framework answers it from its decoded cache or asks for a
  /// load, which [noteLoad] counts.
  void noteObtain() => _obtains++;

  /// Records that a provider had to load bytes (a decoded-cache miss).
  void noteLoad() => _loads++;

  /// The image counters for the settings surface.
  ImageCacheStatistics imageStatistics() {
    final storage = _storage;
    final byCategory = <String, (int, int)>{};
    if (storage != null) {
      for (final entry in storage.entries) {
        final current = byCategory[entry.category] ?? (0, 0);
        byCategory[entry.category] = (current.$1 + entry.size, current.$2 + 1);
      }
    }
    final categories = [
      for (final row in byCategory.entries)
        CategoryCacheStatistics(category: row.key, diskSize: row.value.$1, fileCount: row.value.$2),
    ]..sort((a, b) => b.diskSize.compareTo(a.diskSize));
    final hits = _obtains - _loads;
    return ImageCacheStatistics(
      diskSize: storage?.totalBytes ?? 0,
      fileCount: categories.fold<int>(0, (sum, row) => sum + row.fileCount),
      memorySize: memory.decodedBytes,
      memoryCount: memory.decodedCount,
      hitCount: hits < 0 ? 0 : hits,
      missCount: _loads,
      diskHitCount: _diskHits,
      diskMissCount: _diskMisses,
      networkFetchCount: _networkFetches,
      failureCount: _failures,
      categories: categories,
    );
  }

  /// Writes pending index changes.
  Future<void> flush() async {
    await _storage?.flush();
  }

  /// Flushes the index and stops the debounce timer.
  Future<void> dispose() async {
    _inFlight.clear();
    _refreshes.clear();
    await _index?.close();
  }

  Future<LiveImageResult> _resolve(ImageCacheRequest request) async {
    await initialize();
    final policy = request.policy;
    final now = DateTime.now().toUtc();
    if (_diskEnabled(policy)) {
      final entry = _storage!.entryFor(request.diskKey);
      if (entry != null) {
        final bytes = await _storage!.read(entry);
        if (bytes != null) {
          final expired = entry.isExpiredAt(now);
          final usableWhenStale = entry.isUsableWhenStale(now, policy.maxStale);
          final serveNow =
              !expired ||
              policy.mode == ImageExpiryMode.cacheOnly ||
              (policy.mode == ImageExpiryMode.staleWhileRevalidate && usableWhenStale);
          if (serveNow) {
            _diskHits++;
            _storage!.touch(entry, now);
            return LiveImageResult(
              bytes: bytes,
              source: CacheSource.disk,
              isExpired: expired,
              isStale: expired,
              entry: entry,
            );
          }
          try {
            return await _fetchAndStore(request, entry: entry, now: now);
          } on CacheFailure {
            final fallback =
                policy.mode == ImageExpiryMode.refreshBeforeDisplay && policy.fallbackToStale && usableWhenStale;
            if (fallback) {
              _diskHits++;
              _storage!.touch(entry, now);
              return LiveImageResult(
                bytes: bytes,
                source: CacheSource.disk,
                isExpired: true,
                isStale: true,
                entry: entry,
              );
            }
            rethrow;
          }
        }
      }
    }
    if (policy.mode == ImageExpiryMode.cacheOnly) {
      throw const CacheFailure(CacheFailureKind.notFound, message: 'no cached copy and the policy is cache-only');
    }
    _diskMisses++;
    return await _fetchAndStore(request, now: now);
  }

  Future<LiveImageResult> _fetchAndStore(ImageCacheRequest request, {required DateTime now, CacheEntry? entry}) async {
    final maxBytes = request.policy.effectiveMaxImageSize(_config.image.maxImageBytes);
    final ImageFetchResult fetched;
    try {
      fetched = await _loader.fetch(request: request, maxBytes: maxBytes, entry: entry);
    } on CacheFailure {
      _failures++;
      rethrow;
    }
    if (fetched.notModified) {
      if (entry == null || !_diskEnabled(request.policy)) {
        throw const CacheFailure(CacheFailureKind.notFound, message: '304 without a usable cached copy');
      }
      final expiresAt = _expiryOf(request.policy, DateTime.now().toUtc());
      _storage!.extend(entry, expiresAt);
      final bytes = await _storage!.read(entry);
      if (bytes == null) {
        throw const CacheFailure(CacheFailureKind.notFound, message: '304 but the cached file vanished');
      }
      return LiveImageResult(
        bytes: bytes,
        source: CacheSource.disk,
        isExpired: false,
        isStale: false,
        entry: entry.copyWith(expiresAt: expiresAt, clearExpiresAt: expiresAt == null),
      );
    }
    final bytes = fetched.bytes!;
    if (!looksLikeImage(bytes)) {
      _failures++;
      throw const CacheFailure(CacheFailureKind.unsupportedFormat, message: 'body is not an image');
    }
    _networkFetches++;
    final stored = await _store(request, fetched, now: DateTime.now().toUtc());
    if (_config.image.autoClean && _storageReady && _storage!.totalBytes > _config.image.maxDiskBytes) {
      unawaited(enforceLimit());
    }
    return LiveImageResult(bytes: bytes, source: CacheSource.network, isExpired: false, isStale: false, entry: stored);
  }

  Future<CacheEntry?> _store(ImageCacheRequest request, ImageFetchResult fetched, {required DateTime now}) async {
    if (!_diskEnabled(request.policy)) {
      return null;
    }
    final bytes = fetched.bytes!;
    final entry = CacheEntry(
      key: request.diskKey,
      category: request.categorySlug,
      size: bytes.length,
      createdAt: now,
      lastAccessedAt: now,
      expiresAt: _expiryOf(request.policy, now),
      priority: request.policy.priority,
      etag: fetched.headers['etag'],
      lastModified: fetched.headers['last-modified'],
      version: request.effectiveVersion,
    );
    // The caller still gets its bytes when the disk refuses; a cache is an
    // optimisation, never a precondition for drawing.
    try {
      await _storage!.write(entry, bytes);
      return entry;
    } on CacheFailure catch (failure) {
      log?.warning('image cache write failed', fields: {'kind': failure.kind.name});
      return null;
    }
  }

  Future<LiveImageResult?> _refresh(ImageCacheRequest request) async {
    await initialize();
    if (!_diskEnabled(request.policy)) {
      return null;
    }
    final entry = _storage!.entryFor(request.diskKey);
    if (entry == null) {
      return null;
    }
    try {
      final fetched = await _loader.fetch(
        request: request,
        maxBytes: request.policy.effectiveMaxImageSize(_config.image.maxImageBytes),
        entry: entry,
      );
      final now = DateTime.now().toUtc();
      if (fetched.notModified) {
        _storage!.extend(entry, _expiryOf(request.policy, now));
        await _storage!.flush();
        return null;
      }
      final bytes = fetched.bytes!;
      if (!looksLikeImage(bytes)) {
        _failures++;
        return null;
      }
      _networkFetches++;
      final stored = CacheEntry(
        key: request.diskKey,
        category: request.categorySlug,
        size: bytes.length,
        createdAt: now,
        lastAccessedAt: now,
        expiresAt: _expiryOf(request.policy, now),
        priority: request.policy.priority,
        etag: fetched.headers['etag'],
        lastModified: fetched.headers['last-modified'],
        version: request.effectiveVersion,
      );
      try {
        await _storage!.write(stored, bytes);
      } on CacheFailure catch (failure) {
        log?.warning('stale refresh could not be stored', fields: {'kind': failure.kind.name});
      }
      return LiveImageResult(
        bytes: bytes,
        source: CacheSource.network,
        isExpired: false,
        isStale: false,
        entry: stored,
      );
    } on CacheFailure catch (failure) {
      _failures++;
      log?.info(
        'image refresh failed; keeping the stale copy',
        fields: {'kind': failure.kind.name, 'status': failure.statusCode},
      );
      return null;
    }
  }

  bool _diskEnabled(ImageCachePolicy policy) => _storageReady && _config.image.diskCacheEnabled && policy.diskCache;

  DateTime? _expiryOf(ImageCachePolicy policy, DateTime now) {
    final ttl = policy.effectiveTtl(_config.image.ttlScale);
    return ttl == null ? null : now.add(ttl);
  }

  Duration? _ttlFor(String category) => ImageCachePolicies.byCategory(category).effectiveTtl(_config.image.ttlScale);

  CachePriority _priorityFor(String category) => ImageCachePolicies.byCategory(category).priority;

  Duration? _maxStaleFor(String category) => ImageCachePolicies.byCategory(category).maxStale;
}
