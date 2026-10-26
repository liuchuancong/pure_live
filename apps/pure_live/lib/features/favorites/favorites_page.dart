import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/page_size_options_provider.dart' show pageSizeOptionsProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show SearchRoute;
import 'package:pure_live/features/favorites/favorite_rules.dart';
import 'package:pure_live/features/favorites/favorites_widgets.dart';
import 'package:pure_live/features/favorites/follow_repository.dart';
import 'package:pure_live/features/favorites/follow_tag_picker.dart' show showFollowTagPicker;
import 'package:pure_live/features/favorites/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/features/settings/room_card_settings.dart'
    show RoomCardLayout, roomCardAppearanceProvider;
import 'package:pure_live/features/settings/sites_display_provider.dart' show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/grids/layout_toggle.dart' show LayoutToggle;
import 'package:pure_live/shared/navigation/room_opener.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteIcon, localizedSiteName;
import 'package:pure_live/shared/platforms/platform_picker.dart' show kAllPlatforms;

/// The narrowest card the follows grid uses when dense mode is off (the
/// reference's large follows card).
const double _favoriteLargeCardMinWidth = 300;

/// The widest a compact follows card gets, so dense mode always stays
/// smaller than the large cards.
const double _favoriteDenseCardMaxWidth = 280;

/// The gap and padding the follows grid's [CardGrid] uses (its defaults):
/// the card measure is worked out from the same box, so the columns match
/// the reference's minimum width.
const double _favoriteGridGap = DsSpace.s16;
const EdgeInsets _favoriteGridPadding = EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24);

/// A card measure for [width] that gives the follows grid the reference's
/// columns: compact cards keep the browsing width (up to a small-card cap),
/// while large cards are as wide as the row allows around the 300 px floor.
double _favoriteCardExtent({required bool dense, required double width, required double preferred}) {
  if (dense) return math.min(preferred, _favoriteDenseCardMaxWidth);
  final content = math.max(0, width - _favoriteGridPadding.horizontal);
  final columns = math.max(1, ((content + _favoriteGridGap) / (_favoriteLargeCardMinWidth + _favoriteGridGap)).floor());
  // A hair above the exact item width keeps the grid's own ceil() on the
  // intended column count instead of tipping into one more.
  return (content - _favoriteGridGap * (columns - 1)) / columns + 0.01;
}

/// The follows page (the reference's `FavoritePage`): the group tabs (live,
/// replay, offline, all — each with its count on the shown platform) above
/// the platform tabs (each with its count in the shown group), a refresh
/// button over the visible slice with its progress bar, and the followed
/// rooms as cards carrying their audience over the cover and a
/// streamer · status · audience line, with the reference's pager under
/// them once they fill more than one page.
final class FavoritesPage extends ConsumerStatefulWidget {
  /// The favorites page.
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

final class _FavoritesPageState extends ConsumerState<FavoritesPage> with WidgetsBindingObserver {
  /// The group shown; null is every group.
  LiveFollowGroup? _group;

  /// The platform shown ([kAllPlatforms] for all); local like the
  /// reference's — what a follow list shows depends on what is followed.
  String _platform = kAllPlatforms;

  /// Whether a refresh is running: the header's button spins.
  bool _refreshing = false;

  /// Progress of the visible refresh (0..1); null when none is shown.
  double? _progress;

  /// The tag shown, or null for every tag.
  String? _tag;

  /// The page shown on the bottom pager, from 1.
  int _page = 1;

  /// How many follows one page holds; the shared default until the pager
  /// is changed.
  int _pageSize = 20;

  /// The pager's choices from the shared options, keeping the current size
  /// visible even if it was just removed from the list.
  List<int> _pagerSizes(List<int> options) => {...options, _pageSize}.toList()..sort();

  /// The grid's position, so a new page starts at its top.
  final ScrollController _gridScroll = ScrollController();

  Timer? _autoRefresh;

  /// The reference waits for the foreground transition to settle, then skips
  /// the pass when a refresh just completed.
  static const Duration _resumeRefreshDelay = Duration(milliseconds: 450);
  static const Duration _resumeRefreshStaleAfter = Duration(seconds: 15);

  Timer? _resumeRefresh;

  /// When a refresh last completed; a resume inside
  /// [_resumeRefreshStaleAfter] does not repeat it.
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    _pageSize = ref.read(browseSettingsProvider).homePageSize.clamp(1, 100);
    WidgetsBinding.instance.addObserver(this);
    // A change from the settings surface re-arms the clock in place.
    ref.listenManual(followsAutoRefreshProvider, (_, _) {
      _syncTimer();
      if (!ref.read(followsAutoRefreshProvider).onResume) _cancelResumeRefresh();
    });
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    _cancelResumeRefresh();
    _gridScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded page does not need its clock or a pending resume pass.
    if (state == AppLifecycleState.resumed) {
      _syncTimer();
      _scheduleResumeRefresh();
    } else {
      _cancelResumeRefresh();
    }
  }

  /// Arms the reference's one-shot foreground refresh. It is independent of
  /// the periodic clock: the switch defaults on even with auto refresh off.
  void _scheduleResumeRefresh() {
    _cancelResumeRefresh();
    if (!ref.read(followsAutoRefreshProvider).onResume) return;
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < _resumeRefreshStaleAfter) return;
    _resumeRefresh = Timer(_resumeRefreshDelay, () {
      _resumeRefresh = null;
      if (!mounted || _refreshing) return;
      unawaited(_refresh(ref.read(followsProvider).rooms, showProgress: false));
    });
  }

  void _cancelResumeRefresh() {
    _resumeRefresh?.cancel();
    _resumeRefresh = null;
  }

  /// Re-arms the auto refresh after the choice or the page changed: a new
  /// interval replaces the running clock, an off choice stops it.
  void _syncTimer() {
    final choice = ref.read(followsAutoRefreshProvider);
    _autoRefresh?.cancel();
    if (!choice.enabled) return;
    _autoRefresh = Timer.periodic(Duration(minutes: choice.minutes), (_) {
      if (!mounted || _refreshing) return;
      // The clock keeps every follow current, whatever tab is shown (the
      // reference's `autoRefreshFavorite`); it stays silent.
      unawaited(_refresh(ref.read(followsProvider).rooms, showProgress: false));
    });
  }

  /// The platform shown, falling back to "all" when its last follow left.
  String _visiblePlatform(List<LiveRoom> rooms) {
    if (_platform == kAllPlatforms) return kAllPlatforms;
    final platforms = followPlatformTabs(rooms, ref.read(sitesDisplayProvider.notifier).visibleIds());
    return platforms.contains(_platform) ? _platform : kAllPlatforms;
  }

  /// Refreshes the visible platform and group (the reference's
  /// `refreshVisible`). An empty group refreshes its platform instead: the
  /// refresh is what moves a room into the group, so refreshing nothing
  /// would leave the empty state's button dead.
  Future<void> _runRefresh() async {
    final rooms = ref.read(followsProvider).rooms;
    final platform = _visiblePlatform(rooms);
    final scope = platform == kAllPlatforms ? null : platform;
    final slice = [
      for (final room in rooms)
        if (onFollowPlatform(room, scope) && (_group == null || followGroupOf(room) == _group)) room,
    ];
    final targets = slice.isEmpty
        ? [
            for (final room in rooms)
              if (onFollowPlatform(room, scope)) room,
          ]
        : slice;
    await _refresh(targets, showProgress: true);
  }

  Future<void> _refresh(List<LiveRoom> targets, {required bool showProgress}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (showProgress) _progress = 0;
    });
    try {
      final failed = await ref
          .read(followsProvider.notifier)
          .refreshRooms(targets, onProgress: showProgress ? _onRefreshProgress : null);
      if (showProgress && failed > 0 && mounted) {
        showDsToast(
          context: context,
          title: context.t.favorites.refreshFailed(count: failed),
          status: DsStatus.danger,
        );
      }
    } finally {
      _lastRefreshAt = DateTime.now();
      if (mounted) {
        setState(() {
          _refreshing = false;
          _progress = null;
        });
      }
    }
  }

  void _onRefreshProgress(int done, int total) {
    if (!mounted) return;
    setState(() => _progress = total == 0 ? 1 : done / total);
  }

  /// Switches the group: a new slice starts on its first page.
  void _selectGroup(LiveFollowGroup? group) {
    if (_group == group) return;
    setState(() {
      _group = group;
      _page = 1;
    });
    _jumpToTop();
  }

  /// Switches the platform: a new slice starts on its first page.
  void _selectPlatform(String platform) {
    if (_platform == platform) return;
    setState(() {
      _platform = platform;
      _page = 1;
    });
    _jumpToTop();
  }

  /// Shows [page] and scrolls the cards back to the top.
  void _goToPage(int page) {
    setState(() => _page = page);
    _jumpToTop();
  }

  /// Changes the page size, keeping the first room the viewer was seeing
  /// on the page it lands on (the reference's `onPageSize`).
  void _changePageSize(int size) {
    final firstIndex = (_page - 1) * _pageSize;
    setState(() {
      _pageSize = size;
      _page = firstIndex ~/ size + 1;
    });
    _jumpToTop();
  }

  void _jumpToTop() {
    if (_gridScroll.hasClients) _gridScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final follows = ref.watch(followsProvider);
    final browseCardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final dense = ref.watch(favoritesDensityProvider);
    final layout = ref.watch(browseLayoutProvider);
    // A platform switched off, or the order dragged, in the settings
    // surface reorders the tabs.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    if (!follows.ready) {
      // A failed database open or a broken store says so,
      // with the retry that re-opens the repository once the other
      // instance is gone.
      if (follows.error != null) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.cloudOff),
            title: Text(t.favorites.openFailedTitle),
            description: Text(follows.error!),
            actions: [
              DsButton(
                variant: DsButtonVariant.primary,
                size: DsSize.sm,
                onPressed: () {
                  ref
                    ..invalidate(followRepositoryProvider)
                    ..invalidate(followsProvider);
                },
                child: Text(t.common.retry),
              ),
            ],
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) => CardGrid<LiveRoom>(
          items: const [],
          layout: layout,
          aspectRatio: ref.watch(roomCardAppearanceProvider).layout == RoomCardLayout.compact
              ? CardGrid.roomCardCompactAspectRatio
              : CardGrid.roomCardAspectRatio,
          cardExtent: _favoriteCardExtent(dense: dense, width: constraints.maxWidth, preferred: browseCardExtent),
          isLoading: true,
          itemBuilder: (_, _) => const SizedBox.shrink(),
        ),
      );
    }
    if (follows.rooms.isEmpty) {
      // Nothing followed at all: the one useful next step is finding a
      // room, so the empty page opens the search.
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.heart),
          title: Text(t.favorites.emptyTitle),
          description: Text(t.favorites.emptyDescription),
          actions: [
            DsButton(
              variant: DsButtonVariant.primary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.search, size: 16),
              onPressed: () => const SearchRoute().go(context),
              child: Text(t.favorites.searchLive),
            ),
          ],
        ),
      );
    }

    final platformTabs = followPlatformTabs(follows.rooms, ref.read(sitesDisplayProvider.notifier).visibleIds());
    final platform = platformTabs.contains(_platform) ? _platform : kAllPlatforms;
    final scope = platform == kAllPlatforms ? null : platform;
    final tags = ref.watch(followTagsProvider);
    // A tag removed while selected falls back to every tag rather than
    // showing an empty page nobody can explain.
    final selectedTag = tags.any((tag) => tag.id == _tag) ? _tag : null;
    final tagNames = {for (final tag in tags) tag.id: tag.name};
    final counts = followGroupCounts(follows.rooms, scope);
    final total = followCount(follows.rooms, platform: scope);
    final rooms = [
      for (final room in follows.rooms)
        if (onFollowPlatform(room, scope) &&
            (_group == null || followGroupOf(room) == _group) &&
            (selectedTag == null || room.local.tagIds.contains(selectedTag)))
          room,
    ];
    // The pager slices the loaded follows locally; the shown page is kept
    // inside the slice that is left after a filter or an unfollow.
    final lastPage = rooms.isEmpty ? 1 : (rooms.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(1, lastPage);
    final start = (page - 1) * _pageSize;
    final end = start + _pageSize > rooms.length ? rooms.length : start + _pageSize;
    final visibleRooms = rooms.sublist(start, end);

    Widget cardFor(LiveRoom room, {required bool compact}) {
      final names = [for (final id in room.local.tagIds) ?tagNames[id]];
      return DsContextMenuRegion(
        semanticLabel: t.common.more,
        items: [
          DsMenuItem(
            leading: const DsIcon(DsIcons.tag),
            label: Text(t.favorites.setTags),
            onPressed: () => unawaited(showFollowTagPicker(context, room)),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.heartCrack),
            label: Text(t.favorites.unfollow),
            destructive: true,
            onPressed: () => unawaited(ref.read(followsProvider.notifier).remove(room.ref.identityKey)),
          ),
        ],
        child: FollowedRoomCard(
          room: room,
          compact: compact,
          tags: names,
          platformName: platform == kAllPlatforms ? _platformName(room.ref.platform) : null,
          onOpen: () => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId),
          onUnfollow: () => unawaited(ref.read(followsProvider.notifier).remove(room.ref.identityKey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              // The group tabs and the refresh button share the first line:
              // the tabs scroll, the button keeps its width.
              Row(
                children: [
                  Expanded(
                    child: DsTabs<LiveFollowGroup?>(
                      value: _group,
                      onChanged: _selectGroup,
                      tabs: [
                        // The reference's order: live, replay, offline, all.
                        DsTab<LiveFollowGroup?>(
                          value: LiveFollowGroup.live,
                          label: Text(t.favorites.statusLiveNow),
                          count: counts[LiveFollowGroup.live],
                        ),
                        DsTab<LiveFollowGroup?>(
                          value: LiveFollowGroup.replay,
                          label: Text(t.favorites.statusReplay),
                          count: counts[LiveFollowGroup.replay],
                        ),
                        DsTab<LiveFollowGroup?>(
                          value: LiveFollowGroup.offline,
                          label: Text(t.favorites.statusOfflineNow),
                          count: counts[LiveFollowGroup.offline],
                        ),
                        DsTab<LiveFollowGroup?>(value: null, label: Text(t.favorites.statusAll), count: total),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsSpace.s12),
                  const LayoutToggle(),
                  const SizedBox(width: DsSpace.s8),
                  _RefreshButton(refreshing: _refreshing, onRefresh: _runRefresh),
                ],
              ),
              // The platform tabs: "all", then every platform with follows
              // in the configured order, each with its count in the group.
              DsTabs<String>(
                value: platform,
                onChanged: _selectPlatform,
                tabs: [
                  for (final id in <String>[kAllPlatforms, ...platformTabs])
                    DsTab<String>(
                      value: id,
                      label: id == kAllPlatforms
                          ? Text(_platformName(id))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 6,
                              children: [
                                ?localizedSiteIcon(ref.read(sitesProvider).getById(id), size: 14),
                                Text(_platformName(id)),
                              ],
                            ),
                      count: followCount(follows.rooms, platform: id == kAllPlatforms ? null : id, group: _group),
                    ),
                ],
              ),
              if (tags.isNotEmpty)
                DsChoiceChips<String?>(
                  value: selectedTag,
                  onChanged: (value) => setState(() => _tag = value),
                  semanticLabel: t.favorites.tagsFilter,
                  options: [
                    DsChipOption(value: null, label: Text(t.favorites.allTags)),
                    for (final tag in tags) DsChipOption(value: tag.id, label: Text(tag.name)),
                  ],
                ),
              if (_progress case final progress?)
                DsProgressBar(
                  value: progress,
                  semanticLabel: t.favorites.refresh,
                  style: const DsProgressBarStyle(height: 2.5),
                ),
            ],
          ),
        ),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: _EmptySlice(
                    group: _group,
                    offlineCount: counts[LiveFollowGroup.offline] ?? 0,
                    refreshing: _refreshing,
                    onShowOffline: () => _selectGroup(LiveFollowGroup.offline),
                    onRefresh: _runRefresh,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => CardGrid<LiveRoom>(
                    items: visibleRooms,
                    layout: layout,
                    aspectRatio: ref.watch(roomCardAppearanceProvider).layout == RoomCardLayout.compact
                        ? CardGrid.roomCardCompactAspectRatio
                        : CardGrid.roomCardAspectRatio,
                    listItemBuilder: (context, room) => cardFor(room, compact: true),
                    cardExtent: _favoriteCardExtent(
                      dense: dense,
                      width: constraints.maxWidth,
                      preferred: browseCardExtent,
                    ),
                    scrollController: _gridScroll,
                    itemBuilder: (context, room) => cardFor(room, compact: false),
                  ),
                ),
        ),
        if (lastPage > 1)
          FavoritesPager(
            page: page,
            pageCount: lastPage,
            pageSize: _pageSize,
            busy: _refreshing,
            showPageSize: ref.watch(showPageSizeSelectorProvider),
            showGoto: ref.watch(showGotoButtonProvider),
            pageSizes: _pagerSizes(ref.watch(pageSizeOptionsProvider)),
            onPage: _goToPage,
            onPageSize: _changePageSize,
            onRefresh: _runRefresh,
          ),
      ],
    );
  }

  String _platformName(String id) {
    if (id == kAllPlatforms) return context.t.favorites.statusAll;
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }
}

/// The empty state of one group on the shown platform: the group's title,
/// a refresh, and — when offline follows exist elsewhere — the hint and
/// button that switch to them (the reference's "view offline").
final class _EmptySlice extends StatelessWidget {
  const _EmptySlice({
    required this.group,
    required this.offlineCount,
    required this.refreshing,
    required this.onShowOffline,
    required this.onRefresh,
  });

  final LiveFollowGroup? group;
  final int offlineCount;
  final bool refreshing;
  final VoidCallback onShowOffline;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canShowOffline = group != LiveFollowGroup.offline && offlineCount > 0;
    final title = switch (group) {
      LiveFollowGroup.live => t.favorites.emptyLiveTitle,
      LiveFollowGroup.replay => t.favorites.emptyReplayTitle,
      LiveFollowGroup.offline => t.favorites.emptyOfflineTitle,
      null => t.favorites.emptyTitle,
    };
    return DsEmptyState(
      icon: DsIcon(group == LiveFollowGroup.offline ? DsIcons.eyeOff : DsIcons.heart),
      title: Text(title),
      description: Text(canShowOffline ? t.favorites.emptyOfflineHint : t.favorites.emptyGroupHint),
      actions: [
        if (canShowOffline)
          DsButton(
            variant: DsButtonVariant.primary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.eyeOff, size: 16),
            onPressed: onShowOffline,
            child: Text(t.favorites.showOffline),
          ),
        DsButton(
          variant: canShowOffline ? DsButtonVariant.secondary : DsButtonVariant.primary,
          size: DsSize.sm,
          onPressed: refreshing ? null : onRefresh,
          child: Text(t.favorites.refresh),
        ),
      ],
    );
  }
}

/// The header's refresh button: a spinner while the refresh runs.
final class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.refreshing, required this.onRefresh});

  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: context.t.favorites.refresh,
      onPressed: refreshing ? null : onRefresh,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 30,
          height: 30,
          decoration: DsBoxDecoration(
            color: hovered && !refreshing ? colors.hover : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: refreshing
                ? const SizedBox(width: 14, height: 14, child: DsSpinner())
                : DsIcon(DsIcons.refreshCw, size: 16, color: colors.textMuted),
          ),
        );
      },
    );
  }
}
