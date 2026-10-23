import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart';
import 'package:pure_live/features/home/home_feed_controller.dart';
import 'package:pure_live/features/home/room_card.dart' show RoomCard, RoomCardSkeleton;
import 'package:pure_live/l10n/translations.dart';

/// The live module's home: the recommended rooms of the selected site, as
/// a masonry grid that pages in as the viewer nears its end.
///
/// A row of site icons picks whose recommendations these are — the sites
/// that are only directories (no recommendations of their own) say so in
/// the feed's place instead of failing silently.
final class HomePage extends ConsumerStatefulWidget {
  /// The live home page.
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // The feed never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(homeFeedProvider.notifier).reload());
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider);
    final sites = ref.watch(sitesProvider).all;
    final selectedId = ref.watch(selectedSiteIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _SitePickerRow(sites: sites, selectedId: selectedId),
        ),
        Expanded(child: _FeedGrid(feed: feed)),
      ],
    );
  }
}

/// The row of site icons above the feed: every site the registry holds,
/// its platform icon; the selected one carries the theme's selection.
final class _SitePickerRow extends ConsumerWidget {
  const _SitePickerRow({required this.sites, required this.selectedId});

  final List<LiveSite> sites;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return SizedBox(
      height: theme.sizes.md,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final site in sites) ...[
            const SizedBox(width: DsSpace.s6),
            DsTooltip(
              message: site.manifest.name['zh-CN'] ?? site.manifest.id,
              side: DsSide.bottom,
              child: DsPressable(
                semanticLabel: site.manifest.name['zh-CN'] ?? site.manifest.id,
                onPressed: () => ref.read(selectedSiteIdProvider.notifier).selected = site.manifest.id,
                builder: (context, states, _) {
                  final selected = site.manifest.id == selectedId;
                  final hovered = states.contains(WidgetState.hovered);
                  return Container(
                    width: theme.sizes.md,
                    height: theme.sizes.md,
                    decoration: DsBoxDecoration(
                      color: selected ? theme.selectedFill : hovered ? colors.hover : colors.control,
                      borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
                      shadows: selected ? const <DsShadow>[] : [DsShadow.innerRing(colors.border)],
                    ),
                    child: Center(child: _SiteIcon(site: site)),
                  );
                },
              ),
            ),
          ],
          const SizedBox(width: DsSpace.s6),
        ],
      ),
    );
  }
}

/// A site's icon: the bundled platform picture when the manifest names
/// one, the first letter of its name otherwise.
final class _SiteIcon extends StatelessWidget {
  const _SiteIcon({required this.site});

  final LiveSite site;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final icon = site.manifest.icon;
    if (icon?.type == LiveAssetType.bundled && (icon?.path ?? '').isNotEmpty) {
      return Image.asset(
        'packages/live_sites/${icon!.path}',
        width: theme.sizes.iconSm,
        height: theme.sizes.iconSm,
        errorBuilder: (_, _, _) => _letter(context, colors),
      );
    }
    return _letter(context, colors);
  }

  Widget _letter(BuildContext context, DsColors colors) {
    final theme = DsTheme.of(context);
    final name = site.manifest.name['zh-CN'] ?? site.manifest.id;
    final first = name.isEmpty ? '?' : name.substring(0, 1);
    return Text(
      first.toUpperCase(),
      style: theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w700),
    );
  }
}

/// The feed's grid: skeletons while the first page loads, the rooms as
/// cards page by page, an honest error or empty state in their place. The
/// mosaic grid pages itself — its footer is the loading row's home.
final class _FeedGrid extends ConsumerWidget {
  const _FeedGrid({required this.feed});

  final HomeFeedState feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(homeFeedProvider.notifier);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    if (feed.rooms.isEmpty && feed.loading) {
      return _SkeletonFeed(cardExtent: cardExtent);
    }
    if (feed.rooms.isEmpty && feed.error != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(context.t.common.empty),
          description: Text(feed.error!.message),
          actions: [DsButton(onPressed: controller.reload, child: Text(context.t.common.retry))],
        ),
      );
    }
    if (feed.rooms.isEmpty) {
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(context.t.common.empty)));
    }
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      itemCount: feed.rooms.length,
      itemBuilder: (context, index) => RoomCard(room: feed.rooms[index]),
      footer:
          feed.loading
              ? const Padding(padding: EdgeInsets.all(DsSpace.s16), child: Center(child: RoomCardSkeleton()))
              : null,
      onEndReached: feed.hasMore ? () => unawaited(controller.loadMore()) : null,
    );
  }
}

/// The feed's first-page placeholder: the same grid shape, no content.
final class _SkeletonFeed extends StatelessWidget {
  const _SkeletonFeed({required this.cardExtent});

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
