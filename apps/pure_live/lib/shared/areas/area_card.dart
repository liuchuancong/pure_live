import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:live_sites/live_sites.dart' show LiveArea;

import 'package:pure_live/shared/areas/area_icon.dart';

/// How an area's card draws its picture and name.
enum AreaCardLayout {
  /// The icon beside the name: a wide row a catalogue can lay in columns.
  row,

  /// The icon above the name: a poster tile, the reference's catalogue.
  tile,
}

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
    this.layout = AreaCardLayout.row,
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

  /// Whether the picture sits beside the name or above it.
  final AreaCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final parent = (parentLabel ?? area.parentAreaName ?? '').trim();
    final name = Text(
      area.areaName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
    );
    final group = parent.isEmpty
        ? null
        : Text(
            parent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          );
    return DsCard(
      onPressed: onPressed,
      semanticLabel: area.areaName,
      style: DsCardStyle(
        padding: layout == AreaCardLayout.tile ? EdgeInsets.zero : const EdgeInsets.all(DsSpace.s12),
        background: filled ? colors.control : colors.surface,
        hovered: DsCardStyle(
          background: colors.hover,
          shadows: [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))],
        ),
      ),
      child: switch (layout) {
        AreaCardLayout.row => Row(
          spacing: DsSpace.s12,
          children: [
            AreaIcon(area: area),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: DsSpace.s3,
                children: [name, ?group],
              ),
            ),
            ?trailing,
          ],
        ),
        AreaCardLayout.tile => Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // The picture keeps its square and fills the room the
                    // name leaves, however wide the tile gets.
                    child: LayoutBuilder(
                      builder: (context, constraints) => Center(
                        child: AreaIcon(area: area, side: constraints.biggest.shortestSide),
                      ),
                    ),
                  ),
                  const SizedBox(height: DsSpace.s6),
                  name,
                  ?group,
                ],
              ),
            ),
            // The heart keeps the corner the catalogue's posters carry; the
            // surface disc keeps it legible over a busy logo.
            if (trailing case final trailing?)
              PositionedDirectional(
                top: DsSpace.s4,
                end: DsSpace.s4,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surface.withValues(alpha: 0.85)),
                  child: Padding(padding: const EdgeInsets.all(DsSpace.s4), child: trailing),
                ),
              ),
          ],
        ),
      },
    );
  }
}
