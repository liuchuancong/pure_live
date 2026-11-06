import 'package:live_cache/src/models/image_cache_config.dart';
import 'package:live_cache/src/models/memory_cache_config.dart';
import 'package:meta/meta.dart';

/// Everything the host may tune about the cache.
@immutable
final class LiveCacheConfig {
  /// Creates a configuration from its two halves.
  const new({this.image = const ImageCacheConfig(), this.apiMemory = const MemoryCacheConfig()});

  /// Image cache limits and refresh behaviour.
  final ImageCacheConfig image;

  /// The optional in-memory API cache's limits.
  final MemoryCacheConfig apiMemory;

  /// The configuration with the named halves replaced.
  LiveCacheConfig copyWith({ImageCacheConfig? image, MemoryCacheConfig? apiMemory}) =>
      LiveCacheConfig(image: image ?? this.image, apiMemory: apiMemory ?? this.apiMemory);
}
