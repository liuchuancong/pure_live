import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show AreaRoomsRoute;
import 'package:pure_live/features/areas/area_follow_repository.dart';
import 'package:pure_live/features/areas/areas_controller.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/platforms/platform_picker.dart';

/// The areas page (the reference's `AreasPage`): the platforms' own
/// catalogues — one tab per platform, each loaded when its tab first
/// shows and kept while the app runs — beside the followed areas, the
/// segmented control switching between the two views.
final class AreasPage extends ConsumerStatefulWidget {
  /// The areas page.
  const AreasPage({super.key});

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

/// The two views the segmented control switches between.
enum _AreasView { platform, followed }

final class _AreasPageState extends ConsumerState<AreasPage> {
  _AreasView _view = _AreasView.platform;

  /// One scroll controller per platform (the catalogue grid keeps each
  /// platform's place across tab switches); released with the page.
  final Map<String, ScrollController> _scrolls = {};

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  ScrollController _scrollOf(String platform) => _scrolls[platform] ??= ScrollController();

  @override
  void initState() {
    super.initState();
    // The catalogue never loads from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(areasCatalogProvider.notifier).open(ref.read(areasSiteProvider)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final platform = ref.watch(areasSiteProvider);
    final ids = ref.watch(areasCatalogProvider.notifier).platformIds();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          // A wrap, not a row: the two views and the platform tabs keep
          // their own widths, and a narrow window flows them.
          child: Wrap(
            spacing: DsSpace.s12,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DsSegmentedControl<_AreasView>(
                segments: [
                  DsSegment(value: _AreasView.platform, label: Text(t.areas.viewPlatform)),
                  DsSegment(value: _AreasView.followed, label: Text(t.areas.viewFollowed)),
                ],
                value: _view,
                onChanged: (view) => setState(() => _view = view),
              ),
              if (_view == _AreasView.platform && ids.isNotEmpty)
                SizedBox(
                  width: 260,
                  child: PlatformTabRow(
                    platforms: ids,
                    current: platform,
                    nameOf: _platformName,
                    semanticLabel: t.areas.allAreas,
                    onChanged: (id) {
                      ref.read(areasSiteProvider.notifier).selected = id;
                      unawaited(ref.read(areasCatalogProvider.notifier).open(id));
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _view == _AreasView.platform
              ? (ids.isEmpty
                  ? Center(child: DsEmptyState(icon: const DsIcon(DsIcons.antenna), title: Text(t.areas.noPlatforms)))
                  : _PlatformAreas(
                      key: ValueKey('areas-$platform'),
                      platform: platform,
                      scrollController: _scrollOf(platform),
                    ))
              : const _FollowedAreas(),
        ),
      ],
    );
  }

  String _platformName(String id) {
    final site = ref.watch(sitesProvider).getById(id);
    return site?.manifest.name['zh-CN'] ?? id;
  }
}

/// One platform's areas catalogue as the card grid.
final class _PlatformAreas extends ConsumerWidget {
  const _PlatformAreas({required this.platform, this.scrollController, super.key});

  /// The platform whose areas show.
  final String platform;

  /// The kept controller of this platform's tab.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(areasCatalogProvider.notifier);
    final catalog = ref.watch(areasCatalogProvider.select((map) => map[platform]));
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final state = catalog ?? (areas: const <LiveArea>[], loading: false, error: null);
    return CardGrid<LiveArea>(
      scrollController: scrollController,
      items: state.areas,
      cardExtent: cardExtent,
      aspectRatio: 3.4,
      isLoading: state.loading,
      error: state.error?.message,
      onRetry: () => controller.refresh(platform),
      emptyIcon: DsIcons.layoutGrid,
      emptyTitle: context.t.areas.noAreas,
      itemBuilder: (context, area) => _AreaCard(
        area: area,
        onSelect: () => unawaited(
          context.push(AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location, extra: area),
        ),
      ),
    );
  }
}

/// The followed areas: the areas the viewer follows, the platform they
/// belong to named under each one; pressing the heart unfollows.
final class _FollowedAreas extends ConsumerWidget {
  const _FollowedAreas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final followed = ref.watch(followedAreasProvider);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    if (!followed.ready) {
      return CardGrid<LiveArea>(
        items: const [],
        cardExtent: cardExtent,
        aspectRatio: 3.4,
        isLoading: true,
        itemBuilder: (_, _) => const SizedBox.shrink(),
      );
    }
    if (followed.areas.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.heart),
          title: Text(t.areas.followedEmpty),
          description: Text(t.areas.followedEmptyHint),
        ),
      );
    }
    return CardGrid<LiveArea>(
      items: followed.areas,
      cardExtent: cardExtent,
      aspectRatio: 3.4,
      itemBuilder: (context, area) => _FollowedAreaCard(
        area: area,
        onUnfollow: () => unawaited(ref.read(followedAreasProvider.notifier).remove(area.identityKey)),
        onSelect: () => unawaited(
          context.push(AreaRoomsRoute(platform: area.platform, areaId: area.areaId).location, extra: area),
        ),
      ),
    );
  }
}

/// One area as a card: its picture, its name, and the parent group it sits
/// in when the platform nests areas. Opening the area is [onSelect].
final class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onSelect, this.trailing});

  /// The area shown.
  final LiveArea area;

  /// Fired when the card opens the area.
  final VoidCallback onSelect;

  /// A small widget at the card's end, e.g. the follow toggle.
  final Widget? trailing;

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
            shadows: hovered ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))] : const <DsShadow>[],
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              _AreaIcon(area: area),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      area.areaName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    if (parent != null && parent.isNotEmpty)
                      Text(parent, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        );
      },
    );
  }
}

/// The followed area's card: the area card with an active heart that
/// unfollows on press.
final class _FollowedAreaCard extends StatelessWidget {
  const _FollowedAreaCard({required this.area, required this.onUnfollow, required this.onSelect});

  final LiveArea area;
  final VoidCallback onUnfollow;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _AreaCard(
      area: area,
      onSelect: onSelect,
      trailing: DsPressable(
        semanticLabel: t.areas.unfollow,
        onPressed: onUnfollow,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return DsIcon(
            DsIcons.heart,
            size: DsTheme.of(context).sizes.iconSm,
            color: hovered ? DsTheme.colorsOf(context).danger.fill : DsTheme.colorsOf(context).textSubtle,
          );
        },
      ),
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
    return DsImage(
      image: cachedImage(url),
      width: theme.sizes.md,
      height: theme.sizes.md,
      semanticLabel: area.areaName,
      fallback: fallback,
    );
  }
}
