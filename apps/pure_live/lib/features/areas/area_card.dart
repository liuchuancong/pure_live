import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;
import 'package:pure_uikit/pure_uikit.dart';

/// Shared geometry for the area grids (3.x `areaCardGridMainAxisExtent`):
/// the catalogue packs small square tiles, more of them as the window
/// widens, and every tile reserves the square picture plus its one or two
/// label lines.
abstract final class AreaGridMetrics {
  /// Columns by width: three on a phone up to nine on a wide desktop.
  static int columnsFor(double width) => width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));

  /// The tile height for an [itemWidth]: the square picture plus the labels,
  /// growing with the ambient text scale.
  static double mainAxisExtent(double itemWidth, TextScaler textScaler) {
    const labelSize = 12.0;
    const lineHeight = 1.4;
    final textHeight = 2 * textScaler.scale(labelSize) * lineHeight + 2;
    return itemWidth + math.max(56.0, textHeight + 24);
  }
}

/// An area tile (3.x `AreaCard`): the square picture over the name and, when
/// the site reports one, its parent category. Tapping it opens the area's
/// room list.
final class AreaCard extends StatelessWidget {
  /// Shows [area]; [onOpen] opens the area's room list.
  const new({required this.area, required this.onOpen, super.key});

  /// The area this tile shows.
  final LiveArea area;

  /// Called when the tile is tapped.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final parent = area.parentAreaName ?? '';
    return PureCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: switch (area.iconUrl) {
              final url? when url.isNotEmpty => CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(theme),
              ),
              _ => _fallback(theme),
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area.areaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                if (parent.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    parent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(PureTheme theme) => ColoredBox(
    color: theme.colors.fillQuaternary,
    child: Center(child: Icon(Icons.category_outlined, color: theme.colors.textQuaternary)),
  );
}
