import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart' show LiveArea;

import 'package:pure_live/shared/images/images.dart' show cachedImage;

/// An area's picture: the icon the site ships, a tile bundled with
/// `live_sites` for a catalogue that ships none, or the tag tile when neither
/// exists — either way the square keeps its place beside the name.
final class AreaIcon extends StatelessWidget {
  /// The tile for [area].
  const AreaIcon({required this.area, this.side, this.radius, super.key});

  /// The area whose icon shows.
  final LiveArea area;

  /// The square's side; the theme's medium control size when null.
  final double? side;

  /// The corner radius; the control radius for [side] when null. A poster
  /// tile passes the card's own corner.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final side = this.side ?? theme.sizes.md;
    final url = (area.iconUrl ?? '').trim();
    final bundled = url.startsWith(LiveArea.bundledIconPrefix)
        ? url.substring(LiveArea.bundledIconPrefix.length).trim()
        : null;
    // A site without a picture of its own ships a bundled tile instead
    // (Douyin's catalogue); every other icon is a network address.
    final image = switch ((url, bundled)) {
      (_, final String path) => path.isEmpty ? null : AssetImage(path, package: 'live_sites'),
      ('', _) => null,
      _ => cachedImage(url, policy: ImageCachePolicies.categoryCover),
    };
    final fallback = ColoredBox(
      color: colors.channel,
      child: Center(
        child: DsIcon(DsIcons.tag, size: side * 0.4, color: colors.textMuted),
      ),
    );
    return SizedBox(
      width: side,
      height: side,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? theme.radii.control(side)),
        child: image == null
            ? fallback
            : DsImage(image: image, width: side, height: side, semanticLabel: area.areaName, fallback: fallback),
      ),
    );
  }
}
