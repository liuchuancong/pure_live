import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/features/iptv/iptv_controller.dart';
import 'package:pure_live/features/iptv/iptv_epg_controller.dart';
import 'package:pure_live/features/iptv/iptv_import_dialog.dart';
import 'package:pure_live/features/iptv/iptv_panels.dart';
import 'package:pure_live/features/iptv/iptv_sources_controller.dart';
import 'package:pure_live/features/iptv/iptv_sources_view.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/images/app_image_cache.dart';

/// How often the page re-reads "what is on now": a programme that started
/// on the minute should not wait for the viewer to reopen the page.
const Duration _slotRefreshInterval = Duration(minutes: 1);

/// The two surfaces of the IPTV module: the channel browser, and the
/// source manager that imports, syncs and removes the playlists and guides
/// behind it.
enum _IptvView {
  /// The library's channels, grouped and filterable.
  channels,

  /// The playlists and guide sources, with the sync actions.
  sources,
}

/// The IPTV module's entry page.
///
/// A page header names the open surface and its counts, with the imports
/// and the surface switch beside it. The channel surface is a resource
/// table: scope and group filters, a name search, "sync all" and one row
/// per channel — logo, group, what is on now with its progress, the
/// favourite heart and the player action. The source surface keeps the
/// same table language over the playlists and guides.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV module's channels page.
  const IptvPage({super.key});

  @override
  ConsumerState<IptvPage> createState() => _IptvPageState();
}

final class _IptvPageState extends ConsumerState<IptvPage> {
  Timer? _slotRefresh;
  _IptvView _view = _IptvView.channels;
  final TextEditingController _channelSearch = TextEditingController();

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
    _channelSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final library = ref.watch(iptvLibraryProvider);
    if (library.hasError) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.common.empty),
          description: Text(t.iptv.openFailedDescription),
          actions: [DsButton(onPressed: () => ref.invalidate(iptvLibraryProvider), child: Text(t.common.retry))],
        ),
      );
    }
    final channels = ref.watch(iptvChannelsProvider);
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    final blocked = sources.importing || epg.importing || sources.syncAll != null || !sources.ready || !epg.ready;
    final channelsView = _view == _IptvView.channels;
    final title = channelsView ? t.iptv.viewChannels : t.iptv.viewSources;
    final description = channelsView
        ? channels.query.isNotEmpty
              ? t.iptv.summaryChannelSearch(count: channels.channels.length)
              : t.iptv.summaryChannels(count: channels.totalCount, groups: channels.groups.length)
        : t.iptv.summarySources(
            playlists: sources.playlists.length,
            guides: epg.sources.length,
            channels: sources.channelCount,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IptvHeader(
          title: title,
          description: description,
          view: _view,
          onView: (next) => setState(() => _view = next),
          onImportPlaylist: blocked ? null : () => unawaited(runIptvPlaylistImport(context)),
          onImportGuide: blocked ? null : () => unawaited(runIptvGuideImport(context)),
        ),
        Expanded(
          child: switch (_view) {
            _IptvView.channels => _ChannelsView(channels: channels, search: _channelSearch),
            _IptvView.sources => const IptvSourcesView(),
          },
        ),
      ],
    );
  }
}

/// The surface's head: the module above the page's own name, the counts
/// under it, and the imports and surface switch at the end. A narrow window
/// stacks the actions under the title instead of squeezing them.
final class _IptvHeader extends StatelessWidget {
  const _IptvHeader({
    required this.title,
    required this.description,
    required this.view,
    required this.onView,
    required this.onImportPlaylist,
    required this.onImportGuide,
  });

  final String title;
  final String description;
  final _IptvView view;
  final ValueChanged<_IptvView> onView;
  final VoidCallback? onImportPlaylist;
  final VoidCallback? onImportGuide;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(t.common.moduleIptv, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
        Text(title, style: theme.typography.display.copyWith(color: colors.text)),
        Text(description, style: theme.typography.body.copyWith(color: colors.textMuted)),
      ],
    );
    final actions = Wrap(
      spacing: DsSpace.s8,
      runSpacing: DsSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: onImportPlaylist,
          leading: const DsIcon(DsIcons.plus, size: 15),
          child: Text(t.iptv.importPlaylist),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: onImportGuide,
          leading: const DsIcon(DsIcons.calendarClock, size: 15),
          child: Text(t.iptv.importGuide),
        ),
        DsSegmentedControl<_IptvView>(
          value: view,
          onChanged: onView,
          semanticLabel: t.iptv.viewLabel,
          segments: [
            DsSegment(value: _IptvView.channels, icon: const DsIcon(DsIcons.tv), label: Text(t.iptv.viewChannels)),
            DsSegment(value: _IptvView.sources, icon: const DsIcon(DsIcons.list), label: Text(t.iptv.viewSources)),
          ],
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s16, DsSpace.s20, DsSpace.s4),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: DsSpace.s16),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s12,
                  children: [
                    heading,
                    Align(alignment: AlignmentDirectional.centerStart, child: actions),
                  ],
                ),
        );
      },
    );
  }
}

/// The channel surface: the scope and group filters and a name search over
/// the channel table. The table fills the pane and pages in as it nears
/// its end.
final class _ChannelsView extends ConsumerStatefulWidget {
  const _ChannelsView({required this.channels, required this.search});

  final IptvChannelsState channels;
  final TextEditingController search;

  @override
  ConsumerState<_ChannelsView> createState() => _ChannelsViewState();
}

final class _ChannelsViewState extends ConsumerState<_ChannelsView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!mounted || !_scroll.hasClients || _scroll.position.extentAfter >= 600) return;
    unawaited(ref.read(iptvChannelsProvider.notifier).loadMore());
  }

  /// A page smaller than the window leaves no scroll to invite the next
  /// one: reveal another page after the frame, until the viewport fills or
  /// the list ends. Its own rebuild schedules the next check.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _scroll.position.maxScrollExtent > 0) return;
      final channels = ref.read(iptvChannelsProvider);
      if (channels.loadingMore || channels.shown >= channels.channels.length) return;
      unawaited(ref.read(iptvChannelsProvider.notifier).loadMore());
    });
  }

  void _open(IptvChannel channel) {
    unawaited(context.push(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final channels = widget.channels;
    if (!channels.ready) {
      return const Center(child: DsSpinner());
    }
    if (channels.libraryCount == 0) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.antenna),
          title: Text(t.iptv.emptyTitle),
          description: Text(t.iptv.emptyDescription),
          actions: [
            DsButton(
              onPressed: () => unawaited(runIptvPlaylistImport(context)),
              leading: const DsIcon(DsIcons.plus, size: 16),
              child: Text(t.iptv.importPlaylist),
            ),
          ],
        ),
      );
    }
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    final progress = sources.syncAll;
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    final canSync =
        hasRemote &&
        progress == null &&
        !sources.importing &&
        !epg.importing &&
        sources.busy.isEmpty &&
        epg.busy.isEmpty &&
        sources.ready &&
        epg.ready;
    _fillViewport();
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
      child: IptvTablePanel(
        fill: true,
        toolbar: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s6,
          children: [
            _ChannelsToolbar(
              channels: channels,
              search: widget.search,
              progress: progress,
              canSync: canSync,
              onSync: () => unawaited(syncAllIptvSources(context, ref)),
            ),
            _GroupTabs(channels: channels),
          ],
        ),
        child: _ChannelsTable(channels: channels, scrollController: _scroll, onOpen: _open),
      ),
    );
  }
}

/// The channel table's first row: scope, the open list's count, the name
/// search and the shared sync-all action.
final class _ChannelsToolbar extends ConsumerWidget {
  const _ChannelsToolbar({
    required this.channels,
    required this.search,
    required this.progress,
    required this.canSync,
    required this.onSync,
  });

  final IptvChannelsState channels;
  final TextEditingController search;
  final ({int done, int total})? progress;
  final bool canSync;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final scope = _ScopeSegments(scope: channels.scope);
    final count = Text(
      progress != null
          ? t.iptv.syncAllRunning(done: progress!.done, total: progress!.total)
          : t.iptv.channelCount(count: channels.channels.length),
      style: theme.typography.small.copyWith(color: colors.textMuted),
    );
    final field = DsSearchField(
      controller: search,
      placeholder: t.iptv.searchChannels,
      semanticLabel: t.iptv.searchChannels,
      onChanged: (value) => ref.read(iptvChannelsProvider.notifier).setQuery(value),
    );
    final sync = DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      loading: progress != null,
      onPressed: canSync ? onSync : null,
      leading: const DsIcon(DsIcons.refreshCw, size: 15),
      child: Text(t.iptv.syncAll),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            spacing: DsSpace.s12,
            children: [
              scope,
              count,
              const Spacer(),
              SizedBox(width: 200, child: field),
              sync,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            scope,
            Row(
              children: [
                Expanded(child: count),
                const SizedBox(width: DsSpace.s8),
                sync,
              ],
            ),
            field,
          ],
        );
      },
    );
  }
}

/// The every-channel-or-favourites switch: a choice of two, announced as
/// a radio group; the table below follows at once.
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

/// The channel rows: logo and name, group, what is on now, the favourite
/// heart and the player action. The row itself opens the channel, so a
/// remote or a click anywhere on it works.
final class _ChannelsTable extends ConsumerWidget {
  const _ChannelsTable({required this.channels, required this.scrollController, required this.onOpen});

  final IptvChannelsState channels;
  final ScrollController scrollController;
  final ValueChanged<IptvChannel> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final rows = channels.channels.take(channels.shown).toList(growable: false);
    return DsTable<IptvChannel>(
      semanticLabel: t.iptv.viewChannels,
      layout: const DsTableLayout.auto(),
      rows: rows,
      rowKey: (channel) => channel.id,
      columns: [
        DsTableColumn(
          id: 'channel',
          label: t.iptv.colChannel,
          value: (channel) => channel.entry.name,
          width: const DsTableColumnWidth.flex(2, 220),
          cell: (context, channel) => _ChannelNameCell(channel: channel),
        ),
        DsTableColumn(
          id: 'group',
          label: t.iptv.colGroup,
          value: (channel) => _groupOf(t, channel),
          width: const DsTableColumnWidth.fixed(120),
          cell: (context, channel) => Text(
            _groupOf(t, channel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
          ),
        ),
        DsTableColumn(
          id: 'now',
          label: t.iptv.colNow,
          value: (channel) => channels.slots[channel.id]?.current?.title ?? '',
          width: const DsTableColumnWidth.flex(2, 200),
          cell: (context, channel) => _NowCell(slot: channels.slots[channel.id]),
        ),
        DsTableColumn(
          id: 'favorite',
          label: t.iptv.colFavorite,
          width: const DsTableColumnWidth.fixed(72),
          alignment: DsTableCellAlignment.center,
          cell: (context, channel) => _FavoriteCell(
            favorite: channel.favorite,
            onPressed: () => unawaited(ref.read(iptvChannelsProvider.notifier).toggleFavorite(channel.id)),
          ),
        ),
        DsTableColumn(
          id: 'actions',
          label: t.iptv.colActions,
          width: const DsTableColumnWidth.fixed(64),
          alignment: DsTableCellAlignment.center,
          cell: (context, channel) =>
              IptvIconAction(icon: DsIcons.play, label: t.iptv.openChannel, onPressed: () => onOpen(channel)),
        ),
      ],
      onRowPressed: onOpen,
      scrollController: scrollController,
      loading: channels.loadingMore,
      style: iptvTableStyle(context),
      emptyView: _emptyView(context),
    );
  }

  Widget _emptyView(BuildContext context) {
    final t = context.t;
    if (channels.query.isNotEmpty) {
      return DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noChannelMatch));
    }
    if (channels.scope == IptvChannelScope.favourites) {
      return DsEmptyState(
        icon: const DsIcon(DsIcons.heart),
        title: Text(t.iptv.noFavoritesTitle),
        description: Text(t.iptv.noFavoritesDescription),
      );
    }
    return Center(
      child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(t.common.empty)),
    );
  }

  static String _groupOf(Translations t, IptvChannel channel) {
    final group = iptvGroupKeyOf(channel);
    return group.isEmpty ? t.iptv.ungrouped : group;
  }
}

/// A channel's logo and name, with its dial number under the name when it
/// has one.
final class _ChannelNameCell extends StatelessWidget {
  const _ChannelNameCell({required this.channel});

  final IptvChannel channel;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final logo = (channel.entry.tvgLogo ?? '').trim();
    final number = channel.number;
    return Row(
      spacing: DsSpace.s8,
      children: [
        DsAvatar(
          initials: channel.entry.name,
          image: logo.isEmpty ? null : cachedImage(logo),
          size: DsSize.sm,
          toneIndex: DsAvatar.toneFor(channel.id),
          semanticLabel: channel.entry.name,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(
                channel.entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
              if (number != null)
                Text(
                  number.toString(),
                  style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What is on the channel: the on-air programme with its progress, the next
/// one when nothing is on yet, and a quiet "no guide" line when there is no
/// schedule to read — three facts, drawn as three things.
final class _NowCell extends StatelessWidget {
  const _NowCell({required this.slot});

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
        spacing: 2,
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
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
          // A programme whose length the guide does not know draws no bar:
          // an indeterminate sweep would read as "loading".
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
              style: theme.typography.small.copyWith(color: colors.textSubtle),
            ),
          ),
        ],
      );
    }
    return Text(
      t.iptv.noGuide,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.small.copyWith(color: colors.textSubtle),
    );
  }
}

/// The heart in the table: the channel's favourite flag, pressed to flip it.
final class _FavoriteCell extends StatelessWidget {
  const _FavoriteCell({required this.favorite, required this.onPressed});

  final bool favorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return IptvIconAction(
      icon: DsIcons.heart,
      label: favorite ? t.iptv.unfavouriteAction : t.iptv.favouriteAction,
      onPressed: onPressed,
      color: favorite ? DsTheme.colorsOf(context).accent : null,
    );
  }
}
