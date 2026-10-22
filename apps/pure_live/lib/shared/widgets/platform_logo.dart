import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The bundled icon of one platform, at a fixed size.
///
/// The icons ship with `live_sites` (`packages/live_sites/assets/platforms/<id>.png`),
/// so the file is addressed through its package prefix; a platform without an
/// icon on disk — or a file that fails to decode — falls back to the first
/// letter of its id in a tinted disc, so a missing asset reads as a name, not
/// as a hole.
final class PlatformLogo extends StatelessWidget {
  /// The logo of [siteId].
  const new({required this.siteId, this.size = 24, super.key});

  /// The platform's stable id.
  final String siteId;

  /// The square's edge.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 5),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'packages/live_sites/assets/platforms/$siteId.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => ColoredBox(
            color: theme.colorScheme.primaryContainer,
            child: Center(
              child: Text(
                siteId.isEmpty ? '?' : siteId.substring(0, 1).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The network-loaded logo of a platform, for places that show a site the
/// registry does not carry (a stored follow of an uninstalled adapter).
/// Falls back to [PlatformLogo]'s disc.
final class PlatformLogoNetwork extends StatelessWidget {
  /// The logo from [url]; empty shows nothing.
  const new({required this.url, this.size = 24, super.key});

  /// Where the picture lives.
  final String? url;

  /// The square's edge.
  final double size;

  @override
  Widget build(BuildContext context) {
    final address = url ?? '';
    if (address.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 5),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(imageUrl: address, width: size, height: size, fit: BoxFit.contain),
      ),
    );
  }
}
