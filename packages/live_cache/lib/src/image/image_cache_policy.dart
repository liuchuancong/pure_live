import 'package:live_cache/src/models/cache_priority.dart';
import 'package:meta/meta.dart';

/// What the cache does when the disk copy is past its TTL.
enum ImageExpiryMode {
  /// Draw the stale copy at once and refresh it in the background. The
  /// picture on screen changes in place when the fresh bytes land.
  staleWhileRevalidate,

  /// Fetch first and draw the result; when the fetch fails the stale copy
  /// stands in if the policy allows it.
  refreshBeforeDisplay,

  /// Never open a connection: serve the disk copy, or report a miss.
  cacheOnly,
}

/// One image category's caching rules.
///
/// Policies are immutable values. The presets in `ImageCachePolicies` cover
/// the product's image uses; a caller with a special case builds its own.
@immutable
final class ImageCachePolicy {
  /// Creates a policy for [category].
  const new({
    required this.category,
    required this.ttl,
    this.priority = CachePriority.normal,
    this.memoryCache = true,
    this.diskCache = true,
    this.maxImageSize,
    this.mode = ImageExpiryMode.staleWhileRevalidate,
    this.maxStale = const Duration(days: 7),
    this.fallbackToStale = true,
    this.version,
  }) : assert(maxImageSize == null || maxImageSize > 0, 'A size cap must be positive.');

  /// The category name; also the folder under `images/`.
  final String category;

  /// How long bytes stay fresh. Null means permanent: never expires on its
  /// own, only an explicit clear or a capacity emergency removes it.
  final Duration? ttl;

  /// The cleanup ranking when the cache is over its cap.
  final CachePriority priority;

  /// Whether decoded images may stay in Flutter's `ImageCache`.
  final bool memoryCache;

  /// Whether bytes may be written to and served from disk.
  final bool diskCache;

  /// A per-category hard limit for one image; null uses the global limit.
  final int? maxImageSize;

  /// What happens once the TTL passes.
  final ImageExpiryMode mode;

  /// How long past [ttl] a copy may still stand in. Null keeps it usable
  /// forever while a refresh happens; ignored for permanent entries.
  final Duration? maxStale;

  /// Whether [ImageExpiryMode.refreshBeforeDisplay] falls back to the stale
  /// copy when the network fails.
  final bool fallbackToStale;

  /// A business version folded into the cache key; changing it makes a new
  /// file and abandons the old one.
  final String? version;

  /// Whether the policy never expires on its own.
  bool get isPermanent => ttl == null;

  /// The TTL after the viewer's freshness multiplier (0.5 fresher, 2
  /// thriftier); permanent policies ignore [scale].
  Duration? effectiveTtl(double scale) => ttl == null ? null : ttl! * scale;

  /// The per-image limit after combining the policy with the global cap.
  int effectiveMaxImageSize(int globalLimit) {
    final own = maxImageSize;
    return own == null || own > globalLimit ? globalLimit : own;
  }

  /// The policy with the named fields replaced.
  ImageCachePolicy copyWith({
    String? category,
    Duration? ttl,
    CachePriority? priority,
    bool? memoryCache,
    bool? diskCache,
    int? maxImageSize,
    ImageExpiryMode? mode,
    Duration? maxStale,
    bool? fallbackToStale,
    String? version,
    bool clearTtl = false,
  }) => ImageCachePolicy(
    category: category ?? this.category,
    ttl: clearTtl ? null : (ttl ?? this.ttl),
    priority: priority ?? this.priority,
    memoryCache: memoryCache ?? this.memoryCache,
    diskCache: diskCache ?? this.diskCache,
    maxImageSize: maxImageSize ?? this.maxImageSize,
    mode: mode ?? this.mode,
    maxStale: maxStale ?? this.maxStale,
    fallbackToStale: fallbackToStale ?? this.fallbackToStale,
    version: version ?? this.version,
  );
}
