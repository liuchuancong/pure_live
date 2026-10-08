import 'dart:math' as math;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_image.dart';
import 'package:remixicon/remixicon.dart';

/// One tile of the wallpaper grid: pictures load a grid-sized copy, live
/// wallpapers show their poster, gradients are painted locally.
class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key, required this.item, required this.kind, required this.selected, required this.onTap});

  final WallpaperItem item;
  final WallpaperKind kind;

  /// Marks the entry that backs the background in use right now.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(14);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _artwork(theme),
            if (item.name != null && item.name!.isNotEmpty)
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Text(
                  item.name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
            if (kind == WallpaperKind.video)
              const Positioned(top: 6, left: 8, child: Icon(Remix.play_circle_line, color: Colors.white, size: 20)),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Remix.check_line, size: 15, color: theme.colorScheme.onPrimary),
                ),
              ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: theme.colorScheme.primary, width: 3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _artwork(ThemeData theme) {
    if (kind == WallpaperKind.gradient) return GradientPreview(item: item);
    final String poster = item.poster?.isNotEmpty == true ? item.poster! : item.file;
    if (poster.isEmpty) return const SizedBox.shrink();
    return WallpaperNetworkImage(
      url: item.thumb?.isNotEmpty == true ? item.thumb! : poster,
      fallbackUrl: poster,
      memCacheWidth: 480,
      placeholder: ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
      fallback: const Center(child: Icon(Remix.image_line, color: Colors.white54)),
    );
  }
}

/// Paints a gradient tile locally; no download involved.
///
/// The angle follows the CSS convention the source table uses (0deg points up,
/// positive is clockwise), so a 120deg gradient runs the same way here as it
/// does on the iTab new-tab page.
class GradientPreview extends StatelessWidget {
  const GradientPreview({super.key, required this.item});

  final WallpaperItem item;

  /// CSS angle -> Flutter begin/end alignment pair.
  static (Alignment, Alignment) alignmentsFor(int deg) {
    final double radians = deg * math.pi / 180;
    final double x = math.sin(radians);
    final double y = -math.cos(radians);
    if (x == 0 && y == 0) return (Alignment.bottomCenter, Alignment.topCenter);
    return (Alignment(-x, -y), Alignment(x, y));
  }

  @override
  Widget build(BuildContext context) {
    final List<WallpaperGradientStop> stops = item.gradient ?? const <WallpaperGradientStop>[];
    final List<Color> colors = <Color>[];
    final List<double> positions = <double>[];
    for (final WallpaperGradientStop stop in stops) {
      final Color? color = colorFromHex(stop.color);
      if (color == null) continue;
      colors.add(color);
      positions.add((stop.pos / 100).clamp(0.0, 1.0));
    }
    if (colors.isEmpty) return const ColoredBox(color: Color(0xFF141E30));
    if (colors.length < 2) return ColoredBox(color: colors.first);

    final (Alignment begin, Alignment end) = alignmentsFor(item.deg);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: begin, end: end, colors: colors, stops: positions),
      ),
    );
  }
}
