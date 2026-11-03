import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart' show iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show iptvRemindersProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/views/iptv_group_rail.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_dialog.dart';
import 'package:pure_live/modules/iptv/views/iptv_panels.dart';
import 'package:pure_live/modules/iptv/views/iptv_sources_view.dart';
import 'package:pure_live/shared/shared.dart';

/// How often the page re-reads "what is on now": a programme that started
/// on the minute should not wait for the viewer to reopen the page.
const Duration _slotRefreshInterval = Duration(minutes: 1);

/// The two surfaces of the IPTV module: the channel browser, and the source
/// manager that imports, syncs and removes the playlists and guides behind
/// it. The module's menu gives each one its own entry, so the page opens on
/// the surface the entry names.
enum IptvView {
  /// The library's channels, grouped and filterable.
  channels,

  /// The playlists and guide sources, with the sync actions.
  sources,
}

/// The IPTV module's entry page.
///
/// A page header names the open surface and its counts, with the imports
/// beside it. The channel surface is the reference's two panes: the library's
/// groups down the first column, and the channels of the open group as a
/// resource table — logo, group, what is on now with its progress, the
/// favourite heart and the player action. A window too narrow for the column
/// keeps the same group list behind one line over the table, and the table
/// itself stacks its rows instead of scrolling sideways. The source surface
/// keeps the same table language over the playlists and guides.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV module's channels page, opening on [initialView].
  const IptvPage({this.initialView = IptvView.channels, this.initialScope, super.key});

  /// The surface the page opens on.
  final IptvView initialView;

  /// The channel scope the browser opens on; null leaves the previous choice
  /// alone. The module's 收藏 entry opens the same table, favourites only.
  final IptvChannelScope? initialScope;

  @override
  ConsumerState<IptvPage> createState() => _IptvPageState();
}

final class _IptvPageState extends ConsumerState<IptvPage> {
  Timer? _slotRefresh;
  late IptvView _view = widget.initialView;
  final TextEditingController _channelSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    final scope = widget.initialScope;
    if (scope != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(iptvChannelsProvider.notifier).selectScope(scope);
      });
    }
    // The toolbar's word lands in the channel search in place — even from
    // the sources surface, which steps back to the channels it searches.
    // The listener catches a word handed while the page is showing; the
    // post-frame take catches one handed as the page arrives.
    ref.listenManual(iptvSearchHandoffProvider, (_, _) => _takeHandoff());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeHandoff());
    _slotRefresh = Timer.periodic(_slotRefreshInterval, (_) {
      // A tick queued as the page leaves must not reach a defunct ref.
      if (!mounted) return;
      ref.read(iptvChannelsProvider.notifier).refreshSlots();
    });
  }

  /// Moves the handed word into the channel search: the field reads it and
  /// the channels controller narrows to it.
  void _takeHandoff() {
    final word = ref.read(iptvSearchHandoffProvider.notifier).take();
    if (word == null || word.isEmpty || !mounted) return;
    if (_view != IptvView.channels) setState(() => _view = IptvView.channels);
    _channelSearch.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    ref.read(iptvChannelsProvider.notifier).setQuery(word);
  }

  @override
  void didUpdateWidget(IptvPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the menu moves between the module's
    // entries, so a new entry has to move the page to its surface.
    if (widget.initialView != _view) setState(() => _view = widget.initialView);
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
    // Reading the reminders here arms the module's stored ones: the timer
    // lives in the controller, and a reminder set before a restart has no
    // other reason to bring it back.
    ref.watch(iptvRemindersProvider);
    final library = ref.watch(iptvLibraryProvider);
    if (library.hasError) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.iptv.openFailed),
          description: Text(t.iptv.openFailedDescription),
          actions: [DsButton(onPressed: () => ref.invalidate(iptvLibraryProvider), child: Text(t.common.retry))],
        ),
      );
    }
    final channels = ref.watch(iptvChannelsProvider);
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    final blocked = sources.importing || epg.importing || sources.syncAll != null || !sources.ready || !epg.ready;
    final channelsView = _view == IptvView.channels;
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
          onImportPlaylist: blocked ? null : () => unawaited(runIptvPlaylistImport(context)),
          onImportGuide: blocked ? null : () => unawaited(runIptvGuideImport(context)),
        ),
        Expanded(
          child: switch (_view) {
            IptvView.channels => _ChannelsView(channels: channels, search: _channelSearch),
            IptvView.sources => const IptvSourcesView(),
          },
        ),
      ],
    );
  }
}

/// The surface's head: the module above the page's own name, the counts
/// under it, and the imports at the end. A narrow window stacks the actions
/// under the title instead of squeezing them. The module's menu, not this
/// header, moves between the surfaces.
final class _IptvHeader extends StatelessWidget {
  const _IptvHeader({
    required this.title,
    required this.description,
    required this.onImportPlaylist,
    required this.onImportGuide,
  });

  final String title;
  final String description;
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
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = LiveWindow.isExpanded(constraints.maxWidth);
        final inset = LiveWindow.pageInset(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s16, inset, DsSpace.s4),
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

/// The channel surface: the library's groups down a first column (behind one
/// entry where the window has no room for a column), and over the open
/// group's channels a resource table — the scope and a name search above it.
/// The table fills the pane and pages in as it nears its end.
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

  /// Opens [group] (null for every channel at once) on the browser's own
  /// state, so the column, the entry and the table all follow one choice.
  void _selectGroup(String? group) => ref.read(iptvChannelsProvider.notifier).selectGroup(group);

  /// The group half of the browser's state, in the shape the module's group
  /// column and its entry read.
  IptvGroupFilter get _groupFilter {
    final channels = widget.channels;
    return (
      groups: channels.groups,
      groupCounts: channels.groupCounts,
      totalCount: channels.totalCount,
      selectedGroup: channels.selectedGroup,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final channels = widget.channels;
    if (!channels.ready) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
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
    final filter = _groupFilter;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // A single group has nothing to choose, and the library's own
        // display order is what the column walks.
        final hasGroups = channels.groups.length > 1;
        final rail = hasGroups && LiveWindow.isExpanded(width);
        final inset = LiveWindow.pageInset(width);
        final panel = IptvTablePanel(
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
              if (hasGroups && !rail) IptvGroupEntry(filter: filter, onSelect: _selectGroup),
            ],
          ),
          child: _ChannelsTable(channels: channels, scrollController: _scroll, onOpen: _open),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s16),
          child: rail
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s12,
                  children: [
                    IptvGroupsColumn(filter: filter, onSelect: _selectGroup),
                    Expanded(child: panel),
                  ],
                )
              : panel,
        );
      },
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
        if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
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

/// The channel rows: logo and name, group, what is on now, the favourite
/// heart and the player action. The row itself opens the channel, so a
/// remote or a click anywhere on it works.
///
/// Two forms of the same list. A window of [LiveWindow.compact] and wider
/// reads it as a table; below that the columns cannot fit — the four a
/// medium window keeps need 560 px against a phone's 390 — and a
/// sideways-scrolling table parks the heart and the player action off
/// screen, so the rows stack instead. The kit's own card layout is not the
/// fallback here: it puts one column per "label value" line at a single
/// line's height, and this module's cells are two-line (a name over its dial
/// number, a programme over its progress bar).
final class _ChannelsTable extends ConsumerWidget {
  const _ChannelsTable({required this.channels, required this.scrollController, required this.onOpen});

  final IptvChannelsState channels;
  final ScrollController scrollController;
  final ValueChanged<IptvChannel> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final rows = channels.channels.take(channels.shown).toList(growable: false);
    if (rows.isEmpty) return _channelsEmptyView(context, channels);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (LiveWindow.isCompact(constraints.maxWidth)) {
          return _ChannelsList(channels: channels, scrollController: scrollController, onOpen: onOpen);
        }
        // The group column above (or the entry that opens it) already names
        // and counts the groups; the per-row column only says something when
        // the list runs across more than one — every row repeating the open
        // group's name is the 120 px that pushed this table past a medium
        // window.
        final showGroup = LiveWindow.isExpanded(constraints.maxWidth) && channels.selectedGroup == null;
        return DsTable<IptvChannel>(
          semanticLabel: t.iptv.viewChannels,
          rows: rows,
          rowKey: (channel) => channel.id,
          columns: [
            DsTableColumn(
              id: 'channel',
              label: t.iptv.colChannel,
              value: (channel) => channel.entry.name,
              width: const DsTableColumnWidth.flex(2, 200),
              cell: (context, channel) => _ChannelNameCell(channel: channel, showNumber: browse.showChannelNumber),
            ),
            if (showGroup)
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
            if (browse.showProgrammeLine)
              DsTableColumn(
                id: 'now',
                label: t.iptv.colNow,
                value: (channel) => channels.slots[channel.id]?.current?.title ?? '',
                width: const DsTableColumnWidth.flex(2, 200),
                cell: (context, channel) => IptvNowCell(slot: channels.slots[channel.id]),
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
        );
      },
    );
  }
}

/// What an empty channel list says: a search that matched nothing, a
/// favourites scope with nothing in it, or a library with no channels at
/// all. Shared by the table's window and the stacked list's.
Widget _channelsEmptyView(BuildContext context, IptvChannelsState channels) {
  final t = context.t;
  if (channels.query.isNotEmpty) {
    return Center(
      child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noChannelMatch)),
    );
  }
  if (channels.scope == IptvChannelScope.favourites) {
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.heart),
        title: Text(t.iptv.noFavoritesTitle),
        description: Text(t.iptv.noFavoritesDescription),
      ),
    );
  }
  return Center(
    child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(t.common.empty)),
  );
}

/// The channel's group, named by the interface when the playlist left the
/// channel ungrouped — the same wording the group column and the guide page's
/// rows use.
String _groupOf(Translations t, IptvChannel channel) => iptvGroupLabel(t, iptvGroupKeyOf(channel));

/// The stacked form of the channel rows: the channel's logo and name over
/// what is on it, with the dial number, the heart and the player action at
/// its end. The same three columns as the table, in the row language the
/// module's 最近观看 page already uses, and it pages off the same scroll
/// controller.
final class _ChannelsList extends ConsumerWidget {
  const _ChannelsList({required this.channels, required this.scrollController, required this.onOpen});

  final IptvChannelsState channels;
  final ScrollController scrollController;
  final ValueChanged<IptvChannel> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final rows = channels.channels.take(channels.shown).toList(growable: false);
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      itemCount: rows.length,
      separatorBuilder: (context, _) => const DsDivider(),
      itemBuilder: (context, index) {
        final channel = rows[index];
        final number = browse.showChannelNumber ? channel.number : null;
        return DsListRow(
          semanticLabel: channel.entry.name,
          leading: IptvChannelLogo(channel: channel),
          title: Text(
            channel.entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
          ),
          detail: number == null
              ? null
              : Text(
                  '$number',
                  style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                ),
          description: browse.showProgrammeLine
              ? IptvNowCell(slot: channels.slots[channel.id])
              // Same rule as the table's group column: the row says which
              // group it is in only when the list spans several — the column
              // or its entry above already named the one that is open.
              : channels.selectedGroup != null
              ? null
              : Text(
                  _groupOf(t, channel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s3,
            children: [
              _FavoriteCell(
                favorite: channel.favorite,
                onPressed: () => unawaited(ref.read(iptvChannelsProvider.notifier).toggleFavorite(channel.id)),
              ),
              IptvIconAction(icon: DsIcons.play, label: t.iptv.openChannel, onPressed: () => onOpen(channel)),
            ],
          ),
          onPressed: () => onOpen(channel),
        );
      },
    );
  }
}

/// A channel's logo and name, with its dial number under the name when it
/// has one and the browse setting asks for it.
final class _ChannelNameCell extends StatelessWidget {
  const _ChannelNameCell({required this.channel, required this.showNumber});

  final IptvChannel channel;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final number = showNumber ? channel.number : null;
    return Row(
      spacing: DsSpace.s8,
      children: [
        IptvChannelLogo(channel: channel),
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
                  '$number',
                  style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                ),
            ],
          ),
        ),
      ],
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
