import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;

import 'package:pure_live/shared/images/images.dart' show cachedImage;

/// An area's picture: the icon the site ships, or the tag tile when it ships
/// none — either way the square keeps its place beside the name.
final class AreaIcon extends StatelessWidget {
  /// The tile for [area].
  const AreaIcon({required this.area, this.side, super.key});

  /// The area whose icon shows.
  final LiveArea area;

  /// The square's side; the theme's medium control size when null.
  final double? side;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final side = this.side ?? theme.sizes.md;
    final url = (area.iconUrl ?? '').trim();
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
        borderRadius: BorderRadius.circular(theme.radii.control(side)),
        child: url.isEmpty
            ? fallback
            : DsImage(
                image: cachedImage(url),
                width: side,
                height: side,
                semanticLabel: area.areaName,
                fallback: fallback,
              ),
      ),
    );
  }
}
