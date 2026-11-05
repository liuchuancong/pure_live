import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart' show kRoomCardListDesignHeight, roomCardTileHeight;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart' show followsProvider;
import 'package:pure_live/modules/live/popular/popular.dart' show RoomCard, RoomCardMenu;
import 'package:pure_live/modules/vod/controller/vod_live.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar;
import 'package:pure_live/shared/shared.dart';

/// The followed shelf's row card, and the pair of them plus the gap a column
/// needs before the shelf keeps that form: narrower than this the rail shows
/// one room and a sliver of the next.
const double _kFollowRowCardWidth = 320;

/// The narrowest the shelf's cover card gets, so a 300px window still reads a
/// title instead of two halves too cramped to use.
const double _kFollowCardMinWidth = 150;

/// The reference's 直播 rail entry: the followed rooms and the site's areas
/// over Bilibili's recommended live feed, pages of it as the grid is read.
final class VodLivePage extends ConsumerStatefulWidget {
  /// The live page.
  const VodLivePage({super.key});

  @override
  ConsumerState<VodLivePage> createState() => _VodLivePageState();
}

final class _VodLivePageState extends ConsumerState<VodLivePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodLiveProvider.notifier).open());
    });
  }

  void _openRoom(LiveRoom room, List<LiveRoom> playlist) {
    unawaited(openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, room: room, playlist: playlist));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final settings = ref.watch(browseSettingsProvider);
    final feed = ref.watch(vodLiveProvider);
    final controller = ref.read(vodLiveProvider.notifier);
    final followed = ref.watch(followsProvider);
    final areas = ref.watch(vodLiveAreasProvider).value ?? const <LiveArea>[];
    final followedRooms = [
      for (final room in followed.rooms)
        if (room.ref.platform == SiteIds.bilibili) room,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (followedRooms.isNotEmpty)
          _Section(
            title: t.vod.liveFollowTitle,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The column the shelf is drawn in picks its form. A row card
                // needs two of itself to read as a shelf; below that the rail
                // showed one room and a 26px hint of the next on a 390 phone.
                // There the cards take the shape the feed's grid already uses
                // — 16:9 cover over the room card's own information block —
                // two to a screen; a column that holds two rows keeps the row,
                // which also carries the tags and the audience figure. The gap
                // is the feed's own, so the shelf and the grid below it
                // separate their cards the same way.
                final spacing = settings.crossSpacing;
                final content = math.max(0, constraints.maxWidth - inset * 2).toDouble();
                final holdsRows = content >= _kFollowRowCardWidth * 2 + spacing;
                final cardWidth = holdsRows
                    ? _kFollowRowCardWidth
                    : math.max(_kFollowCardMinWidth, (content - spacing) / 2);
                final cardExtent = holdsRows ? kRoomCardListDesignHeight : roomCardTileHeight(cardWidth);
                return SizedBox(
                  height: cardExtent,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    itemCount: followedRooms.length,
                    separatorBuilder: (context, index) => SizedBox(width: spacing),
                    itemBuilder: (context, index) {
                      final room = followedRooms[index];
                      return SizedBox(
                        width: cardWidth,
                        child: RoomCardMenu(
                          room: room,
                          onOpen: () => _openRoom(room, followedRooms),
                          child: RoomCard(room: room, listRow: holdsRows, onOpen: () => _openRoom(room, followedRooms)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        if (areas.isNotEmpty)
          _Section(
            title: t.vod.liveAreasTitle,
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: inset),
                itemCount: areas.length,
                separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s12),
                itemBuilder: (context, index) {
                  final area = areas[index];
                  return SizedBox(
                    width: 96,
                    child: _AreaTile(
                      area: area,
                      onOpen: () => unawaited(
                        context.push(
                          AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
                          extra: area,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // The feed's head is the module's one: the same 44 row, the card/list
          // switch the grid below already honours, and the reload — on a narrow
          // window the two controls fold into the more at the page's end.
          child: VodFeedToolbar(
            owner: NavigationItem.vodLive,
            tabs: Text(
              t.vod.liveRecommendTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTheme.of(context).typography.title.copyWith(color: DsTheme.colorsOf(context).text),
            ),
            onRefresh: controller.refresh,
          ),
        ),
        Expanded(
          child: PagedCardGrid<LiveRoom>(
            items: feed.rooms,
            layout: ref.watch(browseLayoutProvider),
            listMatchesGridWidth: true,
            listMainAxisExtent: kRoomCardListDesignHeight,
            listItemBuilder: (context, room) => RoomCardMenu(
              room: room,
              onOpen: () => _openRoom(room, feed.rooms),
              child: RoomCard(room: room, listRow: true, onOpen: () => _openRoom(room, feed.rooms)),
            ),
            crossSpacing: settings.crossSpacing,
            mainSpacing: settings.mainSpacing,
            isLoading: feed.loading,
            hasMore: feed.hasMore,
            onLoadMore: controller.loadMore,
            error: feed.error?.message,
            onRetry: controller.refresh,
            onRefresh: controller.refresh,
            refreshError: feed.error?.message,
            emptyIcon: DsIcons.tvMinimal,
            emptyTitle: t.vod.liveEmptyTitle,
            emptyDescription: t.vod.liveEmptyDescription,
            itemBuilder: (context, room) => RoomCardMenu(
              room: room,
              onOpen: () => _openRoom(room, feed.rooms),
              child: RoomCard(room: room, onOpen: () => _openRoom(room, feed.rooms)),
            ),
          ),
        ),
      ],
    );
  }
}

/// One titled strip of the live page.
final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          // The title sits at the page's own inset, not a fixed 20: on a
          // compact window everything else in this column starts 16 in, and
          // two starts down one column is the break this module keeps cutting.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: LiveWindow.pageInset(MediaQuery.sizeOf(context).width)),
            child: Text(title, style: DsTheme.of(context).typography.title.copyWith(color: colors.text)),
          ),
          child,
        ],
      ),
    );
  }
}

/// One area as the reference's mini card: the area's mark over its name.
final class _AreaTile extends StatelessWidget {
  const _AreaTile({required this.area, required this.onOpen});

  final LiveArea area;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final icon = area.iconUrl;
    final fallback = DsIcon(DsIcons.layoutGrid, size: 40, color: colors.textMuted);
    return DsCard(
      onPressed: onOpen,
      semanticLabel: area.areaName,
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: DsSpace.s6,
        children: [
          if (icon == null || icon.isEmpty)
            fallback
          else
            DsImage(image: cachedImage(icon), width: 40, height: 40, fit: BoxFit.contain, fallback: fallback),
          Text(
            area.areaName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
