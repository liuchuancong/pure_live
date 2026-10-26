import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/background/app_background.dart' show BackgroundActiveScope;
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteProvider;
import 'package:pure_live/features/areas/area_follow_repository.dart';
import 'package:pure_live/features/areas/area_rooms_controller.dart';
import 'package:pure_live/features/popular/room_card.dart' show RoomCard;
import 'package:pure_live/features/settings/room_card_settings.dart' show RoomCardLayout, roomCardAppearanceProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/grids/layout_toggle.dart' show LayoutToggle;
import 'package:pure_live/shared/navigation/room_opener.dart';
import 'package:pure_live/shared/paging/room_paging.dart';
import 'package:pure_live/shared/rooms/room_visibility.dart' show showUnplayableProvider;

/// One area's rooms (the reference's `kAreaRooms`): its own page under the
/// areas grid, on the root navigator on both desktop and mobile — back
/// returns to the grid wherever it was opened from.
///
/// The site comes from the shell's selection (the areas page only offers
/// areas of the selected site); the area rides in as the push's extra.
final class AreaRoomsPage extends ConsumerStatefulWidget {
  /// The rooms of [areaId], opened with the [area] itself when the route
  /// carried it.
  const AreaRoomsPage({required this.platform, required this.areaId, this.area, super.key});

  /// The area's platform id, for the title when the object is missing.
  final String platform;

  /// The area's id.
  final String areaId;

  /// The area object, when the route was opened in-app.
  final LiveArea? area;

  @override
  ConsumerState<AreaRoomsPage> createState() => _AreaRoomsPageState();
}

final class _AreaRoomsPageState extends ConsumerState<AreaRoomsPage> {
  /// The grid's scroll position across page changes and layout switches.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final area = widget.area;
      if (area == null) return; // A deep link without the object cannot load.
      unawaited(ref.read(areaRoomsProvider.notifier).init(site: ref.read(selectedSiteProvider), area: area));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(areaRoomsProvider);
    final colors = DsTheme.colorsOf(context);
    final wallpaper = BackgroundActiveScope.isActiveOf(context);
    final settings = ref.watch(browseSettingsProvider);
    final title = state?.area.areaName ?? widget.areaId;
    final controller = ref.read(areaRoomsProvider.notifier);
    // The display page size is the viewer's; the platform is asked in its
    // own window and the catalogue is sliced locally (see the controller).
    ref.listen(browseSettingsProvider.select((s) => s.homePageSize), (previous, next) {
      if (previous != next && state != null) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
        unawaited(controller.resize(next));
      }
    });
    if (state != null && state.pageSize != settings.homePageSize && !state.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(controller.resize(settings.homePageSize));
      });
    }
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final showUnplayable = ref.watch(showUnplayableProvider);

    // The reference's hidden-count line under the rooms: what the discovery
    // filter keeps out is counted, not dropped silently, and one action
    // turns the setting over so they show.
    Widget withHiddenNote(AreaRoomsState open, Widget content) {
      if (open.hidden <= 0 || showUnplayable) return content;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: content),
          Padding(
            padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, wide ? DsSpace.s4 : DsSpace.s20),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                DsIcon(DsIcons.circleAlert, size: 16, color: colors.textMuted),
                Expanded(
                  child: Text(
                    context.t.areas.hiddenUnplayable(count: open.hidden),
                    style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => ref.read(showUnplayableProvider.notifier).setShow(value: true),
                  child: Text(context.t.common.show),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget grid(AreaRoomsState open, List<LiveRoom> rooms, {required bool endless}) => CardGrid<LiveRoom>(
      scrollController: _scroll,
      items: rooms,
      layout: ref.watch(browseLayoutProvider),
      aspectRatio: ref.watch(roomCardAppearanceProvider).layout == RoomCardLayout.compact
          ? CardGrid.roomCardCompactAspectRatio
          : CardGrid.roomCardAspectRatio,
      listItemBuilder: (context, room) => RoomCard(
        room: room,
        compact: true,
        onOpen: () => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: rooms),
      ),
      cardExtent: settings.homeCardExtent,
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: open.loading,
      // A desktop page holds exactly one slice; its pager fetches the next.
      hasMore: endless && open.hasMore,
      onLoadMore: endless ? controller.loadMore : null,
      error: open.error?.message,
      onRetry: controller.reload,
      // A pull reloads the first page; a failure keeps the rooms and is
      // explained in the bar over them.
      onRefresh: controller.reload,
      refreshError: open.error?.message,
      itemBuilder: (context, room) => RoomCard(
        room: room,
        onOpen: () => openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId, playlist: rooms),
      ),
    );

    final Widget body;
    if (state == null) {
      body = Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.tag), title: Text(title)),
      );
    } else if (!wide) {
      body = withHiddenNote(state, grid(state, state.rooms, endless: true));
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: withHiddenNote(
              state,
              grid(state, roomPageOf(state.rooms, state.page, state.pageSize), endless: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s8,
                children: [
                  if (state.loading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
                  DsPagination(
                    page: state.page,
                    pageCount: roomPageCount(
                      page: state.page,
                      roomCount: state.rooms.length,
                      pageSize: state.pageSize,
                      hasMore: state.hasMore,
                    ),
                    onChanged: state.loading
                        ? null
                        : (next) {
                            // A new page starts at its head, as desktop pagers do.
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                            unawaited(controller.loadPage(next));
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: wallpaper ? const Color(0x00000000) : colors.surface,
      appBar: AppBar(
        backgroundColor: wallpaper ? colors.surface.withValues(alpha: 0.82) : colors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        // The area follow sits beside the title, like the reference's
        // FollowAreaButton: the followed-areas view and this page share it.
        actions: [
          if (state != null) _AreaFollowButton(area: state.area),
          const SizedBox(width: DsSpace.s8),
          const Center(child: LayoutToggle()),
          const SizedBox(width: DsSpace.s8),
        ],
      ),
      body: body,
    );
  }
}

/// The heart beside the rooms page's title: filled when the area is
/// followed, hollow when not; pressing toggles it.
final class _AreaFollowButton extends ConsumerWidget {
  const _AreaFollowButton({required this.area});

  final LiveArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedAreasProvider);
    final isFollowed = followed.ready && followed.areas.any((item) => item.identityKey == area.identityKey);
    final colors = DsTheme.colorsOf(context);
    return IconButton(
      tooltip: isFollowed ? context.t.areas.unfollow : context.t.areas.viewFollowed,
      onPressed: () async {
        final repository = ref.read(areaFollowRepositoryProvider).value;
        if (repository != null) await repository.toggle(area);
      },
      icon: DsIcon(DsIcons.heart, size: 20, color: isFollowed ? colors.danger.fill : colors.textMuted),
    );
  }
}
