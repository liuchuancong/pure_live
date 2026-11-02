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
/// The surface is [DsCard]'s own — the theme's card fill and corner, so the
/// card follows the viewer's radius and the glass's translucency exactly as
/// the room cards do — and hover, press and the keyboard focus ring come
/// with it.
final class AreaCard extends StatelessWidget {
  /// The card for [area].
  const AreaCard({
    required this.area,
    required this.onPressed,
    this.parentLabel,
    this.trailing,
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

  /// Whether the picture sits beside the name or above it.
  final AreaCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    final parent = (parentLabel ?? area.parentAreaName ?? '').trim();
    // The poster centres its name under the picture; the row keeps it
    // flush with the picture's side.
    final textAlign = layout == AreaCardLayout.tile ? TextAlign.center : TextAlign.start;
    final name = Text(
      area.areaName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
    );
    final group = parent.isEmpty
        ? null
        : Text(
            parent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          );
    return DsCard(
      onPressed: onPressed,
      semanticLabel: area.areaName,
      style: DsCardStyle(padding: layout == AreaCardLayout.tile ? EdgeInsets.zero : const EdgeInsets.all(DsSpace.s12)),
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
        // The reference's poster: the picture a full-width rounded square
        // under the card's own inset, the name centred under it with the
        // group a quiet line below — never a picture floating in leftover
        // room. The heart keeps the corner over the picture.
        AreaCardLayout.tile => Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s12, DsSpace.s12, DsSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The square takes the tile's width; a tile squeezed
                  // narrower than its measure shrinks the picture, never
                  // the words under it.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.topCenter,
                        child: AreaIcon(area: area, side: constraints.biggest.shortestSide, radius: theme.radii.card),
                      ),
                    ),
                  ),
                  const SizedBox(height: DsSpace.s8),
                  name,
                  if (group != null) ...[const SizedBox(height: 2), group],
                ],
              ),
            ),
            if (trailing case final trailing?)
              PositionedDirectional(
                top: DsSpace.s12,
                end: DsSpace.s12,
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
