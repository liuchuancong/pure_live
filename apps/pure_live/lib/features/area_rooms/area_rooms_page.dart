import 'dart:async' show unawaited;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_pagination/live_pagination.dart';
import 'package:live_sites/live_sites.dart' show LivePageRequest, LiveRoom;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// How the loaded rooms are ordered.
enum _RoomSort { platform, viewers }

/// The rooms of one area (3.x `AreaRoomsPage`): infinite scroll on phones,
/// numbered pages on desktops — the two interaction models
/// `live_pagination` was built for — plus a client-side sort (platform
/// order or most viewers first).
final class AreaRoomsPage extends ConsumerStatefulWidget {
  /// Shows [areaId] of [siteId]; [areaName] titles the page.
  const new({required this.siteId, required this.areaId, required this.areaName, super.key});

  /// The platform the area belongs to.
  final String siteId;

  /// The area's id.
  final String areaId;

  /// The area's display name.
  final String areaName;

  @override
  ConsumerState<AreaRoomsPage> createState() => _AreaRoomsPageState();
}

final class _AreaRoomsPageState extends ConsumerState<AreaRoomsPage> {
  /// How the loaded rooms are ordered.
  _RoomSort _sort = _RoomSort.platform;

  /// Whether this window pages (large) or grows the list (small/medium).
  bool _pagedLayout(BuildContext context) => switch (BreakpointsQualifier().qualify(context)) {
    ScreenSize.large => true,
    ScreenSize.small || ScreenSize.medium => false,
  };

  Widget _appBar(BuildContext context) => PureAppBar(
    title: widget.areaName.isEmpty ? widget.areaId : widget.areaName,
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Center(
          child: SegmentedButton<_RoomSort>(
            segments: [
              ButtonSegment(value: _RoomSort.platform, label: Text(context.t.room.sortPlatform)),
              ButtonSegment(value: _RoomSort.viewers, label: Text(context.t.room.sortViewers)),
            ],
            selected: {_sort},
            onSelectionChanged: (selection) => setState(() => _sort = selection.first),
            showSelectedIcon: false,
          ),
        ),
      ),
      const SettingsEntryButton(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final paged = _pagedLayout(context);
    return PureScaffold(
      appBar: _appBar(context),
      body: paged ? _PagedFeed(loader: _load, sort: _sort) : _InfiniteFeed(loader: _load, sort: _sort),
    );
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
  const new({required this.loader, required this.sort});

  final PageLoader<LiveRoom> loader;
  final _RoomSort sort;

  @override
  ConsumerState<_InfiniteFeed> createState() => _InfiniteFeedState();
}

final class _InfiniteFeedState extends ConsumerState<_InfiniteFeed> {
  late final InfiniteController<LiveRoom> _controller = InfiniteController(loader: widget.loader);
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);

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
    final state = _controller.state;
    if (state.items.isEmpty) {
      return _placeholder(
        context,
        error: state.error,
        loading: state.isRefreshing || state.isUnloaded,
        onRetry: () => unawaited(_controller.refresh()),
      );
    }
    final rooms = widget.sort == _RoomSort.viewers ? _sortByViewers(state.items) : state.items;
    return CustomRefreshIndicator(
      onRefresh: _controller.refresh,
      builder: (context, child, indicator) => Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          Positioned(
            top: 12,
            child: Opacity(
              opacity: indicator.value.clamp(0, 1),
              child: IgnorePointer(child: PureProgress(value: indicator.isLoading ? null : indicator.value)),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.sm, PureSpacing.sm, PureSpacing.xl),
          gridDelegate: _roomGridDelegate(context, constraints.maxWidth),
          itemCount: rooms.length + 1,
          itemBuilder: (context, index) {
            if (index < rooms.length) {
              return _tile(context, rooms[index]);
            }
            return state.isLoadingMore ? const Center(child: PureSpinner(size: 40)) : const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

/// The desktop model: exactly one visible page, first/previous/next and a
/// window of page numbers.
final class _PagedFeed extends ConsumerStatefulWidget {
  const new({required this.loader, required this.sort});

  final PageLoader<LiveRoom> loader;
  final _RoomSort sort;

  @override
  ConsumerState<_PagedFeed> createState() => _PagedFeedState();
}

final class _PagedFeedState extends ConsumerState<_PagedFeed> {
  late final PagedController<LiveRoom> _controller = PagedController(loader: widget.loader);

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
    super.dispose();
  }

  void _onState(PagedState<LiveRoom> state) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final lastPage = state.totalCount == null ? null : (state.totalCount! / state.pageSize).ceil().clamp(1, 1 << 31);
    return Column(
      children: [
        Expanded(child: _body(context, state)),
        _bar(context, state, lastPage),
      ],
    );
  }

  Widget _body(BuildContext context, PagedState<LiveRoom> state) {
    if (state.items.isEmpty) {
      return _placeholder(
        context,
        error: state.error,
        loading: state.isLoading || state.isUnloaded,
        onRetry: () => unawaited(_controller.refresh()),
      );
    }
    final rooms = widget.sort == _RoomSort.viewers ? _sortByViewers(state.items) : state.items;
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.sm, PureSpacing.sm, PureSpacing.xl),
        gridDelegate: _roomGridDelegate(context, constraints.maxWidth),
        itemCount: rooms.length,
        itemBuilder: (context, index) => _tile(context, rooms[index]),
      ),
    );
  }

  Widget _bar(BuildContext context, PagedState<LiveRoom> state, int? lastPage) {
    final busy = state.isLoading;
    final page = state.page;
    final numbers = [
      for (var candidate = page - 2; candidate <= page + 2; candidate++)
        if (candidate >= 1 && (lastPage == null || candidate <= lastPage)) candidate,
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: PureTheme.of(context).colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PureIconButton(
            tooltip: context.t.common.retry,
            icon: Icons.refresh,
            onPressed: busy ? null : () => unawaited(_controller.refresh()),
          ),
          PureIconButton(
            tooltip: '|<',
            icon: Icons.first_page,
            onPressed: page > 1 && !busy ? () => unawaited(_controller.first()) : null,
          ),
          PureIconButton(
            tooltip: '<',
            icon: Icons.chevron_left,
            onPressed: page > 1 && !busy ? () => unawaited(_controller.previous()) : null,
          ),
          for (final number in numbers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: number == page
                  ? Text(
                      '$number',
                      style: TextStyle(fontWeight: FontWeight.w700, color: PureTheme.of(context).colors.primary),
                    )
                  : PureButton(
                      label: '$number',
                      variant: ButtonVariant.ghost,
                      onPressed: busy ? null : () => unawaited(_controller.loadPage(number)),
                    ),
            ),
          PureIconButton(
            tooltip: '>',
            icon: Icons.chevron_right,
            onPressed: (lastPage == null || page < lastPage) && !busy ? () => unawaited(_controller.next()) : null,
          ),
          const SizedBox(width: 12),
          Text(
            context.t.common.pageOf(page: page, total: lastPage ?? 0),
            style: PureTheme.of(context).text.caption,
          ),
        ],
      ),
    );
  }
}

/// Shared pieces of both feeds.

/// The grid both feeds lay their cards into (3.x `area_rooms` delegate):
/// columns react to the window's width and every tile reserves the 16:9
/// cover plus its caption through [RoomGridMetrics].
SliverGridDelegateWithFixedCrossAxisCount _roomGridDelegate(BuildContext context, double width) =>
    RoomGridMetrics.delegateFor(context, width);

List<LiveRoom> _sortByViewers(List<LiveRoom> rooms) {
  int viewers(LiveRoom room) => room.audience.onlineViewers ?? room.audience.popularity ?? 0;
  return [...rooms]..sort((a, b) => viewers(b).compareTo(viewers(a)));
}

Widget _tile(BuildContext context, LiveRoom room) => RoomCard(
  room: room,
  onOpen: () =>
      RoomRoute(siteId: room.ref.platform, roomId: room.ref.roomId, roomName: room.content.title).push<void>(context),
);

Widget _placeholder(
  BuildContext context, {
  required Object? error,
  required bool loading,
  required VoidCallback onRetry,
}) {
  if (error != null) {
    return PureError(message: context.t.errors.network, onRetry: onRetry, retryLabel: context.t.common.retry);
  }
  if (loading) {
    // A bone grid shaped exactly like the room grid, so content replaces
    // the skeleton without a layout jump. Fixed-height bars rather than
    // placeholder letters: a skeleton has to fit its tile in every design
    // language and text scale.
    return LayoutBuilder(
      builder: (context, constraints) => Skeletonizer(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PureSpacing.sm),
          gridDelegate: _roomGridDelegate(context, constraints.maxWidth),
          itemCount: RoomGridMetrics.columnsFor(constraints.maxWidth) * 3,
          itemBuilder: (context, index) => PureCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 12, width: double.infinity, child: ColoredBox(color: Colors.white24)),
                            SizedBox(height: 6),
                            SizedBox(width: 96, height: 10, child: ColoredBox(color: Color(0x26FFFFFF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
