import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The loading shapes the data pages settle into: the grid of cover blocks a
/// wall of cards becomes, and the rows of face-and-words a list becomes —
/// so a page's first paint already has the content's own silhouette instead
/// of a spinner's dot.
final class SkeletonGrid extends StatelessWidget {
  /// A viewport-filling grid of [tiles] cover blocks.
  const SkeletonGrid({
    this.tiles = 12,
    this.childAspectRatio = 16 / 13,
    this.padding = const EdgeInsets.all(DsSpace.s16),
    this.crossAxisSpacing = DsSpace.s12,
    this.mainAxisSpacing = DsSpace.s12,
    super.key,
  });

  /// How many blocks fill the first paint.
  final int tiles;

  /// The block's tile shape, the room card's own.
  final double childAspectRatio;

  final EdgeInsetsGeometry padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: tiles,
      itemBuilder: (context, index) => const DsSkeleton.block(width: double.infinity),
    );
  }
}

/// A column of [rows] list rows: a face circle over two quiet bars, the
/// shape a row of names settles into.
final class SkeletonRows extends StatelessWidget {
  const SkeletonRows({this.rows = 8, this.leading = 40, this.trailing = true, super.key});

  final int rows;

  /// The face circle's size.
  final double leading;

  /// Whether each row ends in a short bar (a duration, a count).
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
      children: [
        for (final _ in List<int>.generate(rows, (index) => index))
          Row(
            spacing: DsSpace.s12,
            children: [
              DsSkeleton.circle(size: leading),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s8,
                  children: [
                    DsSkeleton(width: double.infinity, height: 14),
                    DsSkeleton(width: 140, height: 12),
                  ],
                ),
              ),
              if (trailing) const DsSkeleton(width: 48, height: 12),
            ],
          ),
      ],
    );
  }
}
