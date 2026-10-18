import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_breakpoints.dart';

/// A breakpoint-aware grid for channel cards, posters, and tiles.
///
/// Column counts are defined per [AdaptiveBreakpoint]. If there are fewer
/// children than columns, the grid shrinks to the number of children so a row
/// of five cards does not leave an awkward empty sixth slot.
class ResponsiveGrid extends StatelessWidget {
  /// A grid of [children] with per-class column counts.
  const new({
    required this.children,
    this.compactColumns = 2,
    this.mediumColumns = 3,
    this.expandedColumns = 5,
    this.largeColumns = 6,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 1.1,
    this.mainAxisExtent,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  /// The tiles, in order.
  final List<Widget> children;

  /// Columns in the compact class.
  final int compactColumns;

  /// Columns in the medium class.
  final int mediumColumns;

  /// Columns in the expanded class.
  final int expandedColumns;

  /// Columns in the large class.
  final int largeColumns;

  /// The gap along the scroll axis.
  final double mainAxisSpacing;

  /// The gap across the scroll axis.
  final double crossAxisSpacing;

  /// The tile aspect, used when [mainAxisExtent] is null.
  final double childAspectRatio;

  /// Fixed item height; takes priority over [childAspectRatio].
  final double? mainAxisExtent;

  /// The grid's padding.
  final EdgeInsetsGeometry padding;

  /// Passed to the inner grid view.
  final bool shrinkWrap;

  /// Passed to the inner grid view.
  final ScrollPhysics? physics;

  /// Passed to the inner grid view.
  final ScrollController? controller;

  /// Passed to the inner grid view.
  final bool addAutomaticKeepAlives;

  /// Passed to the inner grid view.
  final bool addRepaintBoundaries;

  /// Passed to the inner grid view.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 0;
        final columns = resolveAdaptiveColumns(
          width: width,
          childCount: children.length,
          compact: compactColumns,
          medium: mediumColumns,
          expanded: expandedColumns,
          large: largeColumns,
        );

        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          controller: controller,
          clipBehavior: clipBehavior,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

/// Sliver version of [ResponsiveGrid] for [CustomScrollView] layouts.
///
/// This variant avoids `shrinkWrap` and keeps the grid lazy, which is the
/// preferred structure for the main content surface.
class SliverResponsiveGrid extends StatelessWidget {
  /// A sliver grid of [children] with per-class column counts.
  const new({
    required this.children,
    this.compactColumns = 2,
    this.mediumColumns = 3,
    this.expandedColumns = 5,
    this.largeColumns = 6,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 1.1,
    this.mainAxisExtent,
    this.padding = EdgeInsets.zero,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    super.key,
  });

  /// The tiles, in order.
  final List<Widget> children;

  /// Columns in the compact class.
  final int compactColumns;

  /// Columns in the medium class.
  final int mediumColumns;

  /// Columns in the expanded class.
  final int expandedColumns;

  /// Columns in the large class.
  final int largeColumns;

  /// The gap along the scroll axis.
  final double mainAxisSpacing;

  /// The gap across the scroll axis.
  final double crossAxisSpacing;

  /// The tile aspect, used when [mainAxisExtent] is null.
  final double childAspectRatio;

  /// Fixed item height; takes priority over [childAspectRatio].
  final double? mainAxisExtent;

  /// The grid's padding.
  final EdgeInsetsGeometry padding;

  /// Passed to the sliver child delegate.
  final bool addAutomaticKeepAlives;

  /// Passed to the sliver child delegate.
  final bool addRepaintBoundaries;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = resolveAdaptiveColumns(
          width: constraints.crossAxisExtent,
          childCount: children.length,
          compact: compactColumns,
          medium: mediumColumns,
          expanded: expandedColumns,
          large: largeColumns,
        );

        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              childAspectRatio: childAspectRatio,
              mainAxisExtent: mainAxisExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => children[index],
              childCount: children.length,
              addAutomaticKeepAlives: addAutomaticKeepAlives,
              addRepaintBoundaries: addRepaintBoundaries,
            ),
          ),
        );
      },
    );
  }
}

/// The column count for [width]: the class's requested count, clamped to at
/// least one and at most [childCount].
int resolveAdaptiveColumns({
  required double width,
  required int childCount,
  required int compact,
  required int medium,
  required int expanded,
  required int large,
}) {
  final breakpoint = AdaptiveBreakpoints.fromWidth(width);
  final requested = breakpoint.resolve<int>(compact: compact, medium: medium, expanded: expanded, large: large);
  return math.max(1, math.min(requested, childCount));
}
