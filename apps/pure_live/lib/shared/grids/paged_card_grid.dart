import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/grids/card_grid.dart';

/// The feed's scroll logic in one place: a wide window pages by number — the
/// wheel's end asks the pager for its next page and a fresh page starts at
/// its head — while a narrow one appends the source's next block as the
/// viewer scrolls and pulls to refresh. The paged feeds hand the accumulated
/// [items] in; this widget slices them locally ([pageSize] per display page)
/// and asks [onLoadMore] for the source's next block only when the slice the
/// viewer is moving to is not in hand yet.
///
/// The pager's count is the local slices in hand plus one while [hasMore]
/// says the source may continue, so a press never skips ahead of what the
/// source has answered. A search or tab switch that hands a shorter list
/// drops the pager back to its first page on its own.
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

  /// How many items one display page holds; the paged layouts slice
  /// [items] by it.
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
  /// The page the viewer asked for. A list that shrank under it (a new
  /// query, a switched tab) reads as its first page until it grows back.
  int _asked = 1;

  /// The page actually shown: [_asked] pulled back into the list's range.
  int get _page {
    if (widget.items.length <= (_asked - 1) * widget.pageSize) return 1;
    return _asked;
  }

  /// How many display pages the accumulated list fills whole.
  int get _inHandPages => widget.items.length ~/ widget.pageSize;

  /// Moves the local pager to [next]: a slice already in hand moves without
  /// a request, a slice past the hand asks the source for one more block
  /// and only moves when that block arrived.
  Future<void> _goToPage(int next) async {
    if (next <= _page || widget.isLoading) return;
    if (next > _inHandPages + 1) return;
    if (next > _inHandPages) {
      final before = widget.items.length;
      await widget.onLoadMore();
      if (!mounted || widget.items.length <= before) return;
    }
    if (!mounted) return;
    setState(() => _asked = next);
    final controller = widget.scrollController;
    if (controller?.hasClients ?? false) controller!.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final grid = wide ? _pagedGrid() : _endlessGrid();
    if (!wide) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: grid),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
          child: Center(
            // The pager keeps its normal ink while a page loads — the ask is
            // dropped inside [_goToPage], the control is not greyed out.
            child: DsPagination(
              page: _page,
              pageCount: _inHandPages + (widget.hasMore ? 1 : 0),
              onChanged: (next) => unawaited(_goToPage(next)),
            ),
          ),
        ),
      ],
    );
  }

  /// The narrow layout: the source's next block appends as the viewer
  /// reaches the end, and the pull refreshes from the first.
  Widget _endlessGrid() {
    return CardGrid<T>(
      scrollController: widget.scrollController,
      items: widget.items,
      layout: widget.layout,
      listItemBuilder: widget.listItemBuilder,
      listMainAxisExtent: widget.listMainAxisExtent,
      listMatchesGridWidth: widget.listMatchesGridWidth,
      aspectRatio: widget.aspectRatio,
      infoExtent: widget.infoExtent,
      cardExtent: widget.cardExtent,
      crossSpacing: widget.crossSpacing,
      mainSpacing: widget.mainSpacing,
      isLoading: widget.isLoading,
      hasMore: widget.hasMore,
      onLoadMore: widget.onLoadMore,
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

  /// The wide layout: the local slice for [_page], the wheel's end moving
  /// the pager forward one page at a time.
  Widget _pagedGrid() {
    final end = _page * widget.pageSize;
    final shown = widget.items.length <= end ? widget.items : widget.items.sublist(0, end);
    final moreInHand = widget.items.length > end;
    return CardGrid<T>(
      scrollController: widget.scrollController,
      items: shown,
      layout: widget.layout,
      listItemBuilder: widget.listItemBuilder,
      listMainAxisExtent: widget.listMainAxisExtent,
      listMatchesGridWidth: widget.listMatchesGridWidth,
      aspectRatio: widget.aspectRatio,
      infoExtent: widget.infoExtent,
      cardExtent: widget.cardExtent,
      crossSpacing: widget.crossSpacing,
      mainSpacing: widget.mainSpacing,
      isLoading: widget.isLoading,
      hasMore: moreInHand || widget.hasMore,
      onLoadMore: () => _goToPage(_page + 1),
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
}
