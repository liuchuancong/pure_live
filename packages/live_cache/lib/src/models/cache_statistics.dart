import 'package:meta/meta.dart';

/// One image category's disk usage.
@immutable
final class CategoryCacheStatistics {
  /// Creates a category row.
  const new({required this.category, required this.diskSize, required this.fileCount});

  /// The category name.
  final String category;

  /// Bytes this category holds.
  final int diskSize;

  /// Files this category holds.
  final int fileCount;
}

/// The image cache's counters at one moment.
@immutable
final class ImageCacheStatistics {
  /// Creates the image counters.
  const new({
    this.diskSize = 0,
    this.fileCount = 0,
    this.memorySize = 0,
    this.memoryCount = 0,
    this.hitCount = 0,
    this.missCount = 0,
    this.diskHitCount = 0,
    this.diskMissCount = 0,
    this.networkFetchCount = 0,
    this.failureCount = 0,
    this.categories = const [],
  });

  /// Bytes on disk.
  final int diskSize;

  /// Files on disk.
  final int fileCount;

  /// Decoded bytes Flutter holds; an estimate, not the process's RSS.
  final int memorySize;

  /// Decoded images Flutter holds.
  final int memoryCount;

  /// Image requests answered by Flutter's decoded-image cache.
  final int hitCount;

  /// Image requests that had to load from disk or network.
  final int missCount;

  /// Reads answered by the disk cache.
  final int diskHitCount;

  /// Reads the disk cache could not answer.
  final int diskMissCount;

  /// Successful network fetches.
  final int networkFetchCount;

  /// Failed reads or fetches.
  final int failureCount;

  /// Disk usage per category.
  final List<CategoryCacheStatistics> categories;

  /// Hits over all image requests; 0 when nothing was asked yet.
  double get hitRate {
    final total = hitCount + missCount;
    return total == 0 ? 0 : hitCount / total;
  }
}

/// The optional API memory cache's counters.
@immutable
final class MemoryCacheStatistics {
  /// Creates the memory counters.
  const new({this.entryCount = 0, this.estimatedSize = 0, this.hitCount = 0, this.missCount = 0});

  /// Live entries.
  final int entryCount;

  /// Estimated bytes held.
  final int estimatedSize;

  /// Reads answered from memory.
  final int hitCount;

  /// Reads that found nothing or an expired value.
  final int missCount;

  /// Hits over all reads; 0 when nothing was asked yet.
  double get hitRate {
    final total = hitCount + missCount;
    return total == 0 ? 0 : hitCount / total;
  }
}

/// Everything the settings surface prints about the cache.
@immutable
final class CacheStatistics {
  /// Creates the aggregate.
  const new({
    this.image = const ImageCacheStatistics(),
    this.apiMemory = const MemoryCacheStatistics(),
    this.lastCleanupAt,
    this.diskAvailable = false,
  });

  /// Image cache counters.
  final ImageCacheStatistics image;

  /// API memory cache counters.
  final MemoryCacheStatistics apiMemory;

  /// The last explicit cleanup, or null when none ran.
  final DateTime? lastCleanupAt;

  /// Whether the disk layer is usable.
  final bool diskAvailable;

  /// Bytes on disk.
  int get totalDiskSize => image.diskSize;

  /// Estimated decoded plus API memory bytes.
  int get totalMemorySize => image.memorySize + apiMemory.estimatedSize;
}
