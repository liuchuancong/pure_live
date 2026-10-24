import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/refresh_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute, SearchRoute;
import 'package:pure_live/features/favorites/favorite_rules.dart';
import 'package:pure_live/features/favorites/follow_repository.dart';
import 'package:pure_live/features/popular/room_card.dart' show RoomCard;
import 'package:pure_live/features/settings/sites_display_provider.dart' show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/platforms/platform_picker.dart' show kAllPlatforms;

/// The follows page (the reference's `FavoritePage`): the group tabs (all,
/// live, replay, offline — each with its count on the shown platform)
/// above the platform tabs (each with its count in the shown group), a
/// refresh button over the visible slice with its progress bar, and the
/// followed rooms as the home feed's own card grid with an unfollow heart
/// on each cover.
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

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A change from the settings surface re-arms the clock in place.
    ref.listenManual(followsAutoRefreshProvider, (_, _) => _syncTimer());
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded page does not need its clock.
    if (state == AppLifecycleState.resumed) _syncTimer();
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final follows = ref.watch(followsProvider);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    // A platform switched off, or the order dragged, in the settings
    // surface reorders the tabs.
    ref
      ..watch(sitesDisplayProvider)
      ..watch(sitesOrderProvider);
    if (!follows.ready) {
      // A locked box (a second app instance) or a broken store says so,
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
      return CardGrid<LiveRoom>(
        items: const [],
        cardExtent: cardExtent,
        isLoading: true,
        itemBuilder: (_, _) => const SizedBox.shrink(),
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
    final counts = followGroupCounts(follows.rooms, scope);
    final total = followCount(follows.rooms, platform: scope);
    final rooms = [
      for (final room in follows.rooms)
        if (onFollowPlatform(room, scope) && (_group == null || followGroupOf(room) == _group)) room,
    ];

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
                      onChanged: (value) => setState(() => _group = value),
                      tabs: [
                        DsTab<LiveFollowGroup?>(value: null, label: Text(t.favorites.statusAll), count: total),
                        DsTab<LiveFollowGroup?>(
                          value: LiveFollowGroup.live,
                          label: Text(t.favorites.statusLive),
                          count: counts[LiveFollowGroup.live],
                        ),
                        DsTab<LiveFollowGroup?>(
                          value: LiveFollowGroup.replay,
                          label: Text(t.favorites.statusReplay),
                          count: counts[LiveFollowGroup.replay],
                        ),
                        DsTab<LiveFollowGroup?>(
                          value: LiveFollowGroup.offline,
                          label: Text(t.favorites.statusOffline),
                          count: counts[LiveFollowGroup.offline],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DsSpace.s12),
                  _RefreshButton(refreshing: _refreshing, onRefresh: _runRefresh),
                ],
              ),
              // The platform tabs: "all", then every platform with follows
              // in the configured order, each with its count in the group.
              DsTabs<String>(
                value: platform,
                onChanged: (value) => setState(() => _platform = value),
                tabs: [
                  for (final id in <String>[kAllPlatforms, ...platformTabs])
                    DsTab<String>(
                      value: id,
                      label: Text(_platformName(id)),
                      count: followCount(follows.rooms, platform: id == kAllPlatforms ? null : id, group: _group),
                    ),
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
                    onShowOffline: () => setState(() => _group = LiveFollowGroup.offline),
                    onRefresh: _runRefresh,
                  ),
                )
              : CardGrid<LiveRoom>(
                  items: rooms,
                  cardExtent: cardExtent,
                  itemBuilder: (context, room) => _FollowedCard(
                    room: room,
                    onUnfollow: () => unawaited(ref.read(followsProvider.notifier).remove(room.ref.identityKey)),
                  ),
                ),
        ),
      ],
    );
  }

  String _platformName(String id) {
    if (id == kAllPlatforms) return context.t.favorites.statusAll;
    final site = ref.read(sitesProvider).getById(id);
    return site?.manifest.name['zh-CN'] ?? id;
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

/// A followed room's card: the home feed's card with the heart on its
/// cover, pressed to unfollow.
final class _FollowedCard extends StatelessWidget {
  const _FollowedCard({required this.room, required this.onUnfollow});

  final LiveRoom room;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Stack(
      children: [
        RoomCard(
          room: room,
          onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
        ),
        PositionedDirectional(
          top: DsSpace.s8,
          end: DsSpace.s8,
          child: DsPressable(
            semanticLabel: context.t.favorites.unfollow,
            onPressed: onUnfollow,
            builder: (context, states, _) {
              final hovered = states.contains(WidgetState.hovered);
              return Container(
                width: theme.sizes.sm,
                height: theme.sizes.sm,
                decoration: DsBoxDecoration(
                  color: hovered ? colors.danger.fill : colors.overlay,
                  borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
                ),
                child: Center(
                  child: DsIcon(DsIcons.heart, size: theme.sizes.iconSm, color: colors.text),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
