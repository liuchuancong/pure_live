import 'package:meta/meta.dart';

/// The image cache's tunable limits.
///
/// Values arrive from the host application's settings surface; the package
/// itself persists none of them.
@immutable
final class ImageCacheConfig {
  /// Creates a configuration with the defaults of the specification:
  /// 1 GB on disk, 30 MB per image, a balanced freshness multiplier and
  /// automatic cleanup on.
  const new({
    this.diskCacheEnabled = true,
    this.autoClean = true,
    this.maxDiskBytes = 1024 * 1024 * 1024,
    this.maxImageBytes = 30 * 1024 * 1024,
    this.ttlScale = 1.0,
    this.cleanupTargetRatio = 0.9,
    this.timeout = const Duration(seconds: 20),
  }) : assert(maxDiskBytes > 0, 'The disk cache needs a positive cap.'),
       assert(maxImageBytes > 0, 'A single image needs a positive cap.'),
       assert(ttlScale > 0, 'The TTL multiplier must be positive.'),
       assert(cleanupTargetRatio > 0 && cleanupTargetRatio <= 1, 'Cleanup must leave a usable cache.');

  /// Whether bytes may be written to disk. Off keeps memory and network
  /// working; existing files stay until the next clear.
  final bool diskCacheEnabled;

  /// Whether a write after the cap is exceeded prunes the cache.
  final bool autoClean;

  /// The cap the cache prunes down to.
  final int maxDiskBytes;

  /// The largest single image the cache accepts.
  final int maxImageBytes;

  /// Multiplies every policy TTL except `permanent`: 0.5 asks for fresher
  /// images, 2 keeps traffic down.
  final double ttlScale;

  /// How much of [maxDiskBytes] cleanup keeps after pruning.
  final double cleanupTargetRatio;

  /// The per-phase network timeout for one image.
  final Duration timeout;

  /// The configuration with the named fields replaced.
  ImageCacheConfig copyWith({
    bool? diskCacheEnabled,
    bool? autoClean,
    int? maxDiskBytes,
    int? maxImageBytes,
    double? ttlScale,
    double? cleanupTargetRatio,
    Duration? timeout,
  }) => ImageCacheConfig(
    diskCacheEnabled: diskCacheEnabled ?? this.diskCacheEnabled,
    autoClean: autoClean ?? this.autoClean,
    maxDiskBytes: maxDiskBytes ?? this.maxDiskBytes,
    maxImageBytes: maxImageBytes ?? this.maxImageBytes,
    ttlScale: ttlScale ?? this.ttlScale,
    cleanupTargetRatio: cleanupTargetRatio ?? this.cleanupTargetRatio,
    timeout: timeout ?? this.timeout,
  );
}
