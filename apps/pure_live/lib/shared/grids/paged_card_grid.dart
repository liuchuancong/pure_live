import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/grids/card_grid.dart';

/// The feed's scroll logic in one place, the popular page's rule: a wide
/// window pages by number — one display page of [pageSize] items under the
/// kit's pagination, the wheel's end moving the pager forward and a fresh
/// page starting at its head — while a narrow one appends one block of
/// [pageSize] as the viewer reaches the end and pulls to refresh. The feeds
/// hand the accumulated [items] in; this widget slices them locally and asks
/// [onLoadMore] for the source's next block only when the block the viewer
/// is moving to is not in hand yet.
///
/// A list that is whole in hand (the follows, the areas, the records) pages
/// and appends the same way with [hasMore] false: the narrow end reveals the
/// next local block, the wide pager counts the local pages.
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
    this.pageSize = 30,
    this.scrollController,
    this.layout = CardLayout.grid,
    this.listItemBuilder,
    this.listMainAxisExtent,
    this.listMatchesGridWidth = false,
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

  /// Whether a list row takes a grid card's width; see
  /// [CardGrid.listMatchesGridWidth].
  final bool listMatchesGridWidth;

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

  /// How many blocks the narrow list has revealed.
  int _revealed = 1;

  /// The last display page the accumulated list fills, whole or in part.
  int get _lastInHand => widget.items.isEmpty ? 1 : (widget.items.length + widget.pageSize - 1) ~/ widget.pageSize;

  /// The page actually shown: [_asked] pulled back into the list's range.
  int get _page => _asked.clamp(1, _lastInHand);

  @override
  void didUpdateWidget(PagedCardGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A list that shrank is a new one (a query, a tab, a refresh): the
    // narrow end starts from its first block again instead of showing
    // every block it had revealed before.
    if (widget.items.length < oldWidget.items.length) _revealed = 1;
  }

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

  /// Appends the next narrow block: the one in hand, else the source's.
  Future<void> _revealMore() async {
    if (widget.items.length > _revealed * widget.pageSize) {
      setState(() => _revealed++);
      return;
    }
    if (!widget.hasMore) return;
    await widget.onLoadMore();
    if (mounted) setState(() => _revealed++);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    if (!wide) return _endlessGrid();
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
      listMatchesGridWidth: widget.listMatchesGridWidth,
      aspectRatio: widget.aspectRatio,
      infoExtent: widget.infoExtent,
      cardExtent: widget.cardExtent,
      crossSpacing: widget.crossSpacing,
      mainSpacing: widget.mainSpacing,
      padding: widget.padding,
      isLoading: widget.isLoading,
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

  /// The narrow layout: the blocks revealed so far, the next appending as
  /// the viewer reaches the end, and the pull refreshing from the first.
  Widget _endlessGrid() {
    final end = math.min(widget.items.length, _revealed * widget.pageSize);
    final shown = end == widget.items.length ? widget.items : widget.items.sublist(0, end);
    final moreInHand = widget.items.length > end;
    return _grid(items: shown, hasMore: moreInHand || widget.hasMore, onLoadMore: _revealMore, pages: false);
  }

  /// The wide layout: the one page the pager names, the wheel's end moving
  /// the pager forward one page at a time.
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
