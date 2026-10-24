import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/areas/area_follow_repository.dart';
import 'package:pure_live/features/areas/area_rooms_controller.dart';
import 'package:pure_live/features/home/room_card.dart' show RoomCard;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final area = widget.area;
      if (area == null) return; // A deep link without the object cannot load.
      unawaited(
        ref.read(areaRoomsProvider.notifier).init(site: ref.read(selectedSiteProvider), area: area),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(areaRoomsProvider);
    final colors = DsTheme.colorsOf(context);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final title = state?.area.areaName ?? widget.areaId;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        // The area follow sits beside the title, like the reference's
        // FollowAreaButton: the followed-areas view and this page share it.
        actions: [
          if (state != null) _AreaFollowButton(area: state.area),
          const SizedBox(width: DsSpace.s8),
        ],
      ),
      body: state == null
          ? Center(child: DsEmptyState(icon: const DsIcon(DsIcons.tag), title: Text(title)))
          : CardGrid<LiveRoom>(
              items: state.rooms,
              cardExtent: cardExtent,
              isLoading: state.loading,
              hasMore: state.hasMore,
              onLoadMore: ref.read(areaRoomsProvider.notifier).loadMore,
              error: state.error?.message,
              onRetry: ref.read(areaRoomsProvider.notifier).reload,
              itemBuilder: (context, room) => RoomCard(
                room: room,
                onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
              ),
            ),
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
      icon: DsIcon(
        DsIcons.heart,
        size: 20,
        color: isFollowed ? colors.danger.fill : colors.textMuted,
      ),
    );
  }
}
