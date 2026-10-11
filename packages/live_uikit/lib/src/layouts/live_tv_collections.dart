import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/core/ui_configuration.dart';
import 'package:live_uikit/src/layouts/live_tv_scaffold.dart';
import 'package:live_uikit/src/theme/live_theme.dart';

/// A horizontally scrolling TV row: a title, the items, and optional
/// "see all" action.
///
/// A TV home page is a stack of these, and the interaction that matters is
/// the one this widget owns: the row scrolls itself as the remote moves
/// through it ([LiveFocusReveal]), so the highlight never leaves the screen.
/// What happens at the end of the row is the page's decision, not the row's —
/// a page that wraps uses `LiveFocusNavigation.move(… wrap: true)` in its
/// direction handler, because only the page knows whether wrapping or moving
/// to the next row is what the user means.
class LiveTvSection extends StatelessWidget {
  /// A TV section.
  const new({
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
    this.height,
    this.itemSpacing,
    this.padding,
    this.controller,
    super.key,
  });

  /// The section title, drawn at section-header size.
  final String title;

  /// How many items the row holds.
  final int itemCount;

  /// Builds the item at an index.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Opens the full list of this section.
  final VoidCallback? onSeeAll;

  /// The label of the "see all" action.
  final String seeAllLabel;

  /// The row height; null lets the items size themselves.
  final double? height;

  /// The gap between items.
  final double? itemSpacing;

  /// The section's outer padding.
  final EdgeInsetsGeometry? padding;

  /// The row's scroll controller, for pages that steer it.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final spacing = itemSpacing ?? geometry.sectionGap;
    final outer = padding ?? EdgeInsets.symmetric(vertical: geometry.iconGap);
    return Padding(
      padding: outer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: geometry.iconGap),
            child: Row(
              children: [
                Expanded(child: Text(title, style: theme.typography.headline)),
                if (onSeeAll case final onSeeAll?) _SeeAllButton(label: seeAllLabel, onPressed: onSeeAll),
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: LiveFocusReveal(
              margin: EdgeInsets.symmetric(horizontal: geometry.controlPadding),
              child: ListView.separated(
                controller: controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: geometry.iconGap),
                itemCount: itemCount,
                separatorBuilder: (context, index) => SizedBox(width: spacing),
                itemBuilder: itemBuilder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "see all" affordance of a section header.
class _SeeAllButton extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.componentTheme.iconGap),
        child: Text(label, style: theme.typography.bodySmall.copyWith(color: theme.colors.primary)),
      ),
    );
  }
}

/// A wrapping grid of focusable TV items that scrolls with the focus.
///
/// The grid is the TV alternative to a phone's infinite-scrolling list: a
/// few large rows of big cards, each reachable by d-pad, the picture
/// following the highlight. Columns come from the theme's density — a TV
/// shows fewer, larger cards than a desktop — so the same page code lays out
/// correctly on both.
class LiveTvContentGrid extends StatelessWidget {
  /// A TV grid.
  const new({
    required this.itemCount,
    required this.itemBuilder,
    this.columns,
    this.spacing,
    this.padding,
    this.controller,
    super.key,
  });

  /// How many items the grid holds.
  final int itemCount;

  /// Builds the item at an index.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Overrides the column count the density implies.
  final int? columns;

  /// The gap between cells.
  final double? spacing;

  /// The grid's outer padding.
  final EdgeInsetsGeometry? padding;

  /// The grid's scroll controller, for pages that steer it.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = theme.componentTheme;
    final gap = spacing ?? geometry.sectionGap;
    final count =
        columns ??
        switch (geometry.density) {
          LiveUiDensity.compact => 6,
          LiveUiDensity.comfortable => 4,
          LiveUiDensity.spacious => 3,
        };
    return LiveFocusReveal(
      margin: EdgeInsets.all(gap),
      child: GridView.builder(
        controller: controller,
        padding: padding ?? geometry.pagePadding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: geometry.cardRadius > 16 ? 1.6 : 1.4,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
