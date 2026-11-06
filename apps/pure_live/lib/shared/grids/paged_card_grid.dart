import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/grids/card_grid.dart';

/// The feed's scroll logic in one place, the popular page's rule: one display
/// page of [pageSize] items under the kit's pagination at every width, the
/// wheel's end moving the pager forward and a fresh page starting at its head.
/// The feeds hand the accumulated [items] in; this widget slices them locally
/// and asks [onLoadMore] for the source's next block only when the block the
/// viewer is moving to is not in hand yet.
///
/// A list that is whole in hand (the follows, the areas, the records) pages
/// the same way with [hasMore] false: the pager counts the local pages.
///
/// The pager's count is the local pages in hand plus one while [hasMore]
/// says the source may continue, so a press never skips ahead of what the
/// source has answered. A list that shrank under the shown page (a new
/// query, a switched tab, a removed item) keeps the viewer on the last page
/// that is left.
final class PagedCardGrid<T> extends StatefulWidget {
  /// A dual-mode feed over [items].
  const PagedCardGrid({
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
    this.showRefreshProgress = true,
    this.pageSize = 30,
    this.scrollController,
    this.layout = CardLayout.grid,
    this.listItemBuilder,
    this.listMainAxisExtent,
    this.listFullWidth = false,
    this.listMatchesGridWidth = false,
    this.oneColumnWhenCompact = false,
    this.compactMainAxisExtent,
    this.aspectRatio,
    this.infoExtent,
    this.cardExtent,
    this.crossSpacing = DsSpace.s16,
    this.mainSpacing = DsSpace.s16,
    this.padding,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.refreshError,
    this.emptyIcon = DsIcons.tv,
    this.emptyTitle,
    this.emptyDescription,
    super.key,
  });

  /// Every block the source has answered so far, in order.
  final List<T> items;

  /// Builds one card.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Whether the source may still have more.
  final bool hasMore;

  /// Whether a source page is in flight.
  final bool isLoading;

  /// Whether a refresh with kept content draws the feed's top progress bar;
  /// see [CardGrid.showRefreshProgress].
  final bool showRefreshProgress;

  /// Fetches the source's next block.
  final Future<void> Function() onLoadMore;

  /// How many items one display page (and one narrow block) holds.
  final int pageSize;

  /// The grid's scroll controller, when the caller keeps one.
  final ScrollController? scrollController;

  /// Cards in columns or row cards; see [CardGrid.layout].
  final CardLayout layout;

  /// Builds one row when [layout] is [CardLayout.list].
  final Widget Function(BuildContext context, T item)? listItemBuilder;

  /// The fixed height of a list row; see [CardGrid.listMainAxisExtent].
  final double? listMainAxisExtent;

  /// The list's one full-width column; see [CardGrid.listFullWidth].
  final bool listFullWidth;

  /// Whether a list row takes a grid card's width; see
  /// [CardGrid.listMatchesGridWidth].
  final bool listMatchesGridWidth;

  /// Whether a grid card keeps one full-width column on a compact page; see
  /// [CardGrid.oneColumnWhenCompact].
  final bool oneColumnWhenCompact;

  /// The fixed compact row height; see [CardGrid.compactMainAxisExtent].
  final double? compactMainAxisExtent;

  /// The tile's width over height; see [CardGrid.aspectRatio].
  final double? aspectRatio;

  /// The information block's height on room-shaped tiles; see
  /// [CardGrid.infoExtent].
  final double? infoExtent;

  /// The widest a card gets; see [CardGrid.cardExtent].
  final double? cardExtent;

  /// The gap between cards across a row.
  final double crossSpacing;

  /// The gap between rows of cards.
  final double mainSpacing;

  /// The grid's outer padding; the grid's own default when null.
  final EdgeInsetsGeometry? padding;

  /// The failure to show when [items] is empty.
  final String? error;

  /// Retries after [error].
  final VoidCallback? onRetry;

  /// Loads the first block again when the viewer pulls the grid down.
  final Future<void> Function()? onRefresh;

  /// The failure of a refresh that kept the cards on screen.
  final String? refreshError;

  /// The empty state's icon and words.
  final DsIconData emptyIcon;
  final String? emptyTitle;
  final String? emptyDescription;

  @override
  State<PagedCardGrid<T>> createState() => _PagedCardGridState<T>();
}

final class _PagedCardGridState<T> extends State<PagedCardGrid<T>> {
  /// The page the wide pager was asked for.
  int _asked = 1;

  /// The last display page the accumulated list fills, whole or in part.
  int get _lastInHand => widget.items.isEmpty ? 1 : (widget.items.length + widget.pageSize - 1) ~/ widget.pageSize;

  /// The page actually shown: [_asked] pulled back into the list's range.
  int get _page => _asked.clamp(1, _lastInHand);

  void _jumpToTop() {
    final controller = widget.scrollController;
    if (controller?.hasClients ?? false) controller!.jumpTo(0);
  }

  /// Moves the wide pager to [next]: a page already in hand moves without a
  /// request, the page past the hand asks the source for one more block
  /// and only moves when that block arrived.
  Future<void> _goToPage(int next) async {
    if (next < 1 || next == _page || widget.isLoading) return;
    if (next > _lastInHand) {
      if (!widget.hasMore || next > _lastInHand + 1) return;
      final before = widget.items.length;
      await widget.onLoadMore();
      if (!mounted || widget.items.length <= before) return;
    }
    if (!mounted) return;
    setState(() => _asked = next);
    _jumpToTop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _pagedGrid()),
        Padding(
          padding: feedGutter(context, custom: widget.padding, top: DsSpace.s12, bottom: DsSpace.s12),
          child: Center(
            // The pager keeps its normal ink while a page loads — the ask is
            // dropped inside [_goToPage], the control is not greyed out.
            child: DsPagination(
              page: _page,
              pageCount: widget.hasMore ? math.max(_page + 1, _lastInHand) : _lastInHand,
              onChanged: (next) => unawaited(_goToPage(next)),
            ),
          ),
        ),
      ],
    );
  }

  CardGrid<T> _grid({
    required List<T> items,
    required bool hasMore,
    required Future<void> Function() onLoadMore,
    required bool pages,
  }) {
    return CardGrid<T>(
      scrollController: widget.scrollController,
      items: items,
      layout: widget.layout,
      listItemBuilder: widget.listItemBuilder,
      listMainAxisExtent: widget.listMainAxisExtent,
      listFullWidth: widget.listFullWidth,
      listMatchesGridWidth: widget.listMatchesGridWidth,
      oneColumnWhenCompact: widget.oneColumnWhenCompact,
      compactMainAxisExtent: widget.compactMainAxisExtent,
      aspectRatio: widget.aspectRatio,
      infoExtent: widget.infoExtent,
      cardExtent: widget.cardExtent,
      crossSpacing: widget.crossSpacing,
      mainSpacing: widget.mainSpacing,
      padding: widget.padding,
      isLoading: widget.isLoading,
      showRefreshProgress: widget.showRefreshProgress,
      hasMore: hasMore,
      pagesOnScrollToEnd: pages,
      onLoadMore: onLoadMore,
      error: widget.error,
      onRetry: widget.onRetry,
      onRefresh: widget.onRefresh,
      refreshError: widget.refreshError,
      emptyIcon: widget.emptyIcon,
      emptyTitle: widget.emptyTitle,
      emptyDescription: widget.emptyDescription,
      itemBuilder: widget.itemBuilder,
    );
  }

  /// The one page the pager names, the wheel's end moving the pager forward
  /// one page at a time.
  Widget _pagedGrid() {
    final start = (_page - 1) * widget.pageSize;
    final end = math.min(widget.items.length, start + widget.pageSize);
    final shown = start >= widget.items.length ? const <Never>[] : widget.items.sublist(start, end);
    return _grid(
      items: shown,
      hasMore: _page < _lastInHand || widget.hasMore,
      onLoadMore: () => _goToPage(_page + 1),
      pages: true,
    );
  }
}
