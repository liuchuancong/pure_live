import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// A paged card grid drawn with desen_ui primitives only: the cards in a
/// responsive grid (no more than the given card extent wide), skeletons while
/// the first page loads, an honest error or empty state in their place,
/// and the next page fetched as the viewer nears the end.
///
/// Every room/area feed in the app renders through this one widget, so
/// paging, spacing and the loading states stay the same everywhere.
final class CardGrid<T> extends StatefulWidget {
  /// A grid over [items].
  const CardGrid({
    required this.items,
    required this.itemBuilder,
    required this.cardExtent,
    this.aspectRatio = _roomCardAspectRatio,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.error,
    this.onRetry,
    this.emptyIcon = DsIcons.tv,
    this.emptyTitle,
    this.emptyDescription,
    this.padding = const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
    this.skeletonCount = 12,
    this.scrollController,
    super.key,
  });

  /// The room card's tile ratio: a 16:9 cover on top and a title row
  /// beneath it. Wide row cards (areas, history) pass their own.
  static const double _roomCardAspectRatio = 1.25;

  /// The items shown.
  final List<T> items;

  /// Builds one card.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// The widest a card gets; the columns follow the width.
  final double cardExtent;

  /// The tile's width over height; the card fills its tile.
  final double aspectRatio;

  /// Whether a page is in flight: the grid's footer shows a spinner, and
  /// the first page shows skeletons instead of the empty state.
  final bool isLoading;

  /// Whether another page may exist; [onLoadMore] fires near the end.
  final bool hasMore;

  /// Fetches the next page. Fired at most once while [isLoading].
  final Future<void> Function()? onLoadMore;

  /// The failure to show when [items] is empty.
  final String? error;

  /// Retries after [error].
  final VoidCallback? onRetry;

  /// The empty state's icon and words.
  final DsIconData emptyIcon;
  final String? emptyTitle;
  final String? emptyDescription;

  /// The grid's outer padding.
  final EdgeInsetsGeometry padding;

  /// How many skeletons the first load shows.
  final int skeletonCount;

  /// The grid's scroll controller; a caller that keeps one per tab (so
  /// switching back restores where the viewer was) passes it here. Null
  /// makes the grid its own.
  final ScrollController? scrollController;

  @override
  State<CardGrid<T>> createState() => _CardGridState<T>();
}

final class _CardGridState<T> extends State<CardGrid<T>> {
  /// How close to the end the next page may be asked for.
  static const double _loadMoreThreshold = 600;

  /// One ask in flight at a time: the notification stream fires per frame
  /// while the viewer scrolls, and one page's load is enough.
  bool _asking = false;

  void _onScroll(ScrollNotification notification) {
    final onLoadMore = widget.onLoadMore;
    if (onLoadMore == null || !widget.hasMore || widget.isLoading || _asking) return;
    if (notification.metrics.pixels < notification.metrics.maxScrollExtent - _loadMoreThreshold) return;
    _asking = true;
    unawaited(
      onLoadMore().whenComplete(() {
        if (mounted) setState(() => _asking = false);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.isLoading) {
      return _SkeletonGrid(
        cardExtent: widget.cardExtent,
        aspectRatio: widget.aspectRatio,
        count: widget.skeletonCount,
        padding: widget.padding,
      );
    }
    if (widget.items.isEmpty && widget.error != null) {
      return _MessagePane(
        icon: const DsIcon(DsIcons.cloudOff),
        title: Text(context.t.common.empty),
        description: Text(widget.error!),
        action: widget.onRetry == null ? null : DsButton(onPressed: widget.onRetry, child: Text(context.t.common.retry)),
      );
    }
    if (widget.items.isEmpty) {
      return _MessagePane(
        icon: DsIcon(widget.emptyIcon),
        title: Text(widget.emptyTitle ?? context.t.common.empty),
        description: widget.emptyDescription == null ? null : Text(widget.emptyDescription!),
      );
    }
    final loadingRow = widget.isLoading && widget.hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScroll(notification);
        return false;
      },
      child: GridView.builder(
        controller: widget.scrollController,
        padding: widget.padding,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: widget.cardExtent,
          mainAxisSpacing: DsSpace.s16,
          crossAxisSpacing: DsSpace.s16,
          childAspectRatio: widget.aspectRatio,
        ),
        // The footer row rides the grid: one more tile while a page loads.
        itemCount: widget.items.length + (loadingRow ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.items.length) {
            return const Center(child: DsSpinner());
          }
          return widget.itemBuilder(context, widget.items[index]);
        },
      ),
    );
  }
}

/// The first page's placeholder: the same grid shape, no content.
final class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({
    required this.cardExtent,
    required this.aspectRatio,
    required this.count,
    required this.padding,
  });

  final double cardExtent;
  final double aspectRatio;
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: cardExtent,
        mainAxisSpacing: DsSpace.s16,
        crossAxisSpacing: DsSpace.s16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: count,
      itemBuilder: (context, index) => const DsSkeleton.block(width: double.infinity, height: double.infinity),
    );
  }
}

/// The error or empty pane the grid shows in its content's place.
final class _MessagePane extends StatelessWidget {
  const _MessagePane({required this.icon, required this.title, this.description, this.action});

  final DsIcon icon;
  final Text title;
  final Text? description;
  final DsButton? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DsEmptyState(icon: icon, title: title, description: description, actions: action == null ? const <Widget>[] : [action!]),
    );
  }
}

/// The single-column sibling of [CardGrid]: full-width list cards that page
/// in exactly like the grid, so every feed pages the same way.
final class CardList<T> extends StatelessWidget {
  /// A list over [items].
  const CardList({
    required this.items,
    this.itemBuilder,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.gap = DsSpace.s12,
    this.padding = const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
    this.skeletonCount = 8,
    this.skeletonBuilder,
    this.scrollController,
    super.key,
  });

  /// The items shown.
  final List<T> items;

  /// Builds one row card; null on a skeleton-only list.
  final Widget Function(BuildContext context, T item)? itemBuilder;

  /// Whether a page is in flight: the footer shows a spinner, and the
  /// first page shows skeletons instead of the empty state.
  final bool isLoading;

  /// Whether another page may exist; [onLoadMore] fires near the end.
  final bool hasMore;

  /// Fetches the next page.
  final Future<void> Function()? onLoadMore;

  /// The rows' spacing.
  final double gap;

  /// The list's outer padding.
  final EdgeInsetsGeometry padding;

  /// How many skeletons the first load shows.
  final int skeletonCount;

  /// Builds a skeleton row; the plain block when null.
  final WidgetBuilder? skeletonBuilder;

  /// The list's scroll controller, when the caller keeps one.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && isLoading) {
      final skeleton = skeletonBuilder ?? (context) => const DsSkeleton(width: double.infinity, height: 64);
      return ListView.builder(
        padding: padding,
        itemCount: skeletonCount,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: skeleton(context),
        ),
      );
    }
    final loadingRow = isLoading && hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: _endReached,
      child: ListView.separated(
        controller: scrollController,
        padding: padding,
        itemCount: items.length + (loadingRow ? 1 : 0),
        separatorBuilder: (context, index) => SizedBox(height: gap),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Center(child: DsSpinner());
          }
          final builder = itemBuilder;
          return builder == null ? const SizedBox.shrink() : builder(context, items[index]);
        },
      ),
    );
  }

  /// Asks for the next page once the viewer nears the end.
  bool _endReached(ScrollNotification notification) {
    final onLoadMore = this.onLoadMore;
    if (onLoadMore == null || !hasMore || isLoading) return false;
    if (notification.metrics.pixels < notification.metrics.maxScrollExtent - 600) return false;
    unawaited(onLoadMore());
    return false;
  }
}
