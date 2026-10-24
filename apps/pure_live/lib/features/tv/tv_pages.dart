import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/popular/popular_controller.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';

/// The TV card: a room as the remote sees it. The pressable is already
/// keyboard-activatable (OK opens the room) and its focus state is the
/// remote's — the card answers it by lifting and ringing itself, the one
/// affordance a three-metre screen needs.
final class TvFocusCard extends StatelessWidget {
  /// The room on the card.
  const TvFocusCard({required this.room, super.key});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final live = room.broadcast.isLiveNow;
    return DsPressable(
      semanticLabel: room.content.title,
      onPressed: () => context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(0, focused ? -8 : 0, 0),
          padding: const EdgeInsets.all(DsSpace.s4),
          decoration: DsBoxDecoration(
            color: colors.control,
            borderRadius: BorderRadius.circular(theme.radii.overlay),
            shadows: focused
                ? [DsShadow(color: colors.overlay, blur: 36, offset: const Offset(0, 14))]
                : const <DsShadow>[],
          ),
          foregroundDecoration: focused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(theme.radii.overlay),
                  border: Border.all(color: theme.selectedFill, width: 3),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsImage(
                image: cachedImage(room.content.coverUrl),
                aspectRatio: 16 / 9,
                semanticLabel: room.content.title,
                style: DsImageStyle(borderRadius: BorderRadius.circular(theme.radii.card)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s6, DsSpace.s8, DsSpace.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      room.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Row(
                      spacing: DsSpace.s6,
                      children: [
                        Expanded(
                          child: Text(
                            room.anchor?.name ?? room.ref.roomId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.small.copyWith(color: colors.textMuted),
                          ),
                        ),
                        if (!live)
                          DsIcon(DsIcons.circleSlash, size: 14, color: colors.textSubtle),
                      ],
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

/// The TV platform row: one large focusable block per platform — the
/// remote's first stop, before the card wall under it.
final class TvPlatformRow extends ConsumerWidget {
  /// The row over [platforms], [current] selected.
  const TvPlatformRow({
    required this.platforms,
    required this.current,
    required this.onChanged,
    super.key,
  });

  final List<String> platforms;
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final names = <String, String>{
      for (final site in ref.watch(sitesProvider).all) site.manifest.id: site.manifest.name['zh-CN'] ?? site.manifest.id,
    };
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: platforms.length,
        separatorBuilder: (context, index) => const SizedBox(width: DsSpace.s8),
        itemBuilder: (context, index) {
          final id = platforms[index];
          return DsPressable(
            autofocus: index == 0,
            semanticLabel: names[id] ?? id,
            onPressed: () => onChanged(id),
            builder: (context, states, _) {
              final focused = states.contains(WidgetState.focused);
              final selected = id == current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
                alignment: Alignment.center,
                decoration: DsBoxDecoration(
                  color: selected ? theme.selectedFill : focused ? colors.hover : colors.control,
                  borderRadius: BorderRadius.circular(theme.radii.control(56)),
                ),
                foregroundDecoration: focused
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(theme.radii.control(56)),
                        border: Border.all(color: theme.selectedFill, width: 2.5),
                      )
                    : null,
                child: Text(
                  names[id] ?? id,
                  style: theme.typography.body.copyWith(
                    fontSize: 19,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? theme.onSelectedFill : colors.text,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The TV popular page: the platform row above this platform's feed, every
/// card remote-focusable. The controllers are the phone and desktop ones —
/// the data layer has no shape of its own.
final class TvPopularPage extends ConsumerStatefulWidget {
  /// The TV home page.
  const TvPopularPage({super.key});

  @override
  ConsumerState<TvPopularPage> createState() => _TvPopularPageState();
}

final class _TvPopularPageState extends ConsumerState<TvPopularPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(popularCatalogProvider.notifier).open(ref.read(popularSiteProvider)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final platform = ref.watch(popularSiteProvider);
    final ids = ref.watch(popularCatalogProvider.notifier).platformIds();
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final catalog = ref.watch(popularCatalogProvider.select((map) => map[platform]));
    final state =
        catalog ?? (rooms: const <LiveRoom>[], nextPage: 1, hasMore: true, loading: false, error: null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s16, DsSpace.s24, DsSpace.s8),
          child: TvPlatformRow(
            platforms: ids,
            current: platform,
            onChanged: (id) {
              ref.read(popularSiteProvider.notifier).selected = id;
              unawaited(ref.read(popularCatalogProvider.notifier).open(id));
            },
          ),
        ),
        Expanded(
          child: CardGrid<LiveRoom>(
            key: ValueKey(platform),
            padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s8, DsSpace.s24, DsSpace.s24),
            items: state.rooms,
            cardExtent: cardExtent.clamp(240, 400),
            aspectRatio: 1.15,
            isLoading: state.loading,
            hasMore: state.hasMore,
            onLoadMore: () => ref.read(popularCatalogProvider.notifier).loadMore(platform),
            error: state.error?.message,
            onRetry: () => ref.read(popularCatalogProvider.notifier).refresh(platform),
            itemBuilder: (context, room) => TvFocusCard(room: room),
          ),
        ),
      ],
    );
  }
}
