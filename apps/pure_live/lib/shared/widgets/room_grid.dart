import 'package:flutter/material.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/shared/widgets/room_card.dart' show RoomGridMetrics;
import 'package:pure_uikit/pure_uikit.dart' show PureSpacing;

/// The room cards, in a waterfall.
///
/// The grids used to hand every tile a height they had to guess:
/// `RoomGridMetrics.mainAxisExtent` measured the caption out of hard-coded font
/// sizes and the text scaler, and a card that came out taller than the estimate —
/// a larger text scale, a language whose body line is taller, a card with the
/// anchor line switched off — was clipped or overflowed inside its own tile. A
/// mosaic tile is given its column width and keeps its own height, so the
/// estimate and that whole class of failure go away, while the columns still come
/// from the same width ladder the placeholder draws.
///
/// The layout is [MosaicLayout.masonry] rather than rows: rows would stretch every
/// tile in a line to its tallest member, which is the same uniformity the grid was
/// computing by hand before, bought with a second pass.
///
/// [footer] is where a "loading more" row belongs. It used to be one more item in
/// [itemCount], which a uniform grid could get away with and a waterfall cannot:
/// a full-width status row is a tile in one column there, floating at half the
/// window's width.
final class RoomGrid extends StatelessWidget {
  /// The grid; [columns] overrides the discovery ladder where a surface reads
  /// its cards larger.
  const new({
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.sm, PureSpacing.sm, PureSpacing.xl),
    this.footer,
    this.columns,
    this.shrinkWrap = false,
    this.physics,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    super.key,
  });

  /// Number of cards.
  final int itemCount;

  /// Builds the card at an index.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The scroll position the page's jump buttons drive.
  final ScrollController? scrollController;

  /// The grid's own padding; the gap between cards is [PureSpacing.sm] and is
  /// not the caller's business any more than the card height is.
  final EdgeInsets padding;

  /// A full-width row after the last card.
  final Widget? footer;

  /// Column count, or null to take it from the width.
  final int? columns;

  /// Whether the grid sizes itself to its content inside a scrolling parent.
  final bool shrinkWrap;

  /// Scroll physics, for the embedded case where the parent owns the scroll.
  final ScrollPhysics? physics;

  /// Whether a drag on the grid dismisses the keyboard.
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MosaicGrid.builder(
      columns: MosaicColumns.count(columns ?? RoomGridMetrics.columnsFor(constraints.maxWidth)),
      layout: const MosaicLayout.masonry(),
      columnGap: PureSpacing.sm,
      rowGap: PureSpacing.sm,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      footer: footer,
      scrollController: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      keyboardDismissBehavior: keyboardDismissBehavior,
    ),
  );
}

/// The same grid as a sliver, for a page whose scroll view is a
/// [CustomScrollView] — the history list's day groups, each with its own grid.
///
/// [width] is the cross-axis the columns divide: a sliver has no constraints of
/// its own to measure, so the caller's `LayoutBuilder` hands it down.
final class SliverRoomGrid extends StatelessWidget {
  /// The sliver; [itemCount] cards laid out across [width].
  const new({required this.width, required this.itemCount, required this.itemBuilder, super.key});

  /// The width the column ladder reads.
  final double width;

  /// Number of cards.
  final int itemCount;

  /// Builds the card at an index.
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) => SliverMosaicGrid.builder(
    columns: MosaicColumns.count(RoomGridMetrics.columnsFor(width)),
    layout: const MosaicLayout.masonry(),
    columnGap: PureSpacing.sm,
    rowGap: PureSpacing.sm,
    itemCount: itemCount,
    itemBuilder: itemBuilder,
  );
}
