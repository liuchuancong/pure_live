import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/grids/card_grid.dart';

/// The paged grid's single-column sibling over [CardList]: the same rule
/// for rows whose height is their own (a task card grows a progress line, an
/// error line) and so cannot ride the grid's fixed-extent list form. The rows
/// page by number under the kit's pagination at every width, so a phone and a
/// desktop share the same way through a long list.
final class PagedCardList<T> extends StatefulWidget {
  /// A dual-mode list over [items].
  const PagedCardList({
    required this.items,
    required this.itemBuilder,
    this.hasMore = false,
    this.isLoading = false,
    this.onLoadMore,
    this.onRefresh,
    this.pageSize = 30,
    this.gap = DsSpace.s12,
    this.padding,
    this.skeletonBuilder,
    this.scrollController,
    super.key,
  });

  /// Every row the source has answered so far, in order.
  final List<T> items;

  /// Builds one row card.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Whether the source may still have more.
  final bool hasMore;

  /// Whether a source page is in flight.
  final bool isLoading;

  /// Fetches the source's next block; null on a list whole in hand.
  final Future<void> Function()? onLoadMore;

  /// Loads the list again when the viewer pulls it down.
  final Future<void> Function()? onRefresh;

  /// How many rows one display page (and one narrow block) holds.
  final int pageSize;

  /// The rows' spacing.
  final double gap;

  /// The list's outer padding; null keeps the window's gutter — see [feedGutter].
  final EdgeInsetsGeometry? padding;

  /// Builds a skeleton row while a page loads.
  final WidgetBuilder? skeletonBuilder;

  /// The list's scroll controller, when the caller keeps one.
  final ScrollController? scrollController;

  @override
  State<PagedCardList<T>> createState() => _PagedCardListState<T>();
}

final class _PagedCardListState<T> extends State<PagedCardList<T>> {
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

  /// Moves the wide pager to [next]; the page past the hand asks the source
  /// for one more block first and only moves when that block arrived.
  Future<void> _goToPage(int next) async {
    if (next < 1 || next == _page || widget.isLoading) return;
    if (next > _lastInHand) {
      final load = widget.onLoadMore;
      if (load == null || !widget.hasMore || next > _lastInHand + 1) return;
      final before = widget.items.length;
      await load();
      if (!mounted || widget.items.length <= before) return;
    }
    if (!mounted) return;
    setState(() => _asked = next);
    _jumpToTop();
  }

  @override
  Widget build(BuildContext context) {
    final start = (_page - 1) * widget.pageSize;
    final end = math.min(widget.items.length, start + widget.pageSize);
    final shown = start >= widget.items.length ? const <Never>[] : widget.items.sublist(start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The wide list does not page on its wheel's end: its rows are a
        // page, the pager under them is the way on.
        Expanded(child: _list(items: shown, hasMore: false, onLoadMore: null)),
        Padding(
          padding: feedGutter(context, custom: widget.padding, top: DsSpace.s12, bottom: DsSpace.s12),
          child: Center(
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

  CardList<T> _list({required List<T> items, required bool hasMore, required Future<void> Function()? onLoadMore}) {
    return CardList<T>(
      items: items,
      itemBuilder: widget.itemBuilder,
      isLoading: widget.isLoading,
      hasMore: hasMore,
      onLoadMore: onLoadMore,
      onRefresh: widget.onRefresh,
      gap: widget.gap,
      padding: widget.padding,
      skeletonBuilder: widget.skeletonBuilder,
      scrollController: widget.scrollController,
    );
  }
}
