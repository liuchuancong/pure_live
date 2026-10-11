import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// Builds the [CacheStore] behind the dio cache interceptor.
///
/// The store choice stays with the app shell: this package is Flutter-free,
/// so a persistent store's directory would be passed in by the caller (from
/// path_provider in a Flutter app, or next to the executable in portable
/// mode).
///
/// Note on persistence: dio_cache_interceptor 4.x ships no first-party file
/// store yet — the community Hive store still pins the 3.x line and cannot
/// be combined with the pinned 4.0.7. Until the ecosystem catches up,
/// caching here is in-memory; a future persistent store can be injected
/// through `DioFactory` without touching this contract.
abstract final class CacheStoreFactory {
  /// An in-memory LRU store ([maxSizeBytes] total, [maxEntrySizeBytes] per
  /// entry). Nothing survives a restart.
  static CacheStore memory({int maxSizeBytes = 7340032, int maxEntrySizeBytes = 512000}) =>
      MemCacheStore(maxSize: maxSizeBytes, maxEntrySize: maxEntrySizeBytes);

  /// Reads through [primary] first, then [secondary] — the shape to use
  /// once a persistent store becomes available: memory in front of disk.
  static CacheStore tiered({required CacheStore primary, required CacheStore secondary}) =>
      BackupCacheStore(primary: primary, secondary: secondary);
}
