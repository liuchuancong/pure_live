import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:mosaic_grid/mosaic_grid.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/features/iptv/iptv_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// How often the page re-reads "what is on now": a programme that started
/// on the minute should not wait for the viewer to reopen the page.
const Duration _slotRefreshInterval = Duration(minutes: 1);

/// The IPTV module's entry page: the channel library's groups as tabs,
/// the open group's channels as a masonry grid of cards — logo, name,
/// what is on now with its progress — and the heart that favourites a
/// channel right from the list.
///
/// The library is the source, not a site: the grid follows the library's
/// watch stream, so whatever surface imports a playlist later lands here
/// without this page asking. A library with nothing imported yet says so
/// in the grid's place instead of failing silently; a channel without a
/// programme guide says that too, per card.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV module's channels page.
  const IptvPage({super.key});

  @override
  ConsumerState<IptvPage> createState() => _IptvPageState();
}

final class _IptvPageState extends ConsumerState<IptvPage> {
  Timer? _slotRefresh;

  @override
  void initState() {
    super.initState();
    _slotRefresh = Timer.periodic(_slotRefreshInterval, (_) {
      ref.read(iptvChannelsProvider.notifier).refreshSlots();
    });
  }

  @override
  void dispose() {
    _slotRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(iptvLibraryProvider);
    if (library.hasError) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(context.t.common.empty),
          description: Text(context.t.iptv.openFailedDescription),
          actions: [
            DsButton(onPressed: () => ref.invalidate(iptvLibraryProvider), child: Text(context.t.common.retry)),
          ],
        ),
      );
    }
    final channels = ref.watch(iptvChannelsProvider);
    if (!channels.ready) {
      return const _SkeletonGrid();
    }
    if (channels.libraryCount == 0) {
      // No channels and no groups, whatever the filter: the library has
      // nothing imported. An empty favourites list is not this state.
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.antenna),
          title: Text(context.t.iptv.emptyTitle),
          description: Text(context.t.iptv.emptyDescription),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ScopeSegments(scope: channels.scope),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
          child: _GroupTabs(channels: channels),
        ),
        Expanded(child: _ChannelsGrid(channels: channels)),
      ],
    );
  }
}

/// The every-channel-or-favourites switch: a choice of two, announced as
/// a radio group; the grid below follows at once.
final class _ScopeSegments extends ConsumerWidget {
  const _ScopeSegments({required this.scope});

  /// The scope the list is in now.
  final IptvChannelScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsSegmentedControl<IptvChannelScope>(
      value: scope,
      onChanged: (next) => ref.read(iptvChannelsProvider.notifier).selectScope(next),
      semanticLabel: t.iptv.scopeLabel,
      segments: [
        DsSegment(value: IptvChannelScope.all, icon: const DsIcon(DsIcons.list), label: Text(t.iptv.scopeAll)),
        DsSegment(
          value: IptvChannelScope.favourites,
          icon: const DsIcon(DsIcons.heart),
          label: Text(t.iptv.scopeFavourites),
        ),
      ],
    );
  }
}

/// The library's groups as a scrolling tab row: every channel first, then
/// one tab per visible group in the library's own display order, each with
/// its live count.
final class _GroupTabs extends ConsumerWidget {
  const _GroupTabs({required this.channels});

  /// The page's state; only its groups half is read here.
  final IptvChannelsState channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsTabs<String?>(
      value: channels.selectedGroup,
      onChanged: (group) => ref.read(iptvChannelsProvider.notifier).selectGroup(group),
      semanticLabel: t.iptv.groupsLabel,
      tabs: [
        DsTab<String?>(value: null, label: Text(t.iptv.tabAll), count: channels.totalCount),
        for (final group in channels.groups)
          DsTab<String?>(value: group, label: Text(_labelOf(t, group)), count: channels.groupCounts[group] ?? 0),
      ],
    );
  }

  /// The group's own name, or the interface's name for the channels no
  /// playlist grouped — the key for those is the empty string the package
  /// leaves to the interface to word.
  static String _labelOf(Translations t, String group) => group.isEmpty ? t.iptv.ungrouped : group;
}

/// The channel grid: the open list's revealed channels as cards, paging in
/// as the view nears its end, an honest empty state in its place. The
/// mosaic grid pages itself; its footer is the loading row's home.
final class _ChannelsGrid extends ConsumerWidget {
  const _ChannelsGrid({required this.channels});

  /// The page's state.
  final IptvChannelsState channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (channels.channels.isEmpty) {
      if (channels.scope == IptvChannelScope.favourites) {
        return Center(
          child: DsEmptyState(
            icon: const DsIcon(DsIcons.heart),
            title: Text(context.t.iptv.noFavoritesTitle),
            description: Text(context.t.iptv.noFavoritesDescription),
          ),
        );
      }
      // A group whose channels are all hidden (or gone with a re-import).
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(context.t.common.empty)),
      );
    }
    final controller = ref.read(iptvChannelsProvider.notifier);
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    final hasMore = channels.shown < channels.channels.length;
    return MosaicGrid.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      itemCount: channels.shown,
      itemBuilder: (context, index) {
        final channel = channels.channels[index];
        return _ChannelCard(
          channel: channel,
          slot: channels.slots[channel.id],
          onToggleFavorite: () => unawaited(controller.toggleFavorite(channel.id)),
        );
      },
      footer: channels.loadingMore
          ? const Padding(
              padding: EdgeInsets.all(DsSpace.s16),
              child: Center(child: _ChannelCardSkeleton()),
            )
          : null,
      onEndReached: hasMore ? () => unawaited(controller.loadMore()) : null,
      endReachedKey: '${channels.selectedGroup ?? '*'}:${channels.scope.name}',
    );
  }
}

/// One channel as a card: the logo (the channel's initials in its place),
/// the number the viewer dialled when it has one, the name, and what is on
/// now — the programme with its progress, the next one when nothing is on,
/// an honest "no guide" line when the channel has none. The heart on the
/// end favourites the channel; opening the channel is the player page's
/// job, so the card body stays inert until that arrives.
final class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.slot, required this.onToggleFavorite});

  /// The channel shown.
  final IptvChannel channel;

  /// What is on the channel; null while the page has not read it.
  final IptvProgrammeSlot? slot;

  /// Fired when the heart is pressed.
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final logo = (channel.entry.tvgLogo ?? '').trim();
    return DsPressable(
      onPressed: null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          padding: const EdgeInsets.all(DsSpace.s12),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : theme.shadows.surface,
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              DsAvatar(
                initials: channel.entry.name,
                image: logo.isEmpty ? null : NetworkImage(logo),
                size: DsSize.md,
                toneIndex: DsAvatar.toneFor(channel.id),
                semanticLabel: channel.entry.name,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s4,
                  children: [
                    Row(
                      spacing: DsSpace.s6,
                      children: [
                        if (channel.number != null)
                          Text(
                            channel.number!.toString(),
                            style: theme.typography.numeric(
                              theme.typography.caption.copyWith(color: colors.textSubtle),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            channel.entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                          ),
                        ),
                      ],
                    ),
                    _ProgrammeLine(slot: slot),
                  ],
                ),
              ),
              _FavoriteButton(favorite: channel.favorite, onPressed: onToggleFavorite),
            ],
          ),
        );
      },
    );
  }
}

/// What is on the channel: the on-air programme with a progress bar, the
/// next one when nothing is on yet, and a quiet "no guide" line when the
/// channel has no programme list to read — three different facts, drawn
/// as three different things.
final class _ProgrammeLine extends StatelessWidget {
  const _ProgrammeLine({required this.slot});

  /// What is on; null while the page has not read it.
  final IptvProgrammeSlot? slot;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final current = slot?.current;
    final next = slot?.next;
    if (current != null && current.title.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          Row(
            spacing: DsSpace.s6,
            children: [
              DsBadge(label: Text(t.iptv.onAir), status: DsStatus.danger),
              Flexible(
                child: Text(
                  current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          // A programme whose length the guide does not know draws no bar:
          // an indeterminate sweep would read as "loading", and this is
          // not loading.
          if (slot?.progress case final progress?) DsProgressBar(value: progress, semanticLabel: t.iptv.onAir),
        ],
      );
    }
    if (next != null && next.title.isNotEmpty) {
      return Row(
        spacing: DsSpace.s6,
        children: [
          DsIcon(DsIcons.clock, size: theme.sizes.iconXs, color: colors.textSubtle),
          Flexible(
            child: Text(
              '${t.iptv.upNext} · ${next.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: colors.textSubtle),
            ),
          ),
        ],
      );
    }
    return Text(
      t.iptv.noGuide,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.caption.copyWith(color: colors.textSubtle),
    );
  }
}

/// The heart on a card's end: the channel's favourite flag, pressed to
/// flip it. A favourited channel's heart carries the accent, the way the
/// favourites badge does elsewhere.
final class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.favorite, required this.onPressed});

  /// Whether the channel is favourited now.
  final bool favorite;

  /// Fired when the heart is pressed.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    return DsPressable(
      semanticLabel: favorite ? t.iptv.unfavouriteAction : t.iptv.favouriteAction,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return SizedBox(
          width: theme.sizes.sm,
          height: theme.sizes.sm,
          child: Center(
            child: DsIcon(
              DsIcons.heart,
              size: theme.sizes.iconSm,
              color: favorite
                  ? colors.accent
                  : hovered
                  ? colors.text
                  : colors.textSubtle,
            ),
          ),
        );
      },
    );
  }
}

/// The grid's opening placeholder: the same masonry shape, no content.
final class _SkeletonGrid extends ConsumerWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardExtent = ref.watch(browseSettingsProvider.select((settings) => settings.homeCardExtent));
    return MosaicGrid(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      columns: MosaicColumns.maxExtent(cardExtent),
      layout: const MosaicLayout.masonry(),
      columnGap: DsSpace.s16,
      rowGap: DsSpace.s16,
      children: [for (var i = 0; i < 12; i++) const _ChannelCardSkeleton()],
    );
  }
}

/// One channel card's placeholder while its page loads: the same shape,
/// no content.
final class _ChannelCardSkeleton extends StatelessWidget {
  const _ChannelCardSkeleton();

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
              spacing: DsSpace.s4,
              children: [
                DsSkeleton(width: DsSpace.s64, height: DsSpace.s12),
                DsSkeleton(width: DsSpace.s48, height: DsSpace.s8),
                DsSkeleton(width: DsSpace.s40, height: DsSpace.s4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
