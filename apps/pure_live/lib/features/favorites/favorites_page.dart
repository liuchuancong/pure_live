import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/refresh_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/favorites/follow_repository.dart';
import 'package:pure_live/features/home/room_card.dart' show RoomCard;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/platforms/platform_picker.dart';

/// The follows page (the reference's `FavoritePage`): the status tabs
/// (live / offline / all) beside the platform tabs ("all", then every
/// platform with follows), a refresh button over the visible slice, and
/// the followed rooms as the home feed's own card grid with an unfollow
/// heart on each cover.
final class FavoritesPage extends ConsumerStatefulWidget {
  /// The favorites page.
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

/// The status the tabs filter by.
enum _FollowStatus { all, live, offline }

final class _FavoritesPageState extends ConsumerState<FavoritesPage> with WidgetsBindingObserver {
  _FollowStatus _status = _FollowStatus.all;

  /// The platform shown ([kAllPlatforms] for all); local like the
  /// reference's — what a follow list shows depends on what is followed.
  String _platform = kAllPlatforms;

  /// Whether a refresh is running: the header's button spins.
  bool _refreshing = false;

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
      unawaited(_runRefresh());
    });
  }

  Future<void> _runRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(followsProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final follows = ref.watch(followsProvider);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
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
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.heart),
          title: Text(t.favorites.emptyTitle),
          description: Text(t.favorites.emptyDescription),
        ),
      );
    }

    // The platform tabs: "all", then every platform with follows, in
    // registry order (the reference's platformTabs).
    final platforms = <String>[
      kAllPlatforms,
      ...{for (final room in follows.rooms) room.ref.platform},
    ];
    final rooms = [
      for (final room in follows.rooms)
        if ((_platform == kAllPlatforms || room.ref.platform == _platform) &&
            (_status == _FollowStatus.all || (_status == _FollowStatus.live) == room.broadcast.isLiveNow))
          room,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          // A wrap, not a row: the status segments, the platform tabs and
          // the refresh button each keep their own width, and a narrow
          // window flows them onto a second line instead of overflowing.
          child: Wrap(
            spacing: DsSpace.s12,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DsSegmentedControl<_FollowStatus>(
                segments: [
                  DsSegment(value: _FollowStatus.all, label: Text(t.favorites.statusAll)),
                  DsSegment(value: _FollowStatus.live, label: Text(t.favorites.statusLive)),
                  DsSegment(value: _FollowStatus.offline, label: Text(t.favorites.statusOffline)),
                ],
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
              SizedBox(
                width: 260,
                child: PlatformTabRow(
                  platforms: platforms,
                  current: _platform,
                  nameOf: _platformName,
                  semanticLabel: t.favorites.statusAll,
                  onChanged: (id) => setState(() => _platform = id),
                ),
              ),
              _RefreshButton(refreshing: _refreshing, onRefresh: _runRefresh),
            ],
          ),
        ),
        Expanded(
          child: CardGrid<LiveRoom>(
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
