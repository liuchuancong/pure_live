import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart' show BrowseSettings, browseSettingsProvider;
import 'package:pure_live/features/settings/room/room_card_settings.dart' show kRoomCardCoverRatio, roomCardTileHeight;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/focus/tv_focus_scale.dart';

/// The widest a feed card gets before the grid takes another column, and the
/// narrowest one may get: the measure every card grid holds itself. A pinned
/// column count is a ceiling — a window that cannot hold that many cards at
/// this width shows fewer instead of squeezing them.
const double kBrowseCardMaxWidth = 340;
const double kBrowseCardMinWidth = 220;

/// The most columns a feed takes, however wide its window.
const int kBrowseCardMaxColumns = 12;

/// The narrowest a list row keeps when its design is wider than a card — the
/// video and series rows with a fixed thumbnail. The room card's own row
/// takes the grid's card width instead.
const double kListCardMinWidth = 360;

/// The columns a viewer's [ceiling] allows in [content] pixels: their number
/// when the window holds that many cards at [minWidth], fewer when it does
/// not. 0 — no ceiling — leaves the count to the width alone.
int cappedColumnsForWidth(double content, {required double spacing, required int ceiling, required double minWidth}) {
  if (ceiling <= 0) return 0;
  if (content <= 0) return ceiling;
  final fits = math.max(1, ((content + spacing) / (minWidth + spacing)).floor());
  return math.min(ceiling, fits);
}

/// One column's width when [columns] share [content] pixels; the hair keeps
/// [SliverGridDelegateWithMaxCrossAxisExtent] from tipping into one more.
double columnExtentForWidth(double content, int columns, double spacing) =>
    (content - spacing * (columns - 1)) / columns + 0.01;

/// The row width the list layout gives itself in [content] pixels: the
/// widest that still leaves whole columns at least [kListCardMinWidth] wide.
double listCardExtentForWidth(double content, {double spacing = DsSpace.s12}) {
  if (content <= 0) return kListCardMinWidth;
  final columns = math.max(1, ((content + spacing) / (kListCardMinWidth + spacing)).floor());
  return (content - spacing * (columns - 1)) / columns + 0.01;
}

/// The card width a feed of [content] pixels gives itself.
///
/// The columns are the fewest that keep a card within [kBrowseCardMaxWidth],
/// less one when that would leave a card narrower than [kBrowseCardMinWidth] —
/// so a phone shows a single wide card, a laptop three or four and an
/// ultrawide six. The answer is the exact width one column then has (plus a
/// hair), which is what [SliverGridDelegateWithMaxCrossAxisExtent] needs to
/// stay on that column count instead of tipping into one more.
double browseCardExtentForWidth(double content, {double crossSpacing = DsSpace.s16}) {
  if (content <= 0) return kBrowseCardMaxWidth;
  double width(int columns) => (content - crossSpacing * (columns - 1)) / columns;
  var columns = 1;
  while (columns < kBrowseCardMaxColumns && width(columns) > kBrowseCardMaxWidth) {
    columns++;
  }
  if (columns > 1 && width(columns) < kBrowseCardMinWidth) columns--;
  return width(columns) + 0.01;
}

/// How a collection of items is laid out: the responsive card grid, or the
/// row card in as many columns as the window can hold.
enum CardLayout {
  /// Cards in columns.
  grid,

  /// Row cards side by side; the columns follow the window, so a wide
  /// desktop shows several rows' worth across instead of one band each.
  list,
}

/// A paged collection drawn with desen_ui primitives only: the items in a
/// responsive grid (no more than the given card extent wide) or a one-column
/// list, skeletons while
/// the first page loads, an honest error or empty state in their place,
/// and the next page fetched as the viewer nears the end.
///
/// With [CardGrid.pagesOnScrollToEnd] that end-of-list ask pages the feed
/// instead of growing it: only a real scroll to the bottom moves on, so the
/// wheel and a number row over the same catalogue stay in step.
///
/// Every room/area feed in the app renders through this one widget, so
/// paging, spacing and the loading states stay the same everywhere.
final class CardGrid<T> extends ConsumerStatefulWidget {
  /// A grid over [items].
  const CardGrid({
    required this.items,
    required this.itemBuilder,
    this.cardExtent,
    this.crossSpacing = DsSpace.s16,
    this.mainSpacing = DsSpace.s16,
    this.aspectRatio,
    this.listMainAxisExtent,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.pagesOnScrollToEnd = false,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.refreshError,
    this.emptyIcon = DsIcons.tv,
    this.emptyTitle,
    this.emptyDescription,
    this.padding = const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
    this.skeletonCount = 12,
    this.scrollController,
    this.layout = CardLayout.grid,
    this.listMatchesGridWidth = false,
    this.listItemBuilder,
    super.key,
  });

  /// The items shown.
  final List<T> items;

  /// Builds one card.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Builds one list row when [layout] is [CardLayout.list]; null falls back
  /// to [itemBuilder].
  final Widget Function(BuildContext context, T item)? listItemBuilder;

  /// Whether the items are a card grid or a one-column list.
  final CardLayout layout;

  /// Whether a list row takes a grid card's width and columns. The room
  /// feeds set it so switching the layout never resizes their cards; a row
  /// whose design is wider than a card (a video row's fixed thumbnail)
  /// leaves it false and keeps [kListCardMinWidth].
  final bool listMatchesGridWidth;

  /// The widest a card gets; the columns follow the width. Null — what every
  /// feed passes now that the card width is no longer a setting — lets the
  /// grid take the width its own columns imply for the space it is given
  /// (see [browseCardExtentForWidth]); a caller with its own measure (the
  /// follows page's density) passes one.
  final double? cardExtent;

  /// The gap between cards across a row (the viewer's column spacing).
  final double crossSpacing;

  /// The gap between rows of cards (the viewer's row spacing).
  final double mainSpacing;

  /// The tile's width over height; the card fills its tile. Null — what a
  /// room feed passes — takes the room card's own shape, a 16:9 cover over a
  /// fixed information block; wide row cards (areas, history) pass their own.
  final double? aspectRatio;

  /// The fixed height of a card in the list layout's multi-column rows, so
  /// a row design keeps its proportions however wide its column gets. Null
  /// falls back to [aspectRatio].
  final double? listMainAxisExtent;

  /// Whether a page is in flight: the grid's footer shows a skeleton card,
  /// and the first page shows skeletons instead of the empty state.
  final bool isLoading;

  /// Whether another page may exist; [onLoadMore] fires near the end.
  final bool hasMore;

  /// Fetches the next page. Fired at most once while [isLoading].
  final Future<void> Function()? onLoadMore;

  /// When true, [onLoadMore] means "show the next page" rather than "append
  /// more rooms": only the real end of a page the viewer can actually scroll
  /// asks for it, and a page that fits the viewport never runs on by itself.
  /// A paged desktop feed sets this so its wheel and its number row agree.
  final bool pagesOnScrollToEnd;

  /// The failure to show when [items] is empty.
  final String? error;

  /// Retries after [error].
  final VoidCallback? onRetry;

  /// Loads the first page again when the viewer pulls the grid down; null
  /// leaves the grid without the gesture.
  final Future<void> Function()? onRefresh;

  /// The failure of a refresh that kept [items] on screen: a bar over the
  /// cards naming the reason, with retry and dismiss. Ignored while [items]
  /// is empty — a first-load failure already takes the whole pane ([error]).
  final String? refreshError;

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
  ConsumerState<CardGrid<T>> createState() => _CardGridState<T>();
}

final class _CardGridState<T> extends ConsumerState<CardGrid<T>> {
  /// How close to the end the next page may be asked for.
  static const double _loadMoreThreshold = 600;

  /// How close to the end counts as "at the end" when the grid pages
  /// ([CardGrid.pagesOnScrollToEnd]) instead of appending.
  static const double _pageEndThreshold = 24;

  /// How much room a focused card keeps from the viewport's edge when the
  /// D-pad scrolls it into view.
  static const double _focusMargin = 12;

  /// One ask in flight at a time: the notification stream fires per frame
  /// while the viewer scrolls, and one page's load is enough.
  bool _asking = false;

  /// The grid's own controller, used while the caller passes none.
  final ScrollController _ownScroll = ScrollController();

  /// The focus node each built card answers, by index: the D-pad moves by
  /// index through them, including rows not built yet (they are scrolled to
  /// and then focused).
  final Map<int, FocusNode> _itemNodes = {};

  /// The last built width and column count: the index walk needs the same
  /// rows the grid delegate made.
  double _gridWidth = 0;
  int _columns = 1;

  /// The tile ratio the last build drew: the focus walk needs the same rows
  /// the delegate made.
  double _tileAspect = kRoomCardCoverRatio;

  /// The room card's fixed tile height for the last build's column width;
  /// null for a caller that brought its own ratio.
  double? _gridItemExtent;

  /// One more than the last programmatic focus move: a retry waiting for a
  /// row to build is dropped when another arrow has moved on.
  int _focusToken = 0;

  /// The refresh failure the viewer closed. Cleared when a new failure
  /// arrives (or the old one clears), so every failed refresh shows again.
  String? _dismissedRefreshError;

  ScrollController get _scroll => widget.scrollController ?? _ownScroll;

  /// The card width the collection uses in a box [width] wide: the caller's
  /// measure when it brought one, the columns the window implies otherwise.
  /// A viewer's column cap lowers the count when the window is too narrow
  /// to hold that many cards at [kBrowseCardMinWidth].
  double _extentFor(double width, BrowseSettings browse) {
    final padding = widget.padding.resolve(Directionality.of(context));
    final content = math.max(0, width - padding.horizontal).toDouble();
    final capped = cappedColumnsForWidth(
      content,
      spacing: widget.crossSpacing,
      ceiling: browse.gridColumns,
      minWidth: kBrowseCardMinWidth,
    );
    if (widget.cardExtent == null && capped > 0 && content > 0) {
      return columnExtentForWidth(content, capped, widget.crossSpacing);
    }
    return widget.cardExtent ?? browseCardExtentForWidth(content, crossSpacing: widget.crossSpacing);
  }

  /// The columns a width gets from [SliverGridDelegateWithMaxCrossAxisExtent].
  int _columnsFor(double width, BrowseSettings browse) {
    final padding = widget.padding.resolve(Directionality.of(context));
    final extent = math.max(0, width - padding.horizontal);
    return math.max(1, (extent / (_extentFor(width, browse) + widget.crossSpacing)).ceil());
  }

  /// The list layout's delegate. A row that takes the card's width
  /// ([CardGrid.listMatchesGridWidth]) uses exactly the grid's measure, so
  /// switching layouts never resizes the cards; a row with its own wider
  /// design keeps [kListCardMinWidth]. Either way the row keeps its fixed
  /// height, so its design does not stretch with the column.
  SliverGridDelegateWithMaxCrossAxisExtent _listDelegate(double width, BrowseSettings browse, double tileAspect) {
    final padding = widget.padding.resolve(Directionality.of(context));
    final content = math.max(0, width - padding.horizontal).toDouble();
    final capped = cappedColumnsForWidth(
      content,
      spacing: widget.crossSpacing,
      ceiling: browse.gridColumns,
      minWidth: kListCardMinWidth,
    );
    final extent = widget.listMatchesGridWidth
        ? _extentFor(width, browse)
        : capped > 0 && content > 0
        ? columnExtentForWidth(content, capped, widget.crossSpacing)
        : listCardExtentForWidth(content, spacing: widget.crossSpacing);
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: extent,
      mainAxisSpacing: widget.mainSpacing,
      crossAxisSpacing: widget.crossSpacing,
      mainAxisExtent: widget.listMainAxisExtent,
      childAspectRatio: widget.listMainAxisExtent == null ? tileAspect : 1,
    );
  }

  @override
  void dispose() {
    _itemNodes.clear();
    _ownScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CardGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshError != widget.refreshError) _dismissedRefreshError = null;
  }

  /// Asks for the next page, once: the scroll, a short viewport and the
  /// D-pad reaching the last row all go through here.
  void _askForMore() {
    final onLoadMore = widget.onLoadMore;
    if (_asking || onLoadMore == null || !widget.hasMore || widget.isLoading) return;
    _asking = true;
    unawaited(
      onLoadMore().whenComplete(() {
        if (mounted) setState(() => _asking = false);
      }),
    );
  }

  void _onScroll(ScrollNotification notification) {
    // The collection's own scroll only: a horizontal strip inside a card
    // bubbles through here too, and its metrics say nothing about this
    // feed's head or end.
    if (notification.depth != 0) return;
    final offset = notification.metrics.pixels;
    if (widget.pagesOnScrollToEnd) {
      // Paging: the ask needs a page that scrolls and an end that is really
      // reached. A page shorter than the viewport would otherwise chain
      // forward the moment it is drawn.
      if (notification.metrics.maxScrollExtent <= 0) return;
      if (offset < notification.metrics.maxScrollExtent - _pageEndThreshold) return;
      _askForMore();
      return;
    }
    if (offset < notification.metrics.maxScrollExtent - _loadMoreThreshold) return;
    _askForMore();
  }

  /// Registers the focus node of the card at [index] while it is built.
  void _registerItem(int index, FocusNode node) => _itemNodes[index] = node;

  void _unregisterItem(int index, FocusNode node) {
    if (identical(_itemNodes[index], node)) _itemNodes.remove(index);
  }

  void _onItemFocus(int index, bool focused) {
    if (!focused) return;
    // Paging moves only when the viewer reaches the end on purpose: a D-pad
    // stop in the last row would otherwise flip the page under them.
    if (widget.pagesOnScrollToEnd) return;
    // The last two rows pre-load the next page, so the D-pad never stops
    // one row short of the end of an infinite feed.
    final columns = math.max(1, _columns);
    if (index >= widget.items.length - columns * 2) _askForMore();
  }

  /// Moves focus by index inside the collection, so the D-pad reaches rows
  /// the lazy list has not built yet; edges fall through to Flutter's
  /// geometry (the sidebar on the left, the pager below).
  KeyEventResult _onItemKey(int index, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final count = widget.items.length;
    if (count == 0) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final columns = math.max(1, _columns);
    final row = index ~/ columns;
    final lastRow = (count - 1) ~/ columns;
    int? target;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) return KeyEventResult.ignored;
      target = index - columns;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (row >= lastRow) {
        _askForMore();
        return KeyEventResult.ignored;
      }
      target = math.min(index + columns, count - 1);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final forward = key == LogicalKeyboardKey.arrowRight;
      final step = forward != (Directionality.of(context) == TextDirection.rtl) ? 1 : -1;
      final column = index % columns;
      final atEdge = step > 0 ? (column == columns - 1 || index + 1 >= count) : column == 0;
      if (atEdge) return KeyEventResult.ignored;
      target = index + step;
    }
    if (target == null || target < 0 || target >= count) return KeyEventResult.ignored;
    _focusItem(target);
    return KeyEventResult.handled;
  }

  void _focusItem(int index) {
    _focusToken++;
    _revealItem(index);
    _requestItemFocus(index, token: _focusToken);
  }

  /// Requests the target card's own focus stop, retrying while a scroll
  /// brings the lazy row into the tree. [token] drops a retry that a newer
  /// arrow has superseded.
  void _requestItemFocus(int index, {required int token, int frames = 6}) {
    if (token != _focusToken) return;
    final node = _itemNodes[index];
    if (node != null && node.context != null) {
      final first = node.traversalDescendants.firstOrNull;
      if (first != null) {
        first.requestFocus();
        return;
      }
    }
    if (frames <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestItemFocus(index, frames: frames - 1, token: token);
    });
  }

  /// Jumps the collection just far enough to show the card at [index];
  /// FocusAutoScroll corrects any estimate once the card is built.
  void _revealItem(int index) {
    final controller = _scroll;
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasViewportDimension) return;
    final padding = widget.padding.resolve(Directionality.of(context));
    final double start;
    final double extent;
    if (_gridWidth <= 0) return;
    final columns = math.max(1, _columns);
    final width = math.max(0, _gridWidth - padding.horizontal);
    if (width <= 0) return;
    final itemWidth = (width - widget.crossSpacing * (columns - 1)) / columns;
    final itemHeight = widget.layout == CardLayout.list
        ? widget.listMainAxisExtent ?? itemWidth / _tileAspect
        : _gridItemExtent ?? itemWidth / _tileAspect;
    start = padding.top + (index ~/ columns) * (itemHeight + widget.mainSpacing);
    extent = itemHeight;
    var target = position.pixels;
    if (start < target + _focusMargin) {
      target = start - _focusMargin;
    } else if (start + extent > target + position.viewportDimension - _focusMargin) {
      target = start + extent + _focusMargin - position.viewportDimension;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() > 0.5) position.jumpTo(target);
  }

  /// Wraps one card with its D-pad stop and index. [zoom] grows the card
  /// while it holds focus on TV; full-width list rows keep only the ring.
  Widget _focusableItem(int index, Widget child, {bool zoom = false}) => _GridFocusItem(
    index: index,
    register: _registerItem,
    unregister: _unregisterItem,
    onKey: _onItemKey,
    onFocusChanged: _onItemFocus,
    child: zoom ? TvFocusScale(child: child) : child,
  );

  /// Asks for the next page when the shown one does not fill the viewport:
  /// a short list cannot be scrolled to its end, so its footer would never
  /// fire (the reference's `_fillViewport`).
  void _fillViewportIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _asking) return;
      if (widget.error != null || widget.items.isEmpty) return;
      final controller = _scroll;
      if (!controller.hasClients || controller.position.maxScrollExtent > 0) return;
      _askForMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(browseSettingsProvider);
    final tileAspect = widget.aspectRatio ?? kRoomCardCoverRatio;
    _tileAspect = tileAspect;
    if (widget.items.isEmpty && widget.isLoading) {
      final listRow = widget.layout == CardLayout.list;
      return _SkeletonGrid(
        cardExtent: widget.cardExtent,
        crossSpacing: widget.crossSpacing,
        mainSpacing: widget.mainSpacing,
        aspectRatio: tileAspect,
        roomCard: widget.aspectRatio == null,
        mainAxisExtent: listRow ? widget.listMainAxisExtent : null,
        listMatchesGridWidth: widget.listMatchesGridWidth,
        columns: browse.gridColumns,
        count: widget.skeletonCount,
        padding: widget.padding,
      );
    }
    if (widget.items.isEmpty && widget.error != null) {
      return _MessagePane(
        icon: const DsIcon(DsIcons.cloudOff),
        title: Text(context.t.common.empty),
        description: Text(widget.error!),
        action: widget.onRetry == null
            ? null
            : DsButton(onPressed: widget.onRetry, child: Text(context.t.common.retry)),
      );
    }
    if (widget.items.isEmpty) {
      return _MessagePane(
        icon: DsIcon(widget.emptyIcon),
        title: Text(widget.emptyTitle ?? context.t.common.empty),
        description: widget.emptyDescription == null ? null : Text(widget.emptyDescription!),
      );
    }
    if (widget.hasMore && widget.onLoadMore != null && !widget.pagesOnScrollToEnd) _fillViewportIfShort();
    final loadingRow = widget.isLoading && widget.hasMore;
    final refresh = widget.onRefresh;
    final Widget collection;
    if (widget.layout == CardLayout.list) {
      final listBuilder = widget.listItemBuilder ?? widget.itemBuilder;
      collection = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScroll(notification);
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The rows keep a grid card's width and columns, so switching
            // the layout never resizes the cards; a wide window shows the
            // same number of rows side by side as it would cards.
            final padding = widget.padding.resolve(Directionality.of(context));
            final content = math.max(0, constraints.maxWidth - padding.horizontal).toDouble();
            final delegate = _listDelegate(constraints.maxWidth, browse, tileAspect);
            _gridWidth = constraints.maxWidth;
            _columns = math.max(1, (content / (delegate.maxCrossAxisExtent + widget.crossSpacing)).ceil());
            return GridView.builder(
              controller: _scroll,
              padding: widget.padding,
              physics: refresh == null ? null : const AlwaysScrollableScrollPhysics(),
              gridDelegate: delegate,
              itemCount: widget.items.length + (loadingRow ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= widget.items.length) {
                  return const _LoadingTile();
                }
                return _focusableItem(index, listBuilder(context, widget.items[index]));
              },
            );
          },
        ),
      );
    } else {
      collection = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScroll(notification);
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The same width and columns the delegate below computes, for
            // the D-pad's row math.
            _gridWidth = constraints.maxWidth;
            _columns = _columnsFor(constraints.maxWidth, browse);
            // A room card keeps a fixed information area under its cover, so
            // its tile's height comes from the column width: a ratio would
            // grow that block along with wide tiles. A caller's own ratio
            // still speaks for its design.
            final padding = widget.padding.resolve(Directionality.of(context));
            final content = math.max(0, constraints.maxWidth - padding.horizontal).toDouble();
            final tileWidth = (content - widget.crossSpacing * (_columns - 1)) / _columns;
            final roomExtent = widget.aspectRatio == null && content > 0 ? roomCardTileHeight(tileWidth) : null;
            _gridItemExtent = roomExtent;
            return GridView.builder(
              controller: _scroll,
              padding: widget.padding,
              // With the gesture on, a short grid still scrolls far enough
              // to pull (the reference's always-scrollable feeds).
              physics: refresh == null ? null : const AlwaysScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _extentFor(constraints.maxWidth, browse),
                mainAxisSpacing: widget.mainSpacing,
                crossAxisSpacing: widget.crossSpacing,
                mainAxisExtent: roomExtent,
                childAspectRatio: roomExtent == null ? tileAspect : 1,
              ),
              // The footer row rides the grid: one more tile while a page
              // loads.
              itemCount: widget.items.length + (loadingRow ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= widget.items.length) {
                  return const _LoadingTile();
                }
                return _focusableItem(index, widget.itemBuilder(context, widget.items[index]), zoom: true);
              },
            );
          },
        ),
      );
    }
    final content = refresh == null
        ? collection
        : CustomRefreshIndicator(onRefresh: refresh, builder: _buildRefreshIndicator, child: collection);
    final error = widget.refreshError;
    // One Stack for good: the error bar is a keyed layer over the collection,
    // never a wrapper swapped in and out around it. A wrapper would change
    // the widget at that slot, tear the grid's element down and let its
    // scroll controller re-attach a fresh position at the head — the feed
    // snapping back to the top the moment the viewer scrolled.
    return Stack(
      children: [
        Positioned.fill(key: const ValueKey('cardGridContent'), child: content),
        // The bar rides over the kept cards: a failed refresh never empties
        // the grid, it explains itself on top of it.
        if (error != null && error != _dismissedRefreshError)
          Positioned(
            key: const ValueKey('cardGridRefreshError'),
            top: DsSpace.s4,
            left: DsSpace.s20,
            right: DsSpace.s20,
            child: _RefreshErrorBanner(
              reason: error,
              onRetry: refresh == null ? null : () => unawaited(refresh()),
              onDismiss: () => setState(() => _dismissedRefreshError = error),
            ),
          ),
      ],
    );
  }

  /// The pull-to-refresh indicator: a spinner easing down from under the
  /// grid's top edge as the drag grows, on the kit's surface with the
  /// accent ink.
  Widget _buildRefreshIndicator(BuildContext context, Widget child, IndicatorController controller) {
    final colors = DsTheme.colorsOf(context);
    final value = controller.value.clamp(0.0, 1.0);
    return Stack(
      children: [
        child,
        if (!controller.isIdle)
          Positioned(
            top: value * 48 - 44,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: DsBoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      shadows: [DsShadow.innerRing(colors.border)],
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(size: 18, color: colors.accent),
                      child: const DsSpinner(style: DsSpinnerStyle(size: 18)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One card with its place in the feed's D-pad walk.
///
/// The wrapper itself is not a stop: the card's own control keeps the focus
/// ring and activation, and the wrapper only hears the arrow keys bubbling
/// from it. Registering its node lets the collection move focus by index,
/// including to rows the lazy list has not built yet.
final class _GridFocusItem extends StatefulWidget {
  const _GridFocusItem({
    required this.index,
    required this.register,
    required this.unregister,
    required this.onKey,
    required this.onFocusChanged,
    required this.child,
  });

  final int index;
  final void Function(int index, FocusNode node) register;
  final void Function(int index, FocusNode node) unregister;
  final KeyEventResult Function(int index, KeyEvent event) onKey;
  // The focus flag is part of a callback signature, where a named parameter
  // would make every call site noisier without naming anything.
  // ignore: avoid_positional_boolean_parameters
  final void Function(int index, bool focused) onFocusChanged;
  final Widget child;

  @override
  State<_GridFocusItem> createState() => _GridFocusItemState();
}

final class _GridFocusItemState extends State<_GridFocusItem> {
  late final FocusNode _node = FocusNode(
    debugLabel: 'feed card ${widget.index}',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
    widget.register(widget.index, _node);
  }

  @override
  void didUpdateWidget(_GridFocusItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      oldWidget.unregister(oldWidget.index, _node);
      widget.register(widget.index, _node);
    }
  }

  @override
  void dispose() {
    widget.unregister(widget.index, _node);
    _node
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onFocus() => widget.onFocusChanged(widget.index, _node.hasFocus);

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: (_, event) {
      // The card itself walks by index; a control nested inside it (a
      // heart, a slider) keeps its own arrow behavior.
      final primary = FocusManager.instance.primaryFocus;
      final first = _node.traversalDescendants.firstOrNull;
      if (primary != first && primary != _node) return KeyEventResult.ignored;
      return widget.onKey(widget.index, event);
    },
    child: widget.child,
  );
}

/// The bar over a feed whose refresh failed while the old cards stay: the
/// reason, a retry, and the ✕ that closes it until the next failure.
final class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.reason, required this.onRetry, required this.onDismiss});

  /// What the failed refresh said.
  final String reason;

  /// Loads the first page again; null when the grid has no [CardGrid.onRefresh].
  final VoidCallback? onRetry;

  /// Closes the bar.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsAlert(
      status: DsStatus.danger,
      // A failure appearing after the cards is news for a screen reader.
      announce: true,
      title: Text(t.common.refreshFailed),
      description: Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: onRetry,
            child: Text(t.common.retry),
          ),
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            onPressed: onDismiss,
            semanticLabel: t.common.close,
            icon: const DsIcon(DsIcons.x),
          ),
        ],
      ),
    );
  }
}

/// The next page's placeholder while it loads: one card-shaped shimmer in
/// the grid's own measure, so the feed never shows a lone spinner in an
/// empty cell.
final class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) => const DsShimmer(
    child: DsSkeleton.block(width: double.infinity, height: double.infinity),
  );
}

/// The first page's placeholder: the same grid shape — or the same row
/// shape, when the list layout fixed a row height — with no content.
final class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({
    required this.crossSpacing,
    required this.mainSpacing,
    required this.aspectRatio,
    required this.count,
    required this.padding,
    required this.columns,
    this.cardExtent,
    this.roomCard = false,
    this.mainAxisExtent,
    this.listMatchesGridWidth = false,
  });

  final double? cardExtent;
  final double crossSpacing;
  final double mainSpacing;
  final double aspectRatio;

  /// Whether these tiles are room cards: their height comes from the column
  /// width plus the fixed information block, as the real grid's does. False
  /// for a caller with its own ratio.
  final bool roomCard;

  /// The fixed height of a list row; null draws the card's own ratio.
  final double? mainAxisExtent;

  /// Whether the rows keep the grid's card width; when false a row is held
  /// to [kListCardMinWidth], as the live list delegate does.
  final bool listMatchesGridWidth;
  final int columns;
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same measure the live grid takes: the placeholder must not
        // reflow the page when the first rooms arrive.
        final resolved = padding.resolve(Directionality.of(context));
        final content = math.max(0, constraints.maxWidth - resolved.horizontal).toDouble();
        final wideRows = mainAxisExtent != null && !listMatchesGridWidth;
        final capped = cappedColumnsForWidth(
          content,
          spacing: crossSpacing,
          ceiling: columns,
          minWidth: wideRows ? kListCardMinWidth : kBrowseCardMinWidth,
        );
        final extent =
            cardExtent ??
            (capped > 0 && content > 0
                ? columnExtentForWidth(content, capped, crossSpacing)
                : wideRows
                ? listCardExtentForWidth(content, spacing: crossSpacing)
                : browseCardExtentForWidth(content, crossSpacing: crossSpacing));
        final columnCount = math.max(1, (content / (extent + crossSpacing)).ceil());
        final tileWidth = (content - crossSpacing * (columnCount - 1)) / columnCount;
        final roomExtent = mainAxisExtent == null && roomCard && content > 0 ? roomCardTileHeight(tileWidth) : null;
        final fixedExtent = mainAxisExtent ?? roomExtent;
        return GridView.builder(
          padding: padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: extent,
            mainAxisSpacing: mainSpacing,
            crossAxisSpacing: crossSpacing,
            mainAxisExtent: fixedExtent,
            childAspectRatio: fixedExtent == null ? aspectRatio : 1,
          ),
          itemCount: count,
          // The shimmer's sweep over the plain block: one shared animation
          // across the whole placeholder grid, the loading idiom the kit
          // draws by.
          itemBuilder: (context, index) => const DsShimmer(
            child: DsSkeleton.block(width: double.infinity, height: double.infinity),
          ),
        );
      },
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
      child: DsEmptyState(
        icon: icon,
        title: title,
        description: description,
        actions: action == null ? const <Widget>[] : [action!],
      ),
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

  /// Whether a page is in flight: the footer shows a skeleton row, and the
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
            // The next row's placeholder: the same skeleton the first load
            // gets, so a pending page never reads as an empty row.
            final skeleton = skeletonBuilder ?? (context) => const DsSkeleton(width: double.infinity, height: 64);
            return DsShimmer(child: skeleton(context));
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
