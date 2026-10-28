import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart' show kRoomCardListDesignHeight;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart' show followsProvider;
import 'package:pure_live/modules/live/popular/popular.dart' show RoomCard;
import 'package:pure_live/modules/vod/controller/vod_live.dart';
import 'package:pure_live/shared/shared.dart';

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
    unawaited(openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: playlist));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
            child: SizedBox(
              height: kRoomCardListDesignHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
                itemCount: followedRooms.length,
                separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s12),
                itemBuilder: (context, index) {
                  final room = followedRooms[index];
                  return SizedBox(
                    width: 320,
                    child: RoomCard(room: room, listRow: true, onOpen: () => _openRoom(room, followedRooms)),
                  );
                },
              ),
            ),
          ),
        if (areas.isNotEmpty)
          _Section(
            title: t.vod.liveAreasTitle,
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
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
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.vod.liveRecommendTitle,
                  style: DsTheme.of(context).typography.title.copyWith(color: DsTheme.colorsOf(context).text),
                ),
              ),
              ChromeIconButton(
                icon: DsIcons.refresh,
                semanticLabel: t.vod.refresh,
                tooltip: t.vod.refresh,
                onPressed: () => unawaited(controller.refresh()),
                size: 36,
              ),
            ],
          ),
        ),
        Expanded(
          child: CardGrid<LiveRoom>(
            items: feed.rooms,
            layout: ref.watch(browseLayoutProvider),
            listMainAxisExtent: kRoomCardListDesignHeight,
            listItemBuilder: (context, room) =>
                RoomCard(room: room, listRow: true, onOpen: () => _openRoom(room, feed.rooms)),
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
            itemBuilder: (context, room) => RoomCard(room: room, onOpen: () => _openRoom(room, feed.rooms)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
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
