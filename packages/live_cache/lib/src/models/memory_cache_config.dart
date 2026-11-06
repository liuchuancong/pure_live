import 'package:meta/meta.dart';

/// Limits for the optional in-memory API cache.
@immutable
final class MemoryCacheConfig {
  /// Creates a configuration holding at most [maxEntries] values or
  /// [maxBytes] estimated bytes, whichever comes first.
  const new({this.maxEntries = 200, this.maxBytes = 8 * 1024 * 1024, this.defaultTtl = const Duration(minutes: 5)})
    : assert(maxEntries > 0, 'The memory cache needs at least one slot.'),
      assert(maxBytes > 0, 'The memory cache needs a positive cap.');

  /// The hard entry-count limit.
  final int maxEntries;

  /// The estimated-size limit; an entry larger than this is refused.
  final int maxBytes;

  /// The TTL used when a caller does not pass one.
  final Duration defaultTtl;

  /// The configuration with the named fields replaced.
  MemoryCacheConfig copyWith({int? maxEntries, int? maxBytes, Duration? defaultTtl}) => MemoryCacheConfig(
    maxEntries: maxEntries ?? this.maxEntries,
    maxBytes: maxBytes ?? this.maxBytes,
    defaultTtl: defaultTtl ?? this.defaultTtl,
  );
}
