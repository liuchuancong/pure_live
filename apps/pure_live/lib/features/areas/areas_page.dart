import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/areas/areas_controller.dart';
import 'package:pure_live/features/home/room_card.dart' show RoomCard, RoomCardSkeleton;
import 'package:pure_live/l10n/translations.dart';

/// The live module's areas page: the selected site's areas as a grid of
/// cards; open one and its rooms take the page under a breadcrumb that
/// leads back to the whole grid.
///
/// A site without the area capability (or with no areas of its own) says so
/// in the grid's place instead of failing silently.
final class AreasPage extends ConsumerStatefulWidget {
  /// The areas page.
  const AreasPage({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

final class _AreasPageState extends ConsumerState<AreasPage> {
  @override
  void initState() {
    super.initState();
    // The grid never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(areasProvider.notifier).loadAreas());
    });
    // A site switch resets the controller; the page asks again, so the new
    // site's areas arrive however the switch was made.
    ref.listenManual(selectedSiteIdProvider, (_, _) {
      unawaited(ref.read(areasProvider.notifier).loadAreas());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(areasProvider);
    final area = state.selectedArea;
    if (area == null) return _AreasGrid(state: state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Align(alignment: AlignmentDirectional.centerStart, child: _AreaBreadcrumb(areaName: area.areaName)),
        ),
        Expanded(child: _AreaRoomsGrid(state: state)),
      ],
    );
  }
}

/// The open area's path: the whole grid behind it, the area as the current
/// page. Pressing the first level returns to the grid.
final class _AreaBreadcrumb extends ConsumerWidget {
  const _AreaBreadcrumb({required this.areaName});

  /// The open area's display name.
  final String areaName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DsBreadcrumb(
      items: [
        DsBreadcrumbItem(
          label: context.t.areas.allAreas,
          icon: const DsIcon(DsIcons.layoutGrid),
          onPressed: () => ref.read(areasProvider.notifier).backToAllAreas(),
        ),
        DsBreadcrumbItem(label: areaName),
      ],
    );
  }
}

/// The areas grid: skeletons while the areas load, an area card per
/// entry, an honest error or no-areas state in their place.
final class _AreasGrid extends ConsumerWidget {
  const _AreasGrid({required this.state});

  /// The page's state; only its areas half is read here.
  final AreasState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(areasProvider.notifier);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    if (state.areas.isEmpty && state.areasLoading) {
      return _SkeletonAreas(cardExtent: cardExtent);
    }
    if (state.areas.isEmpty && state.areasError != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(context.t.common.empty),
          description: Text(state.areasError!.message),
          actions: [DsButton(onPressed: controller.loadAreas, child: Text(context.t.common.retry))],
        ),
      );
    }
    if (state.areas.isEmpty) {
      // A site without the area capability lands here too: not a failure,
      // just nothing to browse by.
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.layoutGrid), title: Text(context.t.areas.noAreas)));
    }
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      itemCount: state.areas.length,
      itemBuilder: (context, index) => _AreaCard(
        area: state.areas[index],
        onSelect: () => unawaited(controller.selectArea(state.areas[index])),
      ),
    );
  }
}

/// One area as a card: its picture, its name, and the parent group it sits
/// in when the platform nests areas. Opening the area is [onSelect].
final class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onSelect});

  /// The area shown.
  final LiveArea area;

  /// Fired when the card opens the area.
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final parent = area.parentAreaName;
    return DsPressable(
      semanticLabel: area.areaName,
      onPressed: onSelect,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.control,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : const <DsShadow>[],
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              _AreaIcon(area: area),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      area.areaName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    if (parent != null && parent.isNotEmpty)
                      Text(
                        parent,
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
      },
    );
  }
}

/// The area's picture: the platform's icon when it names one, a tag glyph
/// over the channel fill otherwise.
final class _AreaIcon extends StatelessWidget {
  const _AreaIcon({required this.area});

  /// The area whose icon is shown.
  final LiveArea area;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final fallback = ColoredBox(
      color: colors.channel,
      child: Center(child: DsIcon(DsIcons.tag, size: theme.sizes.iconMd, color: colors.textMuted)),
    );
    final url = area.iconUrl;
    if (url == null || url.isEmpty) {
      return SizedBox(width: theme.sizes.md, height: theme.sizes.md, child: fallback);
    }
    return DsImage.network(
      url,
      width: theme.sizes.md,
      height: theme.sizes.md,
      semanticLabel: area.areaName,
      fallback: fallback,
    );
  }
}

/// The areas grid's first-load placeholder: the same grid shape, no
/// content.
final class _SkeletonAreas extends StatelessWidget {
  const _SkeletonAreas({required this.cardExtent});

  /// The widest a card gets; the same setting the real grid reads.
  final double cardExtent;

  @override
  Widget build(BuildContext context) {
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      children: [for (var i = 0; i < 12; i++) const _AreaCardSkeleton()],
    );
  }
}

/// The area card's placeholder while its grid loads: the same shape, no
/// content.
final class _AreaCardSkeleton extends StatelessWidget {
  const _AreaCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s12),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsSkeleton.circle(size: theme.sizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [DsSkeleton(width: DsSpace.s32), DsSkeleton(width: DsSpace.s20)],
            ),
          ),
        ],
      ),
    );
  }
}

/// The open area's room feed: the same shape as the home feed — the rooms
/// as cards page by page, an honest error or empty state in their place.
/// The mosaic grid pages itself; its footer is the loading row's home.
final class _AreaRoomsGrid extends ConsumerWidget {
  const _AreaRoomsGrid({required this.state});

  /// The page's state; only its rooms half is read here.
  final AreasState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(areasProvider.notifier);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    if (state.rooms.isEmpty && state.roomsLoading) {
      return _SkeletonRooms(cardExtent: cardExtent);
    }
    if (state.rooms.isEmpty && state.roomsError != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(context.t.common.empty),
          description: Text(state.roomsError!.message),
          actions: [DsButton(onPressed: controller.reloadRooms, child: Text(context.t.common.retry))],
        ),
      );
    }
    if (state.rooms.isEmpty) {
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(context.t.common.empty)));
    }
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      itemCount: state.rooms.length,
      itemBuilder: (context, index) => RoomCard(room: state.rooms[index], onOpen: () => context.push(RoomRoute(platform: state.rooms[index].ref.platform, roomId: state.rooms[index].ref.roomId).location)),
      footer:
          state.roomsLoading
              ? const Padding(padding: EdgeInsets.all(DsSpace.s16), child: Center(child: RoomCardSkeleton()))
              : null,
      onEndReached: state.hasMore ? () => unawaited(controller.loadMoreRooms()) : null,
    );
  }
}

/// The room feed's first-page placeholder: the same grid shape, no
/// content.
final class _SkeletonRooms extends StatelessWidget {
  const _SkeletonRooms({required this.cardExtent});

  /// The widest a card gets; the same setting the real grid reads.
  final double cardExtent;

  @override
  Widget build(BuildContext context) {
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      children: [for (var i = 0; i < 12; i++) const RoomCardSkeleton()],
    );
  }
}
