import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/data/favorite_rules.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/modules/live/favorites/data/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/modules/live/favorites/widgets/favorites_widgets.dart';
import 'package:pure_live/modules/live/popular/popular.dart' show RoomCard, RoomCardMenu;
import 'package:pure_live/shared/shared.dart';

/// The follows page (the reference's `FavoritePage`): the group tabs (live,
/// replay, offline, all — each with its count on the shown platform) above
/// the platform tabs (each with its count in the shown group), a refresh
/// button over the visible slice with its progress bar, and the followed
/// rooms as the shared room card — its own tags on the list rows — with the
/// reference's pager under them once they fill more than one page.
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

  /// The page shown on the bottom pager, from 1. The page is measured in the
  /// shown platform's own feed window (see [roomFeedRequestSize]), so a page
  /// is one refresh's worth of rooms rather than a number the viewer sets.
  int _page = 1;

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
          .refreshRooms(
            targets,
            onProgress: showProgress ? _onRefreshProgress : null,
            // A manual pass is one the viewer is watching: no alerts.
            quiet: showProgress,
          );
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

  void _jumpToTop() {
    if (_gridScroll.hasClients) _gridScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final follows = ref.watch(followsProvider);
    final layout = ref.watch(browseLayoutProvider);
    // The page size follows the platform tab, which resets the page itself;
    // nothing re-slices from the settings surface any more.
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
          listMatchesGridWidth: true,
          // The follows rows carry their tags, so the list is a line taller
          // than a plain room row.
          listMainAxisExtent: kRoomCardListTagsHeight,
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
    final pageSize = roomFeedRequestSize(platform);
    final lastPage = rooms.isEmpty ? 1 : (rooms.length + pageSize - 1) ~/ pageSize;
    final page = _page.clamp(1, lastPage);
    final start = (page - 1) * pageSize;
    final end = start + pageSize > rooms.length ? rooms.length : start + pageSize;
    final visibleRooms = rooms.sublist(start, end);

    Widget cardFor(LiveRoom room, {bool listRow = false}) {
      final names = [for (final id in room.local.tagIds) ?tagNames[id]];
      void open() => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: rooms);
      // The card's own menu already carries open, share, links, unfollow
      // and the tags; the page adds nothing of its own.
      return RoomCardMenu(
        room: room,
        onOpen: open,
        child: RoomCard(room: room, listRow: listRow, tags: names, onOpen: open),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
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
                  _RefreshButton(refreshing: _refreshing, onRefresh: _runRefresh),
                ],
              ),
              // The platform tabs, the wall behind the chevron and the grid
              // switch: one row, exactly as 热门 and 分区 lay them out. Each
              // name carries how many follows it holds in the shown group,
              // and the wall repeats that count under the logo.
              PlatformTabRow(
                platforms: [kAllPlatforms, ...platformTabs],
                current: platform,
                nameOf: _platformName,
                semanticLabel: t.navigation.favorites,
                countOf: (id) => followCount(follows.rooms, platform: id == kAllPlatforms ? null : id, group: _group),
                onManagePlatforms: () =>
                    unawaited(context.push(SettingsSectionRoute(section: SettingsSection.sitesDisplay.name).location)),
                onChanged: _selectPlatform,
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
                    listMatchesGridWidth: true,
                    listMainAxisExtent: kRoomCardListTagsHeight,
                    listItemBuilder: (context, room) => cardFor(room, listRow: true),
                    scrollController: _gridScroll,
                    itemBuilder: (context, room) => cardFor(room),
                  ),
                ),
        ),
        if (lastPage > 1)
          FavoritesPager(page: page, pageCount: lastPage, busy: _refreshing, onPage: _goToPage, onRefresh: _runRefresh),
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
    return DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      semanticLabel: context.t.favorites.refresh,
      loading: refreshing,
      onPressed: refreshing ? null : () => unawaited(onRefresh()),
      icon: DsIcon(DsIcons.refreshCw, size: DsTheme.of(context).sizes.iconSm),
    );
  }
}
