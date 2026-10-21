import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart' show LivePageRequest, LiveRoom;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/room/paging.dart';
import 'package:pure_live/features/room/room_playlist.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_live/shared/widgets/room_card.dart';
import 'package:pure_live/shared/widgets/room_grid.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// How the loaded rooms are ordered.
enum RoomSort {
  /// The platform's own order.
  platform,

  /// Most viewers first.
  viewers,
}

/// The rooms of one area, without a scaffold of its own (3.x
/// `AreaRoomsPage`'s body): infinite scroll on phones, numbered pages on
/// desktops — the two interaction models `live_pagination` was built for —
/// plus a client-side [RoomSort].
///
/// The frame around it decides the chrome: the area-rooms route wraps it in a
/// scaffold with a sort control in the app bar, and the areas page embeds it
/// as the detail pane of the desktop master-detail, sort control beside the
/// area name. A change of [areaId] re-keys the view, which re-roots the
/// controllers.
final class AreaRoomsView extends ConsumerStatefulWidget {
  /// Shows [areaId] of [siteId]; [areaName] labels the header.
  const new({
    required this.siteId,
    required this.areaId,
    required this.areaName,
    this.sort = RoomSort.platform,
    super.key,
  });

  /// The platform the area belongs to.
  final String siteId;

  /// The area's id.
  final String areaId;

  /// The area's display name.
  final String areaName;

  /// How the loaded rooms are ordered.
  final RoomSort sort;

  @override
  ConsumerState<AreaRoomsView> createState() => _AreaRoomsViewState();
}

final class _AreaRoomsViewState extends ConsumerState<AreaRoomsView> {
  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    final width = MediaQuery.sizeOf(context).width;
    // The shared rule: wider than 680 and not a phone pages; the paging
    // controls answer to the pager settings, as the reference's does.
    final paged = desktopPagesIn(ref, width);
    final heroTag = 'area-rooms-${widget.siteId}-${widget.areaId}';
    if (paged) {
      final sizes = pageSizesOf(preferences, width);
      return _PagedFeed(
        loader: _load,
        sort: widget.sort,
        pageSize: sizes.size,
        pageSizes: preferences.pageShowSizeSelector ? sizes.options : null,
        showGoto: preferences.pageShowGoto,
        showJumps: preferences.pageShowScrollTop,
        heroTag: heroTag,
      );
    }
    return _InfiniteFeed(loader: _load, sort: widget.sort, showJumps: preferences.pageShowScrollTop, heroTag: heroTag);
  }

  Future<PageResult<LiveRoom>> _load(PageRequest request) {
    final capability = ref.read(areaProvider(widget.siteId));
    if (capability == null) {
      throw StateError('${widget.siteId} lost its area capability');
    }
    // Errors throw; the controllers keep the shown data and expose the
    // failure on their state.
    return capability
        .getAreaRooms(
          areaId: widget.areaId,
          request: LivePageRequest(page: request.page, pageSize: request.pageSize),
        )
        .then(
          (result) => result.fold(
            (error) => throw _FeedException(error),
            (page) => PageResult(items: page.items, totalCount: page.totalCount, hasMore: page.hasMore),
          ),
        );
  }
}

/// The touch model: one accumulated list, pull to refresh, load more at
/// the end.
final class _InfiniteFeed extends ConsumerStatefulWidget {
  const new({required this.loader, required this.sort, this.showJumps = true, this.heroTag = 'infinite'});

  final PageLoader<LiveRoom> loader;
  final RoomSort sort;

  /// The floating to-top/to-bottom buttons (pager setting).
  final bool showJumps;

  /// Unique per list — two lists may be alive at once.
  final String heroTag;

  @override
  ConsumerState<_InfiniteFeed> createState() => _InfiniteFeedState();
}

final class _InfiniteFeedState extends ConsumerState<_InfiniteFeed> with FeedAutoRefresh<_InfiniteFeed> {
  // The reference's phone page size — what `InfiniteController` defaults to.
  late final InfiniteController<LiveRoom> _controller = InfiniteController(loader: widget.loader);
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);

  @override
  Future<void> feedRefresh() => _controller.refresh();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onState);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onState)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onState(InfiniteState<LiveRoom> state) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) {
      unawaited(_controller.loadNext());
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverAspect = ref.watch(roomCardStyleProvider).aspect.ratio;
    final feed = ref.watch(appPreferencesProvider);
    final state = _controller.state;
    if (state.items.isEmpty) {
      return _placeholder(
        context,
        coverAspect: coverAspect,
        error: state.error,
        loading: state.isRefreshing || state.isUnloaded,
        onRetry: () => unawaited(_controller.refresh()),
      );
    }
    // The discovery rule applies here too: carousels and unpassable
    // restrictions are left out unless the viewer asked to see them.
    final roomVisible = ref.watch(discoveryRoomFilterProvider);
    final visible = [
      for (final room in state.items)
        if (roomVisible(room)) room,
    ];
    final rooms = widget.sort == RoomSort.viewers ? _sortByViewers(visible) : visible;
    return CustomRefreshIndicator(
      onRefresh: _controller.refresh,
      builder: (context, child, indicator) => Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            // The bar needs bounded constraints: a Positioned pinned on `top`
            // alone hands its child unbounded constraints, which a progress bar
            // cannot resolve to a size — a kept-alive off-screen tab then
            // crashes the hit test. Pinning the sides and fixing the width
            // keeps the box laid out in every state.
            child: Center(
              child: SizedBox(
                width: 140,
                child: Opacity(
                  opacity: indicator.value.clamp(0, 1),
                  child: IgnorePointer(child: PureProgress(value: indicator.isLoading ? null : indicator.value)),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RoomGrid(
              scrollController: _scroll,
              crossSpacing: feed.crossAxisSpacing,
              mainSpacing: feed.mainAxisSpacing,
              itemCount: rooms.length,
              itemBuilder: (context, index) => _tile(context, ref, rooms, rooms[index]),
              footer: state.isLoadingMore ? const Center(child: PureSpinner(size: 40)) : null,
            ),
          ),
          if (widget.showJumps)
            Positioned(
              right: 16,
              bottom: 16,
              child: PureJumpButtons(controller: _scroll, heroTag: widget.heroTag),
            ),
        ],
      ),
    );
  }
}

/// The desktop model: exactly one visible page and the shared pagination
/// bar — refresh, page numbers, rooms per page, go to page — with ← → and
/// the jump buttons, as on the reference's paged lists.
final class _PagedFeed extends ConsumerStatefulWidget {
  const new({
    required this.loader,
    required this.sort,
    this.pageSize = 20,
    this.pageSizes,
    this.showGoto = true,
    this.showJumps = true,
    this.heroTag = 'paged',
  });

  final PageLoader<LiveRoom> loader;
  final RoomSort sort;

  /// Rooms on a page at first; the bar can change it for the rest of the
  /// visit (the reference's local override).
  final int pageSize;

  /// The per-page choices; null hides the selector (setting).
  final List<int>? pageSizes;

  /// The "go to page" field (setting).
  final bool showGoto;

  /// The floating to-top/to-bottom buttons (pager setting).
  final bool showJumps;

  /// Unique per list — two lists may be alive at once.
  final String heroTag;

  @override
  ConsumerState<_PagedFeed> createState() => _PagedFeedState();
}

final class _PagedFeedState extends ConsumerState<_PagedFeed> with FeedAutoRefresh<_PagedFeed> {
  late final PagedController<LiveRoom> _controller = PagedController(loader: widget.loader, pageSize: widget.pageSize);
  final ScrollController _scroll = ScrollController();

  @override
  Future<void> feedRefresh() => _controller.refresh();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onState);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onState)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onState(PagedState<LiveRoom> state) {
    if (mounted) {
      setState(() {});
    }
  }

  /// A page change starts the new page at its top (3.x).
  void _goTo(int page) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    unawaited(_controller.loadPage(page));
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final busy = state.isLoading;
    final lastPage = state.totalCount == null ? null : (state.totalCount! / state.pageSize).ceil().clamp(1, 1 << 31);
    // The total is often unknown until the platform runs out: a known last
    // page closes the walk, an unknown one keeps "next" alive.
    final canNext = lastPage == null || state.page < lastPage;
    final choices = widget.pageSizes;
    final pageSizes = choices == null || choices.contains(state.pageSize)
        ? choices
        : ([...choices, state.pageSize]..sort());
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (state.page > 1 && !busy) {
            _goTo(state.page - 1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (!busy && canNext) {
            _goTo(state.page + 1);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _body(context, state)),
                  if (widget.showJumps && state.items.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: PureJumpButtons(controller: _scroll, heroTag: widget.heroTag),
                    ),
                ],
              ),
            ),
            PurePaginationBar(
              page: state.page == 0 ? 1 : state.page,
              lastPage: lastPage,
              canNext: canNext,
              busy: busy,
              pageSize: state.pageSize,
              pageSizes: pageSizes,
              showGoto: widget.showGoto,
              onPage: _goTo,
              onPageSize: (size) => unawaited(_controller.changePageSize(size)),
              onRefresh: () => unawaited(_controller.refresh()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PagedState<LiveRoom> state) {
    final coverAspect = ref.watch(roomCardStyleProvider).aspect.ratio;
    final feed = ref.watch(appPreferencesProvider);
    if (state.items.isEmpty) {
      return _placeholder(
        context,
        coverAspect: coverAspect,
        error: state.error,
        loading: state.isLoading || state.isUnloaded,
        onRetry: () => unawaited(_controller.refresh()),
      );
    }
    // The discovery rule applies here too: carousels and unpassable
    // restrictions are left out unless the viewer asked to see them.
    final roomVisible = ref.watch(discoveryRoomFilterProvider);
    final visible = [
      for (final room in state.items)
        if (roomVisible(room)) room,
    ];
    final rooms = widget.sort == RoomSort.viewers ? _sortByViewers(visible) : visible;
    return RoomGrid(
      scrollController: _scroll,
      crossSpacing: feed.crossAxisSpacing,
      mainSpacing: feed.mainAxisSpacing,
      itemCount: rooms.length,
      itemBuilder: (context, index) => _tile(context, ref, rooms, rooms[index]),
    );
  }
}

/// Shared pieces of both feeds.

List<LiveRoom> _sortByViewers(List<LiveRoom> rooms) {
  int viewers(LiveRoom room) => room.audience.onlineViewers ?? room.audience.popularity ?? 0;
  return [...rooms]..sort((a, b) => viewers(b).compareTo(viewers(a)));
}

Widget _tile(BuildContext context, WidgetRef ref, List<LiveRoom> playlist, LiveRoom room) =>
    RoomCard(room: room, onOpen: () => unawaited(openRoomWithPlaylist(context, ref, playlist, room)));

Widget _placeholder(
  BuildContext context, {
  required double coverAspect,
  required Object? error,
  required bool loading,
  required VoidCallback onRetry,
}) {
  if (error != null) {
    return PureError(message: context.t.errors.network, onRetry: onRetry, retryLabel: context.t.common.retry);
  }
  if (loading) {
    // The shared placeholder follows the loading-style preference and lays its
    // bones on the room grid's columns and cover shape. The cards themselves now
    // choose their own height, so this is the closest estimate the bones can
    // make rather than the exact box — the columns and the cover match to the
    // pixel, a caption that needs more room than the estimate is where the two
    // differ.
    return FeedLoadingPlaceholder(
      delegateBuilder: (width) => RoomGridMetrics.delegateFor(context, width, coverAspect: coverAspect),
    );
  }
  return PureEmpty(title: context.t.common.empty);
}

/// Wraps a site error for the loader contract; the controllers store it on
/// their state and the views render the generic network copy over it.
final class _FeedException implements Exception {
  const new(this.cause);

  /// The site error behind the failure.
  final Object cause;

  @override
  String toString() => 'feed failed: $cause';
}
