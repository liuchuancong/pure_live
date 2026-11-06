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
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/shared/shared.dart';

/// The followed shelf's row card, and the pair of them plus the gap a column
/// needs before the shelf keeps that form: narrower than this the rail shows
/// one room and a sliver of the next.
const double _kFollowRowCardWidth = 320;

/// The narrowest the shelf's cover card gets, so a 300px window still reads a
/// title instead of two halves too cramped to use.
const double _kFollowCardMinWidth = 150;

/// The reference's 直播 rail entry: the site's areas in the head's tab row,
/// the followed rooms as the content's first section, and Bilibili's
/// recommended live feed under them, pages of it as the grid is read.
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

  /// Opens an area's room list: where the head's area tabs all land, the
  /// page they leave still being the recommendation.
  void _openArea(LiveArea area) => unawaited(
    context.push(
      AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location,
      extra: area,
    ),
  );

  /// The head's tab row: 推荐 first, the site's areas after it — the
  /// reference's folding of the area strip into the 44 row. The bar stays
  /// controlled on 推荐, so an area's press opens that area's rooms while the
  /// feed under the head remains the recommendation it was: the selection
  /// never moves, and with the directory ask failed the row is the one tab
  /// it honestly has.
  Widget _feedTabs(Translations t, List<LiveArea> areas) => DsTabs<LiveArea?>(
    value: null,
    onChanged: (area) {
      if (area != null) _openArea(area);
    },
    semanticLabel: t.vod.liveAreasTitle,
    style: kVodFeedTabsStyle,
    tabs: [
      DsTab<LiveArea?>(value: null, label: Text(t.vod.liveRecommendTitle)),
      for (final area in areas) DsTab<LiveArea?>(value: area, label: Text(area.areaName)),
    ],
  );

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
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          // The feed's head is the module's one: the same 44 row, now wearing
          // the areas as tabs beside 推荐 where the reference puts them, the
          // card/list switch the grid below honours, and the reload — on a
          // narrow window the two controls fold into the more at the page's
          // end.
          child: VodFeedToolbar(
            owner: NavigationItem.vodLive,
            tabs: _feedTabs(t, areas),
            onRefresh: controller.refresh,
          ),
        ),
        if (followedRooms.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
            // The shelf's own head: the station's mark, its words, and the
            // way out to the followed list the rail owns.
            child: _SectionHeader(
              mark: const _SiteMark(),
              title: t.vod.liveFollowTitle,
              action: DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => unawaited(context.push(const FavoritesRoute().location)),
                trailing: const DsIcon(DsIcons.chevronRight, size: 14),
                child: Text(t.vod.liveFollowViewAll),
              ),
            ),
          ),
          LayoutBuilder(
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
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
          // The grid's own section head, the reference's words over its feed:
          // the tab above names the choice 推荐, this head names what stands
          // under it.
          child: _SectionHeader(title: t.vod.liveRecommendTitle),
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

/// One section's head row: an optional mark, the section's words, and the
/// section's own way out at the row's end.
final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.mark, this.action});

  /// The section's words.
  final String title;

  /// The mark the words open with, when the section carries one.
  final Widget? mark;

  /// The section's way out, at the row's end.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s6,
      children: [
        ?mark,
        Text(title, style: DsTheme.of(context).typography.title.copyWith(color: colors.text)),
        if (action != null) const Spacer(),
        ?action,
      ],
    );
  }
}

/// The station's mark the followed shelf's head opens with: the one accent
/// square the reference's section rows carry.
final class _SiteMark extends StatelessWidget {
  const _SiteMark();

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Container(
      width: DsSpace.s4,
      height: DsSpace.s4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(theme.radii.control(DsSpace.s4)),
      ),
      child: Text(
        'B',
        style: theme.typography.caption.copyWith(color: colors.onAccent, fontWeight: FontWeight.w700),
      ),
    );
  }
}
