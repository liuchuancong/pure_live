import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/network/image_cache_manager.dart';

/// A wallpaper picture loaded straight from its absolute CDN URL.
///
/// Every catalogue entry carries absolute URLs, so the only fallback worth
/// having is "grid copy failed, use the full picture": a thumbnail can 404 while
/// the original is fine, and showing a broken tile in that case made the whole
/// library look unloadable.
class WallpaperNetworkImage extends StatefulWidget {
  const WallpaperNetworkImage({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.placeholder,
    this.fallback,
  });

  /// Absolute URL of the picture.
  final String url;

  /// Tried when [url] fails; usually the unresized original.
  final String? fallbackUrl;

  final BoxFit fit;
  final int? memCacheWidth;

  /// Shown while loading and while a candidate is being replaced.
  final Widget? placeholder;

  /// Shown when every candidate failed.
  final Widget? fallback;

  @override
  State<WallpaperNetworkImage> createState() => _WallpaperNetworkImageState();
}

class _WallpaperNetworkImageState extends State<WallpaperNetworkImage> {
  int _attempt = 0;
  bool _dead = false;

  List<String> get _candidates => <String>[
    if (widget.url.isNotEmpty) widget.url,
    if ((widget.fallbackUrl ?? '').isNotEmpty && widget.fallbackUrl != widget.url) widget.fallbackUrl!,
  ];

  @override
  void didUpdateWidget(covariant WallpaperNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fallbackUrl != widget.fallbackUrl) {
      _attempt = 0;
      _dead = false;
    }
  }

  void _next() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final int next = _attempt + 1;
      if (next >= _candidates.length) {
        if (!_dead) setState(() => _dead = true);
        return;
      }
      setState(() => _attempt = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dead) return widget.fallback ?? const SizedBox.shrink();

    final List<String> candidates = _candidates;
    if (candidates.isEmpty) return widget.fallback ?? const SizedBox.shrink();

    final String url = candidates[_attempt.clamp(0, candidates.length - 1)];
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppImageCacheManager.instance,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) => widget.placeholder ?? const SizedBox.shrink(),
      errorWidget: (context, _, _) {
        _next();
        return widget.placeholder ?? const SizedBox.shrink();
      },
    );
  }
}
