import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart' show iptvRecentProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show iptvRemindersProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/pages/iptv_play_page.dart' show IptvPlayPage;
import 'package:pure_live/modules/iptv/views/iptv_channel_preview.dart';
import 'package:pure_live/modules/iptv/views/iptv_group_rail.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_dialog.dart';
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
  final FocusNode _searchFocus = FocusNode();

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
    _searchFocus.dispose();
    super.dispose();
  }

  /// The reference's Ctrl+F: the toolbar's search field takes the keyboard,
  /// stepping back from the sources surface if it was showing.
  void _focusSearch() {
    if (_view != IptvView.channels) setState(() => _view = IptvView.channels);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
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
    // The reference's startup card as a head verb: the newest watched
    // channel, one press away — opened only by the press, never autoplayed.
    // The first history entry whose channel still exists wins.
    IptvChannel? recentChannel;
    for (final entry in ref.watch(iptvRecentProvider)) {
      final channel = library.value?.channelById(entry.channelId);
      if (channel != null) {
        recentChannel = channel;
        break;
      }
    }
    void resumeRecent() {
      final channel = recentChannel;
      if (channel == null) return;
      unawaited(context.push(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel));
    }

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
                if (recentChannel != null)
                  DsListRow(
                    leading: const DsIcon(DsIcons.play, size: 16),
                    title: Text(t.iptv.resumeChannel(name: recentChannel.entry.name)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      resumeRecent();
                    },
                  ),
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
    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        // The reference's page shortcuts: the page's own refresh is the
        // shared sync-all, F lands in the channel search, O opens the
        // playlist import.
        if (canSyncAll)
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
              unawaited(syncAllIptvSources(context, ref)),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _focusSearch,
        if (!blocked) const SingleActivator(LogicalKeyboardKey.keyO, control: true): importPlaylist,
      },
      child: Focus(
        autofocus: true,
        child: Column(
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
                              if (recentChannel != null)
                                DsButton(
                                  variant: DsButtonVariant.secondary,
                                  size: DsSize.sm,
                                  onPressed: resumeRecent,
                                  leading: const DsIcon(DsIcons.play, size: 15),
                                  child: Text(t.iptv.resumeChannel(name: recentChannel.entry.name)),
                                ),
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
                IptvView.channels => _ChannelsView(
                  channels: channels,
                  search: _channelSearch,
                  searchFocus: _searchFocus,
                  syncOnToolbar: narrow,
                ),
                IptvView.sources => const IptvSourcesView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The channel surface: the library's groups down a first column (behind one
/// entry where the window has no room for a column), and over the open
/// group's channels a resource table — the scope and a name search above it.
/// The table fills the pane and pages in as it nears its end.
final class _ChannelsView extends ConsumerStatefulWidget {
  const _ChannelsView({
    required this.channels,
    required this.search,
    required this.searchFocus,
    required this.syncOnToolbar,
  });

  final IptvChannelsState channels;
  final TextEditingController search;

  /// The page's Ctrl+F lands here: the search field's focus stop, owned by
  /// the page so the shortcut can take the keyboard.
  final FocusNode searchFocus;

  /// Whether the shared sync-all verb rides the toolbar's own search line:
  /// the page folds the head verbs below the shell's toolbar breakpoint, and
  /// the folded head leaves the verb off its line, so this toolbar draws it.
  final bool syncOnToolbar;

  @override
  ConsumerState<_ChannelsView> createState() => _ChannelsViewState();
}

final class _ChannelsViewState extends ConsumerState<_ChannelsView> {
  final ScrollController _scroll = ScrollController();

  /// The channel the embedded player is on — the module's three-pane makes
  /// selection and playback one fact: a click both plays and marks.
  String? _selected;

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

  /// The three-pane's third column: the module's own player, embedded — a
  /// selection plays here, in place; nothing selected yet is a quiet door,
  /// not an error.
  Widget _embeddedPane() {
    final id = _selected;
    final channel = id == null ? null : ref.watch(iptvLibraryProvider).value?.channelById(id);
    if (channel == null) {
      return _PlayerIdle(broken: id != null);
    }
    return IptvPlayPage(channelId: channel.id, channel: channel, embedded: true);
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
                searchFocus: widget.searchFocus,
                progress: progress,
                canSync: canSync,
                syncOnToolbar: widget.syncOnToolbar,
                onSync: () => unawaited(syncAllIptvSources(context, ref)),
              ),
              if (hasGroups) IptvGroupEntry(filter: filter, onSelect: _selectGroup),
            ],
          ),
          child: _ChannelsList(channels: channels, scrollController: _scroll, onOpen: _open),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s16),
          // From the medium window up the module is the three-pane — the
          // groups move into the list pane's head where the column has no
          // room, and the player rides beside the list on every one of them.
          child: !LiveWindow.isCompact(width)
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s12,
                  children: [
                    if (rail) IptvGroupsColumn(filter: filter, onSelect: _selectGroup),
                    SizedBox(
                      width: LiveWindow.isExpanded(width) ? 340.0 : 300.0,
                      child: _ChannelListPane(
                        channels: channels,
                        slots: channels.slots,
                        search: widget.search,
                        searchFocus: widget.searchFocus,
                        scrollController: _scroll,
                        selected: _selected,
                        showGroupEntry: hasGroups && !rail,
                        filter: filter,
                        onSelectGroup: _selectGroup,
                        onSelect: (channel) => setState(() => _selected = channel.id),
                        onToggleFavourite: (channel) =>
                            unawaited(ref.read(iptvChannelsProvider.notifier).toggleFavorite(channel.id)),
                      ),
                    ),
                    Expanded(child: _embeddedPane()),
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
    required this.searchFocus,
    required this.progress,
    required this.canSync,
    required this.syncOnToolbar,
    required this.onSync,
  });

  final IptvChannelsState channels;
  final TextEditingController search;

  /// The search field's focus stop, owned by the page (its Ctrl+F names it).
  final FocusNode searchFocus;
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
    // The source the list walks: every playlist at once, or one — a menu,
    // because the names are the facts and a panel would be a second screen
    // for one choice.
    final playlists = ref.watch(iptvSourcesProvider).playlists;
    final sourceButton = playlists.length > 1
        ? DsMenuAnchor(
            semanticLabel: t.iptv.sourceLabel,
            items: [
              DsMenuItem(
                checked: channels.playlistId == null,
                label: Text(t.iptv.sourceAll),
                onPressed: () => ref.read(iptvChannelsProvider.notifier).selectPlaylist(null),
              ),
              for (final playlist in playlists)
                DsMenuItem(
                  leading: const DsIcon(DsIcons.server, size: 15),
                  checked: channels.playlistId == playlist.id,
                  label: Text(playlist.name),
                  onPressed: () => ref.read(iptvChannelsProvider.notifier).selectPlaylist(playlist.id),
                ),
            ],
            builder: (context, controller, _) {
              var current = t.iptv.sourceAll;
              for (final playlist in playlists) {
                if (playlist.id == channels.playlistId) current = playlist.name;
              }
              return DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: t.iptv.sourceLabel,
                leading: const DsIcon(DsIcons.server, size: 14),
                onPressed: controller.toggle,
                child: Text(current),
              );
            },
          )
        : null;
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
      focusNode: searchFocus,
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
              ?sourceButton,
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
                ?sourceButton,
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

/// The channels surface of an empty library: what the module is for and
/// the two ways to fill it. The reference's onboarding is this same shape —
/// centred, the module's mark, and a short pair of doors, nothing to
/// browse first and nothing to undo.
final class _StartView extends StatelessWidget {
  const _StartView();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s12,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(16)),
                child: Center(child: DsIcon(DsIcons.antenna, size: 26, color: colors.accentText)),
              ),
              Text(t.iptv.emptyStartTitle, style: theme.typography.title.copyWith(color: colors.text)),
              Text(
                t.iptv.emptyStartDescription,
                textAlign: TextAlign.center,
                style: theme.typography.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: DsSpace.s4),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s8,
                children: [
                  DsButton(
                    onPressed: () => unawaited(runIptvPlaylistImport(context)),
                    leading: const DsIcon(DsIcons.plus, size: 16),
                    child: Text(t.iptv.emptyStartImportAction),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    onPressed: () => unawaited(runIptvGuideImport(context)),
                    leading: const DsIcon(DsIcons.calendarClock, size: 16),
                    child: Text(t.iptv.importGuide),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three-pane's middle column: the module's channels as the reference's
/// own rows — mark, name with the dial number, what is on now under it, the
/// heart, and the tally on the row the player is showing. A click plays and
/// marks in one motion; the search and the scope tabs ride the pane's head.
final class _ChannelListPane extends ConsumerWidget {
  const _ChannelListPane({
    required this.channels,
    required this.slots,
    required this.search,
    required this.searchFocus,
    required this.scrollController,
    required this.selected,
    required this.onSelect,
    required this.onToggleFavourite,
    required this.filter,
    required this.onSelectGroup,
    this.showGroupEntry = false,
  });

  final IptvChannelsState channels;
  final Map<String, IptvProgrammeSlot> slots;
  final TextEditingController search;
  final FocusNode searchFocus;
  final ScrollController scrollController;
  final String? selected;
  final ValueChanged<IptvChannel> onSelect;
  final ValueChanged<IptvChannel> onToggleFavourite;

  /// The group picker rides the pane's head where the window has no room
  /// for the group column beside it.
  final bool showGroupEntry;
  final IptvGroupFilter filter;
  final ValueChanged<String?> onSelectGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final rows = channels.channels.take(channels.shown).toList(growable: false);
    final pane = IptvTablePanel(
      fill: true,
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          _ChannelsToolbar(
            channels: channels,
            search: search,
            searchFocus: searchFocus,
            progress: null,
            canSync: false,
            syncOnToolbar: false,
            onSync: () {},
          ),
          if (showGroupEntry) IptvGroupEntry(filter: filter, onSelect: onSelectGroup),
        ],
      ),
      child: rows.isEmpty
          ? _channelsEmptyView(context, channels)
          : ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
              itemCount: rows.length,
              separatorBuilder: (context, _) => const DsDivider(indent: 60),
              itemBuilder: (context, index) {
                final channel = rows[index];
                return IptvChannelTile(
                  channel: channel,
                  slot: slots[channel.id],
                  selected: selected == channel.id,
                  showNumber: browse.showChannelNumber,
                  groupLine: channels.selectedGroup == null ? iptvGroupLabel(t, iptvGroupKeyOf(channel)) : null,
                  onPlay: () => onSelect(channel),
                  onToggleFavourite: () => onToggleFavourite(channel),
                );
              },
            ),
    );
    return pane;
  }
}

/// The third column before anything plays: a quiet door, not an error.
final class _PlayerIdle extends StatelessWidget {
  const _PlayerIdle({required this.broken});

  /// The selection names a channel the library no longer holds — the words
  /// say the list is the way back, not that the module is broken.
  final bool broken;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return ColoredBox(
      color: theme.colors.overlay,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: DsSpace.s8,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: colors.accentTint, borderRadius: BorderRadius.circular(16)),
              child: Center(child: DsIcon(DsIcons.antenna, size: 26, color: colors.accentText)),
            ),
            Text(t.iptv.playerIdleTitle, style: theme.typography.title.copyWith(color: colors.text)),
            Text(
              t.iptv.playerIdleHint,
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
