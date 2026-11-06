import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:live_cache/live_cache.dart';

/// The app's one installed cache.
///
/// Every networked picture in the app goes through [cachedImage], which
/// builds a `LiveCacheImage` over this manager: one clearable tree with
/// per-category TTLs, a disk cap, stale-while-revalidate refreshes and the
/// statistics the settings pane prints. The boot installs the manager before
/// the first frame; a widget has no business constructing its own.
LiveCacheManager? _installed;

/// The manager in force. A call before the boot installs one is a wiring bug,
/// not a state a page should handle.
LiveCacheManager get liveCacheManager =>
    _installed ?? (throw StateError('The live cache is not installed; the app boot must call installLiveCacheManager.'));

/// The manager in force, or null before the boot installed one.
LiveCacheManager? get installedLiveCacheManager => _installed;

/// Points this engine at [manager]. Called by the boot/root before the first
/// network image is asked for.
void installLiveCacheManager(LiveCacheManager manager) {
  _installed = manager;
}

/// A network image through the installed cache.
///
/// [policy] names the business category (a cover, an avatar, an emote…); the
/// default covers an image whose caller has no stronger claim. [width] and
/// [height] ask for a decode box, so a thumbnail never decodes at full size.
/// [cacheKey] is the stable identity for a server that rotates signed query
/// strings; [version] invalidates a changed picture without a new URL.
ImageProvider cachedImage(
  String url, {
  ImageCachePolicy? policy,
  int? width,
  int? height,
  String? cacheKey,
  String? version,
  String? accountScope,
  Map<String, String> headers = const {},
}) {
  final manager = liveCacheManager;
  return LiveCacheImage(
    cache: manager.image,
    request: ImageCacheRequest(
      url: Uri.parse(url),
      policy: policy ?? ImageCachePolicies.general,
      cacheKey: cacheKey,
      version: version,
      accountScope: accountScope,
      headers: headers,
    ),
    width: width,
    height: height,
  );
}

/// A byte count in the settings surface's words: B, KB or MB, one decimal.
String formatCacheSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
