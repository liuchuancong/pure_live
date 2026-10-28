import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;

import 'package:pure_live/shared/areas/area_icon.dart';

/// One area as a card: its picture, its name, the parent group it sits in
/// when the platform nests areas, and an optional control at the end.
///
/// The surface is [DsCard]'s, so hover, press and the keyboard focus ring
/// come with it. [filled] gives the card the control fill, for a page that
/// lays its cards directly on the surface.
final class AreaCard extends StatelessWidget {
  /// The card for [area].
  const AreaCard({
    required this.area,
    required this.onPressed,
    this.parentLabel,
    this.trailing,
    this.filled = false,
    super.key,
  });

  /// The area shown.
  final LiveArea area;

  /// Fired when the card opens the area; null leaves it inert.
  final VoidCallback? onPressed;

  /// The parent group's name; the area's own when null.
  final String? parentLabel;

  /// A control at the card's end, e.g. the follow heart.
  final Widget? trailing;

  /// Draws the card on the control fill instead of the surface.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final parent = (parentLabel ?? area.parentAreaName ?? '').trim();
    return DsCard(
      onPressed: onPressed,
      semanticLabel: area.areaName,
      style: DsCardStyle(
        padding: const EdgeInsets.all(DsSpace.s12),
        background: filled ? colors.control : colors.surface,
        hovered: DsCardStyle(
          background: colors.hover,
          shadows: [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))],
        ),
      ),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          AreaIcon(area: area),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: DsSpace.s3,
              children: [
                Text(
                  area.areaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
                if (parent.isNotEmpty)
                  Text(
                    parent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
