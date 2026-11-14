import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/room/player/room_playlist.dart' show roomPlaylistProvider;
import 'package:pure_live/modules/live/search/search_controller.dart';
import 'package:pure_live/shared/shared.dart';

/// The switcher's three sources: the followed rooms on air, the list this
/// room was opened from (hot, an area, …), and a search across every enabled
/// platform. The source group only appears when the room came from a list.
enum RoomSwitchGroup { follows, source, search }

/// The portrait fullscreen's swipe list: followed rooms on air, or the
/// history when none is on. The current room stays in the list so its
/// neighbours can be found; an absent current room starts from the
/// first/last.
List<LiveRoom> roomSwipeList({
  required List<LiveRoom> follows,
  required List<LiveRoom> history,
  required LiveRoom current,
}) {
  final onAir = [
    for (final room in follows)
      if (room.broadcast.isLiveNow) room,
  ];
  final watched = [for (final room in history) room];
  if (onAir.any((room) => room.ref.identityKey == current.ref.identityKey)) return onAir;
  if (watched.any((room) => room.ref.identityKey == current.ref.identityKey)) return watched;
  return onAir.isNotEmpty ? onAir : watched;
}

/// Opens the room switcher over [current]: the followed rooms on air, the
/// source list the room was opened from, and a search across every enabled
/// platform. A pick replaces the room page, so going back does not return to
/// the old room.
Future<void> showRoomSwitcher(BuildContext context, {required LiveRoom current}) => showAppDialog<void>(
  context: context,
  builder: (context) => _RoomSwitcherDialog(current: current),
);

final class _RoomSwitcherDialog extends ConsumerStatefulWidget {
  const _RoomSwitcherDialog({required this.current});

  final LiveRoom current;

  @override
  ConsumerState<_RoomSwitcherDialog> createState() => _RoomSwitcherDialogState();
}

final class _RoomSwitcherDialogState extends ConsumerState<_RoomSwitcherDialog> {
  RoomSwitchGroup? _group;
  late final TextEditingController _field = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // The search runs across every enabled platform at once: a word typed here
  // is a room to find, not a platform to browse.
  void _runSearch(String word) {
    final query = word.trim();
    if (query.isEmpty) return;
    ref.read(searchSiteIdProvider.notifier).selected = kSearchAllPlatforms;
    unawaited(ref.read(searchProvider.notifier).search(query));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final follows = ref.watch(followsProvider).rooms;
    final playlist = ref.watch(roomPlaylistProvider);
    bool other(LiveRoom room) => room.ref.identityKey != widget.current.ref.identityKey;
    final followsList = [
      for (final room in follows)
        if (room.broadcast.isLiveNow && other(room)) room,
    ];
    final sourceList = [
      for (final room in playlist?.rooms ?? const <LiveRoom>[])
        if (other(room)) room,
    ];
    final groups = [RoomSwitchGroup.follows, if (sourceList.isNotEmpty) RoomSwitchGroup.source, RoomSwitchGroup.search];
    final group = _group != null && groups.contains(_group) ? _group! : groups.first;
    final layout = ref.watch(roomSwitcherLayoutProvider);
    final search = ref.watch(searchProvider);
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = math.max(280, math.min(720, screen.width - 32)).toDouble();
    final dialogHeight = math.max(260, math.min(480, screen.height - 160)).toDouble();
    final counts = {RoomSwitchGroup.follows: followsList.length, RoomSwitchGroup.source: sourceList.length};
    String label(RoomSwitchGroup value) => switch (value) {
      RoomSwitchGroup.follows => t.room.switchOnAir,
      RoomSwitchGroup.source => t.room.switchSource,
      RoomSwitchGroup.search => t.room.switchSearch,
    };

    final listRooms = switch (group) {
      RoomSwitchGroup.follows => followsList,
      RoomSwitchGroup.source => sourceList,
      RoomSwitchGroup.search => const <LiveRoom>[],
    };
    Widget body() {
      if (group == RoomSwitchGroup.search) {
        return PagedCardGrid<LiveRoom>(
          scrollController: _scroll,
          items: search.rooms,
          hasMore: search.hasMore,
          isLoading: search.loading,
          onLoadMore: ref.read(searchProvider.notifier).loadMore,
          layout: CardLayout.list,
          listMatchesGridWidth: true,
          listMainAxisExtent: kRoomCardListDesignHeight,
          listItemBuilder: (context, room) => _SwitcherRow(room: room, onPressed: () => _open(room)),
          crossSpacing: DsSpace.s8,
          mainSpacing: DsSpace.s8,
          padding: const EdgeInsets.all(DsSpace.s4),
          error: search.error?.message,
          onRetry: () => unawaited(ref.read(searchProvider.notifier).retry()),
          emptyIcon: DsIcons.searchX,
          emptyTitle: t.search.noResultsTitle,
          itemBuilder: (context, room) => _SwitcherCard(room: room, onPressed: () => _open(room)),
        );
      }
      if (listRooms.isEmpty) {
        return Center(
          child: Text(t.room.switchEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
        );
      }
      return layout == RoomSwitcherLayout.grid
          ? GridView.builder(
              padding: const EdgeInsets.all(DsSpace.s4),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 224,
                mainAxisExtent: 164,
                crossAxisSpacing: DsSpace.s8,
                mainAxisSpacing: DsSpace.s8,
              ),
              itemCount: listRooms.length,
              itemBuilder: (context, index) =>
                  _SwitcherCard(room: listRooms[index], onPressed: () => _open(listRooms[index])),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(DsSpace.s4),
              itemCount: listRooms.length,
              separatorBuilder: (_, _) => DsLine(color: colors.border),
              itemBuilder: (context, index) =>
                  _SwitcherRow(room: listRooms[index], onPressed: () => _open(listRooms[index])),
            );
    }

    return AppDialog(
      title: Text(t.room.switchRoom),
      description: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            Row(
              children: [
                Expanded(
                  child: DsChoiceChips<RoomSwitchGroup>(
                    value: group,
                    semanticLabel: t.room.switchRoom,
                    options: [
                      for (final value in groups)
                        DsChipOption(
                          value: value,
                          label: Text(counts.containsKey(value) ? '${label(value)} ${counts[value]}' : label(value)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _group = value),
                  ),
                ),
                if (group != RoomSwitchGroup.search) ...[
                  const SizedBox(width: DsSpace.s8),
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: layout == RoomSwitcherLayout.grid ? t.room.switchShowList : t.room.switchShowGrid,
                    onPressed: () => unawaited(
                      ref
                          .read(roomSwitcherLayoutProvider.notifier)
                          .set(layout == RoomSwitcherLayout.grid ? RoomSwitcherLayout.list : RoomSwitcherLayout.grid),
                    ),
                    icon: DsIcon(layout == RoomSwitcherLayout.grid ? DsIcons.list : DsIcons.layoutGrid, size: 16),
                  ),
                ],
              ],
            ),
            if (group == RoomSwitchGroup.search)
              DsSearchField(
                controller: _field,
                autofocus: true,
                placeholder: t.common.searchHint,
                onSubmitted: _runSearch,
              ),
            Expanded(child: body()),
          ],
        ),
      ),
      style: DsDialogStyle(width: dialogWidth + 40),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }

  void _open(LiveRoom room) {
    final router = ref.read(appRouterProvider);
    Navigator.of(context).pop();
    unawaited(
      router.pushReplacement(
        RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location,
        extra: room,
      ),
    );
  }
}

final class _SwitcherCard extends ConsumerWidget {
  const _SwitcherCard({required this.room, required this.onPressed});

  final LiveRoom room;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final site = ref.watch(sitesProvider).getById(room.ref.platform);
    final platform = site == null ? room.ref.platform : localizedSiteName(site);
    final cover = room.content.coverUrl.trim();
    return DsCard(
      onPressed: onPressed,
      style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
              child: cover.isEmpty
                  ? ColoredBox(color: colors.control)
                  : LayoutBuilder(
                      builder: (context, constraints) => DsImage(
                        image: cachedImage(cover, policy: ImageCachePolicies.liveRoomCover),
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  room.content.title.trim().isEmpty ? room.ref.roomId : room.content.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.text),
                ),
                Text(
                  room.broadcast.isLiveNow ? '$platform · ${context.t.room.switchLive}' : platform,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _SwitcherRow extends ConsumerWidget {
  const _SwitcherRow({required this.room, required this.onPressed});

  final LiveRoom room;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final site = ref.watch(sitesProvider).getById(room.ref.platform);
    final platform = site == null ? room.ref.platform : localizedSiteName(site);
    final cover = room.content.coverUrl.trim();
    return DsListRow(
      onPressed: onPressed,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 112,
          height: 63,
          child: cover.isEmpty
              ? ColoredBox(color: colors.control)
              : DsImage(image: cachedImage(cover, policy: ImageCachePolicies.liveRoomCover), width: 112, height: 63),
        ),
      ),
      title: Text(
        room.content.title.trim().isEmpty ? room.ref.roomId : room.content.title.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      description: Text(
        room.broadcast.isLiveNow ? '$platform · ${context.t.room.switchLive}' : platform,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
