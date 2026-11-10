import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/layouts/tv/tv_input_field.dart' show TvInputField;

import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart' show iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_presets_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show iptvRemindersProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/data/iptv_preset.dart' show IptvPreset;
import 'package:pure_live/modules/iptv/data/iptv_preset_catalog.dart' show builtinIptvPresets;
import 'package:pure_live/modules/iptv/views/iptv_channel_preview.dart';
import 'package:pure_live/modules/iptv/views/iptv_group_rail.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_dialog.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_preview_pane.dart' show iptvImportFailureWords;
import 'package:pure_live/modules/iptv/views/iptv_import_source_pane.dart' show IptvPresetCard;
import 'package:pure_live/modules/iptv/views/iptv_panels.dart';
import 'package:pure_live/modules/iptv/views/iptv_sources_view.dart';
import 'package:pure_live/shared/shared.dart';

/// How often the page re-reads "what is on now": a programme that started
/// on the minute should not wait for the viewer to reopen the page.
const Duration _slotRefreshInterval = Duration(minutes: 1);

/// The channel scope strip's shape: the module's content-tabs measure — 44
/// tall, flush with the line that holds it, and no hairline under the row —
/// the same shape the music module's feed tabs wear, against the kit's own
/// defaults (46 tall over a border-coloured rule) that would contradict it.
const DsTabsStyle _iptvScopeTabsStyle = DsTabsStyle(
  height: 44,
  padding: EdgeInsets.zero,
  dividerColor: Color(0x00000000),
);

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
/// The page opens on the live module's own tool line: what the surface holds
/// at its start, its verbs at the end, and on a narrow page the verbs ride the
/// shell's head instead (the phone rule every module follows). The channel
/// surface is the reference's two panes: the library's groups down the first
/// column, and the channels of the open group as a resource table — logo,
/// group, what is on now with its progress, the favourite heart and the
/// player action. A window too narrow for the column keeps the same group list
/// behind one line over the table, and the table itself stacks its rows
/// instead of scrolling sideways. The source surface keeps the same table
/// language over the playlists and guides.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV module's channels page, opening on [initialView].
  const IptvPage({required this.owner, this.initialView = IptvView.channels, this.initialScope, super.key});

  /// The menu entry this page is standing in for: the shell shows the head
  /// verbs only under the entry that published them.
  final NavigationItem owner;

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
    // Arriving on the module is when the preset layer acts: the first visit
    // adds the default source, signed lists whose links went stale are
    // re-read, and the recommended catalogue is refreshed from its feed.
    // Each runs off the frame and none of them blocks the page.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_arrive()));
    _slotRefresh = Timer.periodic(_slotRefreshInterval, (_) {
      // A tick queued as the page leaves must not reach a defunct ref.
      if (!mounted) return;
      ref.read(iptvChannelsProvider.notifier).refreshSlots();
    });
  }

  /// The preset layer's work on arrival, once the library is open.
  Future<void> _arrive() async {
    try {
      await ref.read(iptvLibraryProvider.future);
    } on Object {
      return;
    }
    if (!mounted) return;
    final presets = ref.read(iptvPresetsProvider.notifier);
    unawaited(presets.refreshFeed());
    if (!ref.read(iptvPresetsProvider).onboarded) {
      // An existing library is the viewer's own choice already; only an
      // empty one is given the default.
      final library = ref.read(iptvLibraryProvider).value;
      if (library != null && library.playlists.isEmpty) {
        await presets.onboard();
      } else {
        presets.skipOnboarding();
      }
    }
    if (mounted) unawaited(presets.refreshStale());
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
    final title = channelsView ? t.iptv.libraryTitle : t.iptv.viewSources;
    final description = channelsView
        ? channels.query.isNotEmpty
              ? t.iptv.summaryChannelSearch(count: channels.channels.length)
              : t.iptv.librarySummary(playlists: sources.playlists.length, channels: channels.totalCount)
        : t.iptv.summarySources(
            playlists: sources.playlists.length,
            guides: epg.sources.length,
            channels: sources.channelCount,
          );
    // The shell's one width decision: on a narrow page the imports ride the
    // shell's head line, the rule the live module's pages follow.
    final narrow = PageLayoutScope.isNarrow(context);
    void importPlaylist() => unawaited(runIptvPlaylistImport(context));
    void importGuide() => unawaited(runIptvGuideImport(context));
    // The head's shared sync-all verb, beside the imports while the window
    // keeps the verbs (the reference's head row). Below the shell's toolbar
    // breakpoint the verbs fold into the shell's head instead, so the
    // channels toolbar carries the verb on its own search line; the sources
    // surface leaves it out here, its table line already saying it.
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    final canSyncAll = hasRemote && !blocked && sources.busy.isEmpty && epg.busy.isEmpty;
    final syncVerb = DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      loading: sources.syncAll != null,
      onPressed: canSyncAll ? () => unawaited(syncAllIptvSources(context, ref)) : null,
      leading: const DsIcon(DsIcons.refreshCw, size: 15),
      child: Text(t.iptv.syncAll),
    );
    final more = DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: t.common.more,
      leading: const DsIcon(DsIcons.chevronDown, size: 14),
      child: Text(t.common.more),
      onPressed: () => unawaited(
        showActionsPanel(
          context,
          title: t.common.more,
          children: [
            DsListSection(
              children: [
                DsListRow(
                  leading: const DsIcon(DsIcons.plus, size: 16),
                  title: Text(t.iptv.importPlaylist),
                  onPressed: blocked
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          importPlaylist();
                        },
                ),
                DsListRow(
                  leading: const DsIcon(DsIcons.calendarClock, size: 16),
                  title: Text(t.iptv.importGuide),
                  onPressed: blocked
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          importGuide();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (narrow && channelsView) publishPageHeadActions(context, ref, widget.owner, [more]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The channels surface opens with the shared head; the sources view
        // carries its own — its verbs (the import menu, sort) live there, and
        // one head per surface keeps the line honest.
        if (channelsView)
          LayoutBuilder(
            builder: (context, constraints) {
              final inset = LiveWindow.pageInset(constraints.maxWidth);
              return Padding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
                child: IptvPageHead(
                  title: title,
                  description: description,
                  actions: narrow
                      ? const <Widget>[]
                      : [
                          DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: blocked ? null : importPlaylist,
                            leading: const DsIcon(DsIcons.plus, size: 15),
                            child: Text(t.iptv.importPlaylist),
                          ),
                          DsButton(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            onPressed: blocked ? null : importGuide,
                            leading: const DsIcon(DsIcons.calendarClock, size: 15),
                            child: Text(t.iptv.importGuide),
                          ),
                          if (channelsView) syncVerb,
                        ],
                ),
              );
            },
          ),
        Expanded(
          child: switch (_view) {
            IptvView.channels => _ChannelsView(channels: channels, search: _channelSearch, syncOnToolbar: narrow),
            IptvView.sources => const IptvSourcesView(),
          },
        ),
      ],
    );
  }
}

/// The channel surface: the library's groups down a first column (behind one
/// entry where the window has no room for a column), and over the open
/// group's channels a resource table — the scope and a name search above it.
/// The table fills the pane and pages in as it nears its end.
final class _ChannelsView extends ConsumerStatefulWidget {
  const _ChannelsView({required this.channels, required this.search, required this.syncOnToolbar});

  final IptvChannelsState channels;
  final TextEditingController search;

  /// Whether the shared sync-all verb rides the toolbar's own search line:
  /// the page folds the head verbs below the shell's toolbar breakpoint, and
  /// the folded head leaves the verb off its line, so this toolbar draws it.
  final bool syncOnToolbar;

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
    final channels = widget.channels;
    if (!channels.ready) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    }
    if (channels.libraryCount == 0) {
      return const _StartView();
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
                syncOnToolbar: widget.syncOnToolbar,
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

/// The channel table's first row: the scope tabs, the open list's count, the
/// name search and — where the page's head line does not already carry it —
/// the shared sync-all action.
final class _ChannelsToolbar extends ConsumerWidget {
  const _ChannelsToolbar({
    required this.channels,
    required this.search,
    required this.progress,
    required this.canSync,
    required this.syncOnToolbar,
    required this.onSync,
  });

  final IptvChannelsState channels;
  final TextEditingController search;
  final ({int done, int total})? progress;
  final bool canSync;

  /// Whether the row draws the shared sync-all verb; false when the page's
  /// head line carries it.
  final bool syncOnToolbar;

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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.small.copyWith(color: colors.textMuted),
    );
    final field = TvInputField(
      controller: search,
      placeholder: t.iptv.searchChannels,
      semanticLabel: t.iptv.searchChannels,
      onChanged: (value) => ref.read(iptvChannelsProvider.notifier).setQuery(value),
    );
    final sync = syncOnToolbar
        ? DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            loading: progress != null,
            onPressed: canSync ? onSync : null,
            leading: const DsIcon(DsIcons.refreshCw, size: 15),
            child: Text(t.iptv.syncAll),
          )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
          return Row(
            spacing: DsSpace.s12,
            children: [
              scope,
              const Spacer(),
              count,
              SizedBox(width: 200, child: field),
              ?sync,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Row(
              spacing: DsSpace.s8,
              children: [
                scope,
                Flexible(child: count),
              ],
            ),
            Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(child: field),
                ?sync,
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The every-channel-or-favourites switch: the module's 44px content tabs,
/// announced as a tab bar; the table below follows at once.
final class _ScopeSegments extends ConsumerWidget {
  const _ScopeSegments({required this.scope});

  /// The scope the list is in now.
  final IptvChannelScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return SizedBox(
      height: 44,
      child: DsTabs<IptvChannelScope>(
        value: scope,
        onChanged: (next) => ref.read(iptvChannelsProvider.notifier).selectScope(next),
        semanticLabel: t.iptv.scopeLabel,
        style: _iptvScopeTabsStyle,
        tabs: [
          DsTab(value: IptvChannelScope.all, label: Text(t.iptv.scopeAll)),
          DsTab(value: IptvChannelScope.favourites, label: Text(t.iptv.scopeFavourites)),
        ],
      ),
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
        return IptvChannelHoverPreview(
          channel: channel,
          child: DsListRow(
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
          ),
        );
      },
    );
  }
}

/// A channel's logo and name, with its dial number under the name when it
/// has one and the browse setting asks for it. A pointer that rests on the
/// cell floats the channel itself beside the row, muted — the table has no
/// cover to play on, so the glance hangs here.
final class _ChannelNameCell extends StatelessWidget {
  const _ChannelNameCell({required this.channel, required this.showNumber});

  final IptvChannel channel;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final number = showNumber ? channel.number : null;
    return IptvChannelHoverPreview(
      channel: channel,
      child: Row(
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
      ),
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

/// The channels surface of an empty library: what the module is for, the
/// recommended sources one tap away, and the way to bring one's own list.
///
/// The first visit adds the default source by itself; this is what a viewer
/// sees while that runs, when it could not (no network), and after they
/// removed every source — never a dead end with a lone import button.
final class _StartView extends ConsumerWidget {
  const _StartView();

  Future<void> _add(BuildContext context, WidgetRef ref, IptvPreset preset) async {
    final t = context.t;
    final result = await ref.read(iptvPresetsProvider.notifier).add(preset);
    if (!context.mounted) return;
    if (result.isImported) {
      showDsToast(
        context: context,
        status: DsStatus.success,
        title: t.iptv.presetAddedToast(name: preset.nameIn(currentLanguageTag())),
      );
      if (result.id != null) unawaited(ref.read(iptvPresetsProvider.notifier).attachGuide(result.id!, preset: preset));
      return;
    }
    if (result.status == IptvImportStatus.cancelled) return;
    showDsToast(context: context, status: DsStatus.danger, title: iptvImportFailureWords(result, t));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final presets = ref.watch(iptvPresetsProvider);
    final controller = ref.read(iptvPresetsProvider.notifier);
    final tag = currentLanguageTag();
    final busy = presets.adding != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final inset = LiveWindow.pageInset(width);
        final columns = width >= LiveWindow.expanded ? 3 : (width >= LiveWindow.compact ? 2 : 1);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s24, inset, DsSpace.s32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: LiveWindow.content),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: DsSpace.s20,
                children: [
                  Row(
                    spacing: DsSpace.s16,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(16)),
                        child: Center(child: DsIcon(DsIcons.antenna, size: 26, color: colors.accentText)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: DsSpace.s4,
                          children: [
                            Text(t.iptv.emptyStartTitle, style: theme.typography.title.copyWith(color: colors.text)),
                            Text(
                              t.iptv.emptyStartDescription,
                              style: theme.typography.body.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (busy) const DsProgressBar(),
                  Text(t.iptv.presetSectionTitle, style: theme.typography.labelStrong.copyWith(color: colors.text)),
                  if (presets.presets.isEmpty)
                    Text(t.iptv.presetEmpty, style: theme.typography.body.copyWith(color: colors.textMuted))
                  else
                    _Grid(
                      columns: columns,
                      children: [
                        for (final preset in presets.presets)
                          IptvPresetCard(
                            preset: preset,
                            languageTag: tag,
                            added: controller.playlistOf(preset) != null,
                            builtin: builtinIptvPresets.any((entry) => entry.id == preset.id),
                            actionLabel: presets.adding == preset.id ? t.iptv.previewReading : null,
                            onPressed: busy ? null : () => unawaited(_add(context, ref, preset)),
                          ),
                      ],
                    ),
                  Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        onPressed: busy ? null : () => unawaited(runIptvPlaylistImport(context)),
                        leading: const DsIcon(DsIcons.plus, size: 16),
                        child: Text(t.iptv.emptyStartImportAction),
                      ),
                      DsButton(
                        variant: DsButtonVariant.ghost,
                        onPressed: busy ? null : () => unawaited(runIptvGuideImport(context)),
                        leading: const DsIcon(DsIcons.calendarClock, size: 16),
                        child: Text(t.iptv.importGuide),
                      ),
                      if (presets.deleted.isNotEmpty)
                        DsButton(
                          variant: DsButtonVariant.ghost,
                          onPressed: busy ? null : controller.restoreDefaults,
                          leading: const DsIcon(DsIcons.rotateCcw, size: 16),
                          child: Text(t.iptv.presetRestore),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [children] in rows of [columns], each row as tall as its tallest card.
final class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final row = children.sublist(start, (start + columns).clamp(0, children.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              for (final child in row) Expanded(child: child),
              for (var i = row.length; i < columns; i++) const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s12, children: rows);
  }
}
