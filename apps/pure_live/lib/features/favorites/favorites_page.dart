import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/favorites/follow_repository.dart';
import 'package:pure_live/features/home/room_card.dart' show RoomCard, RoomCardSkeleton;
import 'package:pure_live/l10n/translations.dart';

/// The live module's favorites: the followed rooms as the home feed's own
/// card grid, an unfollow button on each card's cover, an honest empty
/// state while nothing is followed.
///
/// The list follows the repository's watch stream, so a follow made
/// anywhere (the room page's button, when it arrives) lands here at once.
final class FavoritesPage extends ConsumerWidget {
  /// The favorites page.
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(followsProvider);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    if (!follows.ready) {
      return _SkeletonFeed(cardExtent: cardExtent);
    }
    if (follows.rooms.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.heart),
          title: Text(context.t.favorites.emptyTitle),
          description: Text(context.t.favorites.emptyDescription),
        ),
      );
    }
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      itemCount: follows.rooms.length,
      itemBuilder: (context, index) {
        final room = follows.rooms[index];
        return _FollowedCard(
          room: room,
          onUnfollow: () => unawaited(ref.read(followsProvider.notifier).remove(room.ref.identityKey)),
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
        RoomCard(room: room, onOpen: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location)),
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
                child: Center(child: DsIcon(DsIcons.heart, size: theme.sizes.iconSm, color: colors.text)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The feed's opening placeholder: the same grid shape, no content.
final class _SkeletonFeed extends StatelessWidget {
  const _SkeletonFeed({required this.cardExtent});

  final double cardExtent;

  @override
  Widget build(BuildContext context) {
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      children: [for (var i = 0; i < 8; i++) const RoomCardSkeleton()],
    );
  }
}
