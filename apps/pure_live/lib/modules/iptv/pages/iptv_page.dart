import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/tv/tv_input_field.dart' show TvInputField;

import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart'
    show IptvChannelOrder, iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_reminders.dart' show iptvRemindersProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/pages/iptv_play_page.dart' show IptvPlayPage;
import 'package:pure_live/modules/iptv/views/iptv_channel_preview.dart';
import 'package:pure_live/modules/iptv/views/iptv_group_rail.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_dialog.dart';
import 'package:pure_live/modules/iptv/views/iptv_panels.dart';
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

/// The IPTV module's entry page: the channel browser, one list.
///
/// The page's whole chrome is the two source pickers at its top-left — the
/// playlist the channel list reads, and the guide its programme line reads —
/// with the import and sync verbs folded into their menus. The channels
/// themselves are the reference's two panes: the library's groups down the
/// first column, and the channels of the open group as a resource table —
/// logo, group, what is on now with its progress, the favourite heart and
/// the player action. A window too narrow for the column keeps the same
/// group list behind one line over the table, and the table itself stacks
/// its rows instead of scrolling sideways.
final class IptvPage extends ConsumerStatefulWidget {
  /// The IPTV module's channels page.
  const IptvPage({super.key});

  @override
  ConsumerState<IptvPage> createState() => _IptvPageState();
}

final class _IptvPageState extends ConsumerState<IptvPage> {
  Timer? _slotRefresh;
  final TextEditingController _channelSearch = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The toolbar's word lands in the channel search in place. The listener
    // catches a word handed while the page is showing; the post-frame take
    // catches one handed as the page arrives.
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
    _channelSearch.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    ref.read(iptvChannelsProvider.notifier).setQuery(word);
  }

  @override
  void dispose() {
    _slotRefresh?.cancel();
    _channelSearch.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The reference's Ctrl+F: the toolbar's search field takes the keyboard.
  void _focusSearch() {
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
    void importPlaylist() => unawaited(runIptvPlaylistImport(context));
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    final canSyncAll = hasRemote && !blocked && sources.busy.isEmpty && epg.busy.isEmpty;
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
        child: _ChannelsView(channels: channels, search: _channelSearch, searchFocus: _searchFocus),
      ),
    );
  }
}

/// The channel surface: the library's groups down a first column (behind one
/// entry where the window has no room for a column), and over the open
/// group's channels a resource table — the scope and a name search above it.
/// The table fills the pane and pages in as it nears its end.
final class _ChannelsView extends ConsumerStatefulWidget {
  const _ChannelsView({required this.channels, required this.search, required this.searchFocus});

  final IptvChannelsState channels;
  final TextEditingController search;

  /// The page's Ctrl+F lands here: the search field's focus stop, owned by
  /// the page so the shortcut can take the keyboard.
  final FocusNode searchFocus;

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
      // The waiting face keeps the page's own gutter — a fixed 16 left the
      // skeleton proud of the loaded rows beside it on a wide window.
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LiveWindow.pageInset(MediaQuery.sizeOf(context).width),
          vertical: DsSpace.s16,
        ),
        child: const SkeletonRows(),
      );
    }
    if (channels.libraryCount == 0) {
      return const _StartView();
    }
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
              _ChannelsToolbar(channels: channels, search: widget.search, searchFocus: widget.searchFocus),
              if (hasGroups) IptvGroupEntry(filter: filter, onSelect: _selectGroup),
            ],
          ),
          child: _ChannelsList(channels: channels, scrollController: _scroll, onOpen: _open),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s16),
          // The page's whole chrome is the top-left source row — the
          // playlist and the guide the list reads, with the import and sync
          // verbs folded into their menus.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              const Align(alignment: AlignmentDirectional.centerStart, child: _IptvSourcePickers()),
              Expanded(
                // From the medium window up the module is the three-pane — the
                // groups move into the list pane's head where the column has no
                // room, and the player rides beside the list on every one of
                // them.
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The channel list pane's head row: the scope tabs and the name search.
/// The playlist picker and the sync verbs live in the page's top-left source
/// row; this line is the list's own two controls and nothing else.
final class _ChannelsToolbar extends ConsumerWidget {
  const _ChannelsToolbar({required this.channels, required this.search, required this.searchFocus});

  final IptvChannelsState channels;
  final TextEditingController search;

  /// The search field's focus stop, owned by the page (its Ctrl+F names it).
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final scope = _ScopeSegments(scope: channels.scope);
    // The list's order: the library's ranking or the alphabet — a menu,
    // the same two choices a settings pane would carry, said beside the
    // list they act on.
    final order = ref.watch(iptvBrowseSettingsProvider.select((settings) => settings.order));
    final orderButton = DsMenuAnchor(
      semanticLabel: t.iptv.sort,
      items: [
        DsMenuItem(
          checked: order == IptvChannelOrder.defaultOrder,
          label: Text(t.iptv.sortDefault),
          onPressed: () => ref.read(iptvBrowseSettingsProvider.notifier).setOrder(value: IptvChannelOrder.defaultOrder),
        ),
        DsMenuItem(
          checked: order == IptvChannelOrder.name,
          label: Text(t.iptv.sortByName),
          onPressed: () => ref.read(iptvBrowseSettingsProvider.notifier).setOrder(value: IptvChannelOrder.name),
        ),
      ],
      builder: (context, menuController, _) => DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        semanticLabel: t.iptv.sort,
        leading: const DsIcon(DsIcons.arrowDownUp, size: 14),
        onPressed: menuController.toggle,
        child: Text(order == IptvChannelOrder.name ? t.iptv.sortByName : t.iptv.sortDefault),
      ),
    );
    final field = TvInputField(
      controller: search,
      focusNode: searchFocus,
      placeholder: t.iptv.searchChannels,
      semanticLabel: t.iptv.searchChannels,
      onChanged: (value) => ref.read(iptvChannelsProvider.notifier).setQuery(value),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
          return Row(
            spacing: DsSpace.s12,
            children: [
              scope,
              orderButton,
              const Spacer(),
              SizedBox(width: 200, child: field),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Row(spacing: DsSpace.s8, children: [scope, orderButton]),
            field,
          ],
        );
      },
    );
  }
}

/// The page's top-left corner, its whole chrome: the playlist the channel
/// list reads and the guide its programme line reads — one menu each, with
/// the import verb (and the shared sync-all, on the playlist's menu) folded
/// under the same press. The page head they replace counted what the library
/// held; these name what it is open on, and the active picks travel with the
/// list.
final class _IptvSourcePickers extends ConsumerWidget {
  const _IptvSourcePickers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final channels = ref.watch(iptvChannelsProvider);
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    final blocked = sources.importing || epg.importing || sources.syncAll != null || !sources.ready || !epg.ready;
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    final canSyncAll = hasRemote && !blocked && sources.busy.isEmpty && epg.busy.isEmpty;

    void importPlaylist() => unawaited(runIptvPlaylistImport(context));
    void importGuide() => unawaited(runIptvGuideImport(context));

    // The open source's own name on the button; a list of one still picks
    // (a second import arrives under the first), so the menu never folds
    // away.
    var playlist = t.iptv.sourceAll;
    for (final source in sources.playlists) {
      if (source.id == channels.playlistId) playlist = source.name;
    }
    var guide = t.iptv.guideTitle;
    for (final source in epg.sources) {
      if (source.id == epg.activeId) guide = source.name;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        IptvPlaylistMenu(
          playlists: sources.playlists,
          activeId: channels.playlistId,
          currentLabel: playlist,
          loading: sources.syncAll != null,
          onSelect: (id) => ref.read(iptvChannelsProvider.notifier).selectPlaylist(id),
          extraItems: [
            DsMenuItem(
              leading: const DsIcon(DsIcons.plus, size: 16),
              label: Text(t.iptv.importPlaylist),
              onPressed: blocked ? null : importPlaylist,
            ),
            if (hasRemote)
              DsMenuItem(
                leading: const DsIcon(DsIcons.refreshCw, size: 16),
                label: Text(t.iptv.syncAll),
                onPressed: canSyncAll ? () => unawaited(syncAllIptvSources(context, ref)) : null,
              ),
          ],
        ),
        DsMenuAnchor(
          semanticLabel: t.iptv.guideTitle,
          items: [
            for (final source in epg.sources)
              DsMenuItem(
                leading: const DsIcon(DsIcons.calendarClock, size: 16),
                checked: source.id == epg.activeId,
                label: Text(source.name),
                onPressed: () => unawaited(ref.read(iptvEpgProvider.notifier).selectGuide(source)),
              ),
            if (epg.sources.isNotEmpty) const DsMenuDivider(),
            DsMenuItem(
              leading: const DsIcon(DsIcons.plus, size: 16),
              label: Text(t.iptv.importGuide),
              onPressed: blocked ? null : importGuide,
            ),
          ],
          builder: (context, controller, _) => DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            semanticLabel: t.iptv.guideTitle,
            trailing: const DsIcon(DsIcons.chevronDown, size: 14),
            onPressed: controller.toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(guide, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ],
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
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final rows = channels.channels.take(channels.shown).toList(growable: false);
    // The stacked list answers the same three empties the three-pane's
    // column does — a search that matched nothing, a favourites scope with
    // nothing in it, a library with no channels at all.
    if (rows.isEmpty) return _channelsEmptyView(context, channels);
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      itemCount: rows.length,
      separatorBuilder: (context, _) => const DsDivider(),
      itemBuilder: (context, index) {
        final channel = rows[index];
        // The stacked list wears the module's one channel row — the same
        // tile the desktop pane draws, so the two surfaces never drift: a
        // press plays, the heart sits in its trailing slot, and the row
        // names its group only when the list spans several.
        return IptvChannelHoverPreview(
          channel: channel,
          child: IptvChannelTile(
            channel: channel,
            slot: browse.showProgrammeLine ? channels.slots[channel.id] : null,
            selected: false,
            showNumber: browse.showChannelNumber,
            groupLine: channels.selectedGroup != null ? null : _groupOf(t, channel),
            onPlay: () => onOpen(channel),
            onToggleFavourite: () => unawaited(ref.read(iptvChannelsProvider.notifier).toggleFavorite(channel.id)),
          ),
        );
      },
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
    return Center(
      child: DsEmptyState(
        icon: const DsIcon(DsIcons.antenna),
        title: Text(t.iptv.emptyStartTitle),
        description: Text(t.iptv.emptyStartDescription),
        actions: [
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
          _ChannelsToolbar(channels: channels, search: search, searchFocus: searchFocus),
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
                final row = IptvChannelTile(
                  channel: channel,
                  slot: slots[channel.id],
                  selected: selected == channel.id,
                  showNumber: browse.showChannelNumber,
                  groupLine: channels.selectedGroup == null ? iptvGroupLabel(t, iptvGroupKeyOf(channel)) : null,
                  onPlay: () => onSelect(channel),
                  onToggleFavourite: () => onToggleFavourite(channel),
                );
                // The glance rides the rows the pane is not already playing:
                // the selected channel's own stream runs in the player
                // beside the list, and a second window of it says nothing.
                return selected == channel.id ? row : IptvChannelHoverPreview(channel: channel, child: row);
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
    return ColoredBox(
      color: DsTheme.of(context).colors.overlay,
      child: Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.antenna),
          title: Text(
            // The selection named a channel the library dropped: that is
            // said outright, not with the never-picked words.
            broken ? t.iptv.playerChannelMissing : t.iptv.playerIdleTitle,
          ),
          description: Text(t.iptv.playerIdleHint),
        ),
      ),
    );
  }
}
