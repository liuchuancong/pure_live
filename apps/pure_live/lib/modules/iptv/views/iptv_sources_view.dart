import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/tv/tv_input_field.dart' show TvInputField;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvPlaylistIsRemote;
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_presets_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_dialog.dart' show runIptvGuideImport, runIptvPlaylistImport;
import 'package:pure_live/modules/iptv/views/iptv_import_preview_pane.dart' show iptvImportFailureWords;
import 'package:pure_live/modules/iptv/views/iptv_panels.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// What the resources table shows: everything, only playlists or only
/// guides.
enum _SourceFilter { all, playlists, guides }

/// The preference the viewer's source order is kept under: a string list of
/// `p:<playlist id>` and `g:<guide id>` keys, first shown first.
const String _sourceOrderPref = 'iptv.sources.order';

/// The kind filter's tab bar: 44 tall, starting flush with the strip that
/// holds it, and no hairline under the row — the panel's own rule below the
/// toolbar already draws that line, the measure the music module's feed
/// tabs fixed for the same 44px bar shape.
const DsTabsStyle _sourceFilterTabsStyle = DsTabsStyle(
  height: 44,
  padding: EdgeInsets.zero,
  dividerColor: Color(0x00000000),
);

/// The IPTV source manager, in the reference's resource-panel shape: the
/// 44px head that names the surface, counts what it holds and carries the
/// page's verbs (import, the shared sync-all, the order editor), then the
/// guide in use, and one table over the playlists and guides with a kind
/// filter, a search, per-row sync/delete and the guide switches.
///
/// The update *schedule* — the interval, the bulk switch, how many guides it
/// covers — is not here. It is one setting with one home, Settings → IPTV;
/// this page only carries the commands that act on the sources it lists.
///
/// The order of the table is the viewer's own: "edit order" swaps it for a
/// reorder card with a drag grip and arrow controls, keeps the result as a
/// draft until "save order", and writes the draft to the store then. Cancel
/// leaves the stored order exactly as it was.
final class IptvSourcesView extends ConsumerStatefulWidget {
  /// The source manager shown on the IPTV page's sources tab.
  const IptvSourcesView({super.key});

  @override
  ConsumerState<IptvSourcesView> createState() => _IptvSourcesViewState();
}

final class _IptvSourcesViewState extends ConsumerState<IptvSourcesView> {
  final TextEditingController _search = TextEditingController();
  _SourceFilter _filter = _SourceFilter.all;
  String _query = '';
  List<String> _savedOrder = const [];
  List<Object> _draft = const [];
  List<String> _draftStart = const [];
  bool _sorting = false;
  bool _savingOrder = false;

  @override
  void initState() {
    super.initState();
    try {
      _savedOrder = StoragePrefs.getStringList(_sourceOrderPref) ?? const [];
    } on Object {
      // A closed store starts with the natural order.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String title, {String? description, bool danger = false}) {
    showDsToast(
      context: context,
      title: title,
      description: description,
      status: danger ? DsStatus.danger : DsStatus.success,
    );
  }

  // -- Sync ----------------------------------------------------------------

  Future<void> _syncPlaylist(IptvPlaylist playlist) async {
    final result = await ref.read(iptvSourcesProvider.notifier).syncPlaylist(playlist);
    if (!mounted || result == null) return;
    final t = context.t;
    if (result.isImported) {
      _toast(t.iptv.synced(name: playlist.name));
    } else {
      _toast(t.iptv.syncFailed(name: playlist.name), description: iptvImportFailureWords(result, t), danger: true);
    }
  }

  Future<void> _syncGuide(EpgSource source) async {
    final result = await ref.read(iptvEpgProvider.notifier).syncSource(source);
    if (!mounted || result == null) return;
    final t = context.t;
    if (result.isImported) {
      _toast(t.iptv.synced(name: source.name));
    } else {
      _toast(t.iptv.syncFailed(name: source.name), description: iptvImportFailureWords(result, t), danger: true);
    }
  }

  // -- Delete --------------------------------------------------------------

  Future<void> _deletePlaylist(IptvPlaylist playlist) async {
    final t = context.t;
    final impact = ref.read(iptvSourcesProvider.notifier).deletionImpact(playlist);
    final presets = ref.read(iptvPresetsProvider);
    final presetId = presets.added.entries.where((entry) => entry.value == playlist.id).firstOrNull?.key;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.deletePlaylistTitle,
      // The confirmation says what goes with the record before the stars go,
      // and a built-in source says it will not come back on its own.
      description: [
        t.iptv.deletePlaylistMessage(name: playlist.name, count: playlist.channelCount),
        if (impact.channels > 0)
          t.iptv.deleteImpactNote(channels: impact.channels, favourites: impact.favourites)
        else
          t.iptv.deleteImpactNone,
        if (presetId != null) t.iptv.deletePresetNote,
      ].join('\n'),
      confirmLabel: t.iptv.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash),
    );
    if (!confirmed || !mounted) return;
    final deleted = await ref.read(iptvSourcesProvider.notifier).deletePlaylist(playlist);
    if (!mounted) return;
    if (deleted && presetId != null) ref.read(iptvPresetsProvider.notifier).forget(presetId);
    _toast(deleted ? t.iptv.deleted(name: playlist.name) : t.iptv.sourceChanged, danger: !deleted);
  }

  Future<void> _deleteGuide(EpgSource source) async {
    final t = context.t;
    final inUse = ref.read(iptvEpgProvider).activeId == source.id;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.deleteGuideTitle,
      description: [t.iptv.deleteGuideMessage(name: source.name), if (inUse) t.iptv.deleteActiveGuideNote].join('\n'),
      confirmLabel: t.iptv.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash),
    );
    if (!confirmed || !mounted) return;
    final deleted = await ref.read(iptvEpgProvider.notifier).deleteSource(source);
    if (!mounted) return;
    _toast(deleted ? t.iptv.deleted(name: source.name) : t.iptv.sourceChanged, danger: !deleted);
  }

  // -- Guide selection and updates ----------------------------------------

  Future<void> _chooseGuide() async {
    final t = context.t;
    final epg = ref.read(iptvEpgProvider);
    final chosen = await showDsDialog<EpgSource>(
      context: context,
      builder: (dialogContext) => DsDialog(
        title: Text(t.iptv.chooseGuide),
        style: const DsDialogStyle(width: 480),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.iptv.activeGuideDescription),
            for (final source in epg.sources)
              DsListRow(
                leading: const DsIcon(DsIcons.calendarClock),
                title: Text(source.name),
                description: Text(source.source),
                selected: source.id == epg.activeId,
                trailing: source.id == epg.activeId ? const DsIcon(DsIcons.check, size: 16) : null,
                onPressed: () => Navigator.of(dialogContext).pop(source),
              ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    await ref.read(iptvEpgProvider.notifier).selectGuide(chosen);
    if (!mounted) return;
    _toast(context.t.iptv.guideSelected(name: chosen.name));
  }

  Future<void> _setAutoUpdate(EpgSource source, bool value) =>
      ref.read(iptvEpgProvider.notifier).setAutoUpdate(source, value: value);

  // -- Order ---------------------------------------------------------------

  static String _keyOf(Object item) => item is IptvPlaylist ? 'p:${item.id}' : 'g:${(item as EpgSource).id}';

  /// [all] in the viewer's stored order, with sources the order does not
  /// name kept after the named ones in their natural (playlist, guide)
  /// order.
  List<Object> _ordered(List<Object> all) {
    if (_savedOrder.isEmpty) return all;
    final rank = {for (final (index, key) in _savedOrder.indexed) key: index};
    final natural = {for (final (index, item) in all.indexed) _keyOf(item): index};
    return [...all]..sort((a, b) {
      final aKey = _keyOf(a);
      final bKey = _keyOf(b);
      final aRank = rank[aKey];
      final bRank = rank[bKey];
      if (aRank != null || bRank != null) {
        if (aRank == null) return 1;
        if (bRank == null) return -1;
        if (aRank != bRank) return aRank.compareTo(bRank);
      }
      return (natural[aKey] ?? 0).compareTo(natural[bKey] ?? 0);
    });
  }

  void _startSorting(List<Object> ordered) {
    if (ordered.isEmpty) return;
    setState(() {
      _sorting = true;
      _draft = [...ordered];
      _draftStart = [for (final item in ordered) _keyOf(item)];
    });
  }

  void _moveDraft(int from, int to) {
    if (from < 0 || from >= _draft.length) return;
    final target = to.clamp(0, _draft.length - 1);
    if (target == from) return;
    setState(() {
      final item = _draft.removeAt(from);
      _draft.insert(target, item);
    });
  }

  void _cancelSorting() {
    setState(() {
      _sorting = false;
      _draft = const [];
      _draftStart = const [];
    });
  }

  Future<void> _saveOrder() async {
    if (_savingOrder || !_dirty) return;
    final keys = [for (final item in _draft) _keyOf(item)];
    setState(() => _savingOrder = true);
    try {
      await StoragePrefs.setStringList(_sourceOrderPref, keys);
    } on Object {
      // The new order still holds for this run; the next boot falls back.
    }
    if (!mounted) return;
    setState(() {
      _savedOrder = keys;
      _savingOrder = false;
      _sorting = false;
      _draft = const [];
      _draftStart = const [];
    });
    _toast(context.t.iptv.orderSaved);
  }

  bool get _dirty {
    if (_draft.length != _draftStart.length) return true;
    for (var index = 0; index < _draft.length; index++) {
      if (_keyOf(_draft[index]) != _draftStart[index]) return true;
    }
    return false;
  }

  // -- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    if (!sources.ready || !epg.ready) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    }
    final active = _activeOf(epg);
    final round = sources.syncAll;
    final blocked = sources.importing || epg.importing || round != null;
    final settingsBlocked = blocked || epg.busy.isNotEmpty || sources.busy.isNotEmpty;
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    final canSync = hasRemote && !blocked && epg.busy.isEmpty && sources.busy.isEmpty;
    final all = _ordered(<Object>[...sources.playlists, ...epg.sources]);
    if (_sorting) {
      return _buildSorting(context);
    }
    final rows = [
      for (final item in all)
        if (_keeps(item) && _matches(item, _query)) item,
    ];
    // The head's three verbs, the reference's 导入 / 全部同步 / 排序 line.
    // One import entry stands over the playlist and guide flows, so the
    // row keeps the mockup's three actions and the toolbar below holds
    // nothing but the filters.
    final actions = [
      DsMenuAnchor(
        semanticLabel: t.iptv.importAction,
        items: [
          DsMenuItem(
            leading: const DsIcon(DsIcons.plus),
            label: Text(t.iptv.importPlaylist),
            onPressed: blocked ? null : () => unawaited(runIptvPlaylistImport(context)),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.calendarClock),
            label: Text(t.iptv.importGuide),
            onPressed: blocked ? null : () => unawaited(runIptvGuideImport(context)),
          ),
        ],
        builder: (context, controller, _) => DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          onPressed: blocked ? null : controller.toggle,
          leading: const DsIcon(DsIcons.plus, size: 15),
          child: Text(t.iptv.importAction),
        ),
      ),
      DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        loading: round != null,
        onPressed: canSync ? () => unawaited(syncAllIptvSources(context, ref)) : null,
        leading: const DsIcon(DsIcons.refreshCw, size: 15),
        child: Text(t.iptv.syncAll),
      ),
      DsButton(
        variant: DsButtonVariant.secondary,
        size: DsSize.sm,
        onPressed: all.isNotEmpty ? () => _startSorting(all) : null,
        leading: const DsIcon(DsIcons.listOrdered, size: 15),
        child: Text(t.iptv.editOrder),
      ),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          IptvPageHead(
            title: t.iptv.sourcesManager,
            description: t.iptv.sourcesSummary(playlists: sources.playlists.length, guides: epg.sources.length),
            actions: actions,
          ),
          _ActiveGuideCard(
            active: active,
            canChoose: epg.sources.isNotEmpty && !settingsBlocked,
            onChoose: () => unawaited(_chooseGuide()),
          ),
          if (round case final progress?) _SyncStrip(done: progress.done, total: progress.total),
          IptvTablePanel(
            toolbar: _SourcesToolbar(
              filter: _filter,
              onFilter: (next) => setState(() => _filter = next),
              count: rows.length,
              search: _search,
              onQuery: (value) => setState(() => _query = value),
            ),
            child: _SourcesTable(
              rows: rows,
              actions: _SourcesActions(
                activeId: epg.activeId,
                channelCounts: epg.channelCounts,
                blocked: settingsBlocked,
                sourceBusy: sources.busy,
                guideBusy: epg.busy,
                presetPlaylists: ref.watch(iptvPresetsProvider.select((state) => state.added.values.toSet())),
                syncPlaylist: (playlist) => unawaited(_syncPlaylist(playlist)),
                syncGuide: (source) => unawaited(_syncGuide(source)),
                deletePlaylist: (playlist) => unawaited(_deletePlaylist(playlist)),
                deleteGuide: (source) => unawaited(_deleteGuide(source)),
                autoUpdate: (source, value) => unawaited(_setAutoUpdate(source, value)),
              ),
              emptyView: _emptyView(context, sources, epg),
            ),
          ),
        ],
      ),
    );
  }

  /// The edit-order card: the draft as a draggable list with arrow controls,
  /// a draft notice and the cancel/save pair. It covers the settings cards
  /// while it is open, so only the thing being ordered is on screen.
  Widget _buildSorting(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final dirty = _dirty;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
      child: IptvTablePanel(
        toolbar: Row(
          spacing: DsSpace.s8,
          children: [
            DsIcon(DsIcons.listOrdered, size: theme.sizes.iconSm, color: colors.textMuted),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    t.iptv.orderTitle,
                    style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                  ),
                  Text(t.iptv.orderHint, style: theme.typography.small.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_draft.isEmpty)
              Padding(
                padding: const EdgeInsets.all(DsSpace.s24),
                child: Center(
                  child: DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.noSourcesTitle)),
                ),
              )
            else
              DsReorderableList(
                shrinkWrap: true,
                defaultHandles: false,
                padding: EdgeInsets.zero,
                itemCount: _draft.length,
                onReorder: _moveDraft,
                itemBuilder: (context, index) => _SortRow(
                  key: ValueKey(_keyOf(_draft[index])),
                  item: _draft[index],
                  last: index == _draft.length - 1,
                  onMoveTop: index > 0 ? () => _moveDraft(index, 0) : null,
                  onMoveUp: index > 0 ? () => _moveDraft(index, index - 1) : null,
                  onMoveDown: index < _draft.length - 1 ? () => _moveDraft(index, index + 1) : null,
                  onMoveBottom: index < _draft.length - 1 ? () => _moveDraft(index, _draft.length - 1) : null,
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  if (dirty) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.warning.signal),
                    ),
                    Flexible(
                      child: Text(
                        t.iptv.orderDraft,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.small.copyWith(color: colors.warning.text),
                      ),
                    ),
                  ],
                  const Spacer(),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: _savingOrder ? null : _cancelSorting,
                    child: Text(t.common.cancel),
                  ),
                  DsButton(
                    size: DsSize.sm,
                    loading: _savingOrder,
                    onPressed: dirty && !_savingOrder ? () => unawaited(_saveOrder()) : null,
                    child: Text(t.iptv.saveOrder),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _keeps(Object item) => switch (_filter) {
    _SourceFilter.all => true,
    _SourceFilter.playlists => item is IptvPlaylist,
    _SourceFilter.guides => item is EpgSource,
  };

  bool _matches(Object item, String query) {
    final word = query.trim().toLowerCase();
    if (word.isEmpty) return true;
    final name = item is IptvPlaylist ? item.name : (item as EpgSource).name;
    final address = item is IptvPlaylist ? item.url ?? '' : (item as EpgSource).source;
    final format = item is IptvPlaylist ? _playlistBadge(item) : _guideBadge(item as EpgSource);
    return name.toLowerCase().contains(word) ||
        address.toLowerCase().contains(word) ||
        format.toLowerCase().contains(word);
  }

  Widget _emptyView(BuildContext context, IptvSourcesState sources, IptvEpgState epg) {
    final t = context.t;
    if (_query.trim().isNotEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noSourceMatch)),
      );
    }
    if (_filter == _SourceFilter.playlists && sources.playlists.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.list),
          title: Text(t.iptv.noPlaylistsTitle),
          description: Text(t.iptv.noPlaylistsDescription),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(runIptvPlaylistImport(context)),
              child: Text(t.iptv.importPlaylist),
            ),
          ],
        ),
      );
    }
    if (_filter == _SourceFilter.guides && epg.sources.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.calendarClock),
          title: Text(t.iptv.noGuidesTitle),
          description: Text(t.iptv.epgEmpty),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(runIptvGuideImport(context)),
              child: Text(t.iptv.importGuide),
            ),
          ],
        ),
      );
    }
    if (sources.playlists.isEmpty && epg.sources.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.list),
          title: Text(t.iptv.noSourcesTitle),
          description: Text(t.iptv.noSourcesDescription),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(runIptvPlaylistImport(context)),
              child: Text(t.iptv.importPlaylist),
            ),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(runIptvGuideImport(context)),
              child: Text(t.iptv.importGuide),
            ),
          ],
        ),
      );
    }
    return Center(
      child: DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noSourceMatch)),
    );
  }

  static EpgSource? _activeOf(IptvEpgState epg) {
    for (final source in epg.sources) {
      if (source.id == epg.activeId) return source;
    }
    return null;
  }
}

/// The guide in use, with the picker that changes it. This is the one thing
/// on the page that reads as a settings card, and it is a management action
/// over the source list rather than a schedule — so it stays here.
final class _ActiveGuideCard extends StatelessWidget {
  const _ActiveGuideCard({required this.active, required this.canChoose, required this.onChoose});

  final EpgSource? active;
  final bool canChoose;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return _SettingCard(
      title: t.iptv.activeGuideTitle,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  active?.name ?? t.iptv.activeGuideNone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTheme.of(context).typography.body
                      .copyWith(fontWeight: FontWeight.w600, color: DsTheme.colorsOf(context).text),
                ),
                if (active != null)
                  Text(
                    active!.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textSubtle),
                  ),
              ],
            ),
          ),
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: canChoose ? onChoose : null,
            child: Text(t.iptv.select),
          ),
        ],
      ),
    );
  }
}

/// The reference's setting card: a title row over a hairline, then the
/// card's controls.
final class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsCard(
      style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Text(
            title,
            style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
          ),
          const DsDivider(),
          child,
        ],
      ),
    );
  }
}

/// The sync round's progress under the guide card, while one runs.
final class _SyncStrip extends StatelessWidget {
  const _SyncStrip({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(DsSpace.s12),
      decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          Text(
            t.iptv.syncAllRunning(done: done, total: total),
            style: theme.typography.body.copyWith(color: colors.text),
          ),
          Expanded(
            child: DsProgressBar(value: total == 0 ? null : done / total, semanticLabel: t.iptv.syncAll),
          ),
        ],
      ),
    );
  }
}

/// The resources table's toolbar: the kind filter as the module's 44px tab
/// bar, the visible count and the search. The page's verbs — import, sync
/// all, edit order — live in the head row above, so this bar only narrows
/// the list.
final class _SourcesToolbar extends StatelessWidget {
  const _SourcesToolbar({
    required this.filter,
    required this.onFilter,
    required this.count,
    required this.search,
    required this.onQuery,
  });

  final _SourceFilter filter;
  final ValueChanged<_SourceFilter> onFilter;
  final int count;
  final TextEditingController search;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tabs = DsTabs<_SourceFilter>(
      value: filter,
      onChanged: onFilter,
      style: _sourceFilterTabsStyle,
      semanticLabel: t.iptv.viewLabel,
      tabs: [
        DsTab(value: _SourceFilter.all, label: Text(t.iptv.filterAll)),
        DsTab(value: _SourceFilter.playlists, label: Text(t.iptv.filterPlaylists)),
        DsTab(value: _SourceFilter.guides, label: Text(t.iptv.filterGuides)),
      ],
    );
    final countText = Text(
      t.iptv.sourceCount(count: count),
      style: theme.typography.small.copyWith(color: colors.textMuted),
    );
    final field = TvInputField(
      controller: search,
      placeholder: t.iptv.searchSources,
      semanticLabel: t.iptv.searchSources,
      onChanged: onQuery,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
          return Row(
            spacing: DsSpace.s12,
            children: [
              Expanded(child: tabs),
              countText,
              SizedBox(width: 200, child: field),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [tabs, countText, field],
        );
      },
    );
  }
}

/// Below this the resources table cannot hold its columns. The five a medium
/// window keeps need 200 + 76 + 120 + 96 + 84 plus the row's own 32 px of
/// padding = 608, and the format column adds another 96. A sideways-scrolling
/// table parks the update switch and the delete action off screen, and the
/// kit's card fallback is one "label value" line per column at a single
/// line's height while a source is three lines (name, stats, address), so the
/// narrow form is defined here instead.
const double _sourcesTableMinWidth = 760;

/// The playlists and guides: one table in a window wide enough for its
/// columns, stacked rows in a narrow one. The same fields and the same
/// actions either way, read from one [_SourcesActions].
final class _SourcesTable extends StatelessWidget {
  const _SourcesTable({required this.rows, required this.actions, required this.emptyView});

  final List<Object> rows;
  final _SourcesActions actions;
  final Widget emptyView;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = theme.typography.small.copyWith(color: colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _sourcesTableMinWidth) {
          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.s32),
              child: emptyView,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in rows.indexed) ...[
                if (index > 0) const DsDivider(),
                _SourceRow(item: item, actions: actions),
              ],
            ],
          );
        }
        // The format is a hint about the address every row already shows; it
        // gets a column of its own only in a window wide enough to pay for
        // one, and is read inline on the address line otherwise.
        final showFormat = LiveWindow.isExpanded(constraints.maxWidth);
        return DsTable<Object>(
          semanticLabel: t.iptv.viewSources,
          rows: rows,
          rowKey: _SourcesActions.rowKey,
          columns: [
            DsTableColumn(
              id: 'name',
              label: t.iptv.colName,
              value: actions.name,
              width: const DsTableColumnWidth.flex(2, 200),
              cell: (context, item) => _SourceNameCell(item: item, actions: actions, inlineFormat: !showFormat),
            ),
            if (showFormat)
              DsTableColumn(
                id: 'format',
                label: t.iptv.colFormat,
                value: actions.format,
                width: const DsTableColumnWidth.fixed(96),
                cell: (context, item) => DsBadge(dot: false, label: Text(actions.format(item))),
              ),
            DsTableColumn(
              id: 'channels',
              label: t.iptv.colChannel,
              value: actions.channelCount,
              width: const DsTableColumnWidth.fixed(76),
              numeric: true,
              cell: (context, item) =>
                  Text(iptvNumber(actions.channelCount(item)), style: theme.typography.numeric(meta)),
            ),
            DsTableColumn(
              id: 'updated',
              label: t.iptv.colUpdated,
              value: (item) => actions.updated(item)?.millisecondsSinceEpoch ?? 0,
              width: const DsTableColumnWidth.flex(1, 120),
              cell: (context, item) => Text(
                _stamp(actions.updated(item)) ?? t.iptv.neverUpdated,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ),
            DsTableColumn(
              id: 'auto',
              label: t.iptv.colAutoUpdate,
              width: const DsTableColumnWidth.fixed(96),
              alignment: DsTableCellAlignment.center,
              cell: actions.autoCell,
            ),
            DsTableColumn(
              id: 'actions',
              label: t.iptv.colActions,
              width: const DsTableColumnWidth.fixed(84),
              alignment: DsTableCellAlignment.center,
              cell: actions.rowActions,
            ),
          ],
          style: iptvTableStyle(context),
          emptyView: emptyView,
        );
      },
    );
  }
}

/// What a source row can do and the state that decides whether it may do it
/// now, plus the per-item reads both forms of the list need. One object
/// shared by the table's cells and the stacked rows, so the two forms of the
/// same list cannot drift apart.
final class _SourcesActions {
  const _SourcesActions({
    required this.activeId,
    required this.channelCounts,
    required this.blocked,
    required this.sourceBusy,
    required this.guideBusy,
    required this.syncPlaylist,
    required this.syncGuide,
    required this.deletePlaylist,
    required this.deleteGuide,
    required this.autoUpdate,
    this.presetPlaylists = const {},
  });

  final String? activeId;
  final Map<String, int> channelCounts;
  final bool blocked;
  final Set<String> sourceBusy;
  final Set<String> guideBusy;
  final ValueChanged<IptvPlaylist> syncPlaylist;
  final ValueChanged<EpgSource> syncGuide;
  final ValueChanged<IptvPlaylist> deletePlaylist;
  final ValueChanged<EpgSource> deleteGuide;
  // The switch reports its own on/off; a named flag would only rename it.
  // ignore: avoid_positional_boolean_parameters
  final void Function(EpgSource source, bool value) autoUpdate;

  /// The ids of the playlists a recommended source became.
  final Set<String> presetPlaylists;

  /// Whether [item] is a playlist a recommended source became.
  bool isPreset(Object item) => item is IptvPlaylist && presetPlaylists.contains(item.id);

  static String rowKey(Object item) => item is IptvPlaylist ? 'p:${item.id}' : 'g:${(item as EpgSource).id}';

  String name(Object item) => item is IptvPlaylist ? item.name : (item as EpgSource).name;

  String address(Object item) => item is IptvPlaylist ? (item.url ?? '') : (item as EpgSource).source;

  String format(Object item) => item is IptvPlaylist ? _playlistBadge(item) : _guideBadge(item as EpgSource);

  DateTime? updated(Object item) => item is IptvPlaylist ? item.importedAt : (item as EpgSource).lastRefresh;

  int channelCount(Object item) =>
      item is IptvPlaylist ? item.channelCount : channelCounts[(item as EpgSource).id] ?? 0;

  bool isRemote(Object item) => item is IptvPlaylist ? iptvPlaylistIsRemote(item) : (item as EpgSource).isRemote;

  bool isBusy(Object item) => sourceBusy.contains(rowKey(item)) || guideBusy.contains(rowKey(item));

  bool isInUse(Object item) => item is EpgSource && item.id == activeId;

  /// The row's sync and delete pair; a local source has nothing to sync.
  Widget rowActions(BuildContext context, Object item) {
    final t = context.t;
    final busy = isBusy(item);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRemote(item))
          IptvIconAction(
            icon: DsIcons.refreshCw,
            label: t.iptv.sync,
            busy: busy,
            onPressed: blocked && !busy ? null : () => sync(item),
          ),
        IptvIconAction(
          icon: DsIcons.trash,
          label: t.iptv.delete,
          destructive: true,
          onPressed: blocked || busy ? null : () => delete(item),
        ),
      ],
    );
  }

  void sync(Object item) {
    if (item is IptvPlaylist) {
      syncPlaylist(item);
    } else {
      syncGuide(item as EpgSource);
    }
  }

  void delete(Object item) {
    if (item is IptvPlaylist) {
      deletePlaylist(item);
    } else {
      deleteGuide(item as EpgSource);
    }
  }

  /// The guide's own update switch, or null for a row the schedule does not
  /// cover.
  Widget? autoSwitch(BuildContext context, Object item) {
    if (item is! EpgSource || !item.isRemote) return null;
    final busy = guideBusy.contains(rowKey(item));
    return DsSwitch(
      value: item.autoUpdate,
      onChanged: blocked || busy ? null : (value) => autoUpdate(item, value),
      semanticLabel: context.t.iptv.autoUpdate,
    );
  }

  /// The auto column: the switch, or the dash for a row without one.
  Widget autoCell(BuildContext context, Object item) {
    return autoSwitch(context, item) ??
        Text('—', style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted));
  }
}

/// One source in the stacked form: the kind tile, the name with the badges
/// the table gives it, one line of stats, the address it came from, and the
/// update switch and actions the table keeps in their own columns.
final class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.item, required this.actions});

  final Object item;
  final _SourcesActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final address = actions.address(item);
    final stats = [
      actions.format(item),
      t.iptv.channelCount(count: actions.channelCount(item)),
      _stamp(actions.updated(item)) ?? t.iptv.neverUpdated,
    ].join(' · ');
    final auto = actions.autoSwitch(context, item);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s12,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: colors.control,
              borderRadius: BorderRadius.circular(theme.radii.control(40)),
            ),
            child: DsIcon(
              item is IptvPlaylist ? DsIcons.list : DsIcons.calendarClock,
              size: theme.sizes.iconSm,
              color: colors.textMuted,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Row(
                  spacing: DsSpace.s6,
                  children: [
                    Flexible(
                      child: Text(
                        actions.name(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                      ),
                    ),
                    DsBadge(
                      dot: false,
                      label: Text(actions.isRemote(item) ? t.iptv.networkTag : t.iptv.localTag),
                      icon: DsIcon(actions.isRemote(item) ? DsIcons.globe : DsIcons.fileText, size: 12),
                    ),
                    if (actions.isInUse(item)) DsBadge(dot: false, label: Text(t.iptv.inUse), status: DsStatus.info),
                  ],
                ),
                Text(
                  stats,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.textMuted),
                ),
                if (address.isNotEmpty)
                  _SourceAddressLine(text: address, address: address, remote: actions.isRemote(item)),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: DsSpace.s4,
            children: [?auto, actions.rowActions(context, item)],
          ),
        ],
      ),
    );
  }
}

/// A row's name, its local/network origin, the active-guide mark and the
/// address it came from — with the format read inline on the address line
/// when the table has no column for it.
final class _SourceNameCell extends StatelessWidget {
  const _SourceNameCell({required this.item, required this.actions, required this.inlineFormat});

  final Object item;
  final _SourcesActions actions;
  final bool inlineFormat;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final remote = actions.isRemote(item);
    final address = actions.address(item);
    final line = address.isEmpty
        ? actions.format(item)
        : (inlineFormat ? '${actions.format(item)} · $address' : address);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          spacing: DsSpace.s6,
          children: [
            Flexible(
              child: Text(
                actions.name(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
              ),
            ),
            DsBadge(
              dot: false,
              label: Text(remote ? t.iptv.networkTag : t.iptv.localTag),
              icon: DsIcon(remote ? DsIcons.globe : DsIcons.fileText, size: 12),
            ),
            if (actions.isPreset(item))
              DsBadge(
                dot: false,
                status: DsStatus.success,
                label: Text(t.iptv.sourceBuiltinTag),
                icon: const DsIcon(DsIcons.sparkles, size: 12),
              ),
            if (actions.isInUse(item)) DsBadge(dot: false, label: Text(t.iptv.inUse), status: DsStatus.info),
          ],
        ),
        if (inlineFormat || address.isNotEmpty)
          _SourceAddressLine(text: line, address: address.isEmpty ? null : address, remote: remote),
      ],
    );
  }
}

/// The small line under a source's name: where it came from, then copy and,
/// for an http(s) source, open. [address] is null for a local source that
/// records no path, and for a medium-window row whose line carries only the
/// format.
final class _SourceAddressLine extends StatelessWidget {
  const _SourceAddressLine({required this.text, required this.remote, this.address});

  /// The line's text.
  final String text;

  /// The address the actions work on; null when there is none to act on.
  final String? address;

  /// Whether the source is a network one, which is what makes an http(s)
  /// address worth opening.
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final link = address;
    return Row(
      spacing: DsSpace.s4,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
        ),
        if (link != null) ...[
          _SourceAddressAction(
            icon: DsIcons.copy,
            label: t.iptv.copySourceAddress,
            onPressed: () => unawaited(copySourceAddress(context, link)),
          ),
          if (remote && (link.startsWith('http://') || link.startsWith('https://')))
            _SourceAddressAction(
              icon: DsIcons.externalLink,
              label: t.iptv.openSourceAddress,
              onPressed: () => unawaited(openSourceAddress(context, link)),
            ),
        ],
      ],
    );
  }
}

Future<void> copySourceAddress(BuildContext context, String address) async {
  await Clipboard.setData(ClipboardData(text: address));
  if (context.mounted) showDsToast(context: context, title: context.t.iptv.sourceAddressCopied);
}

Future<void> openSourceAddress(BuildContext context, String address) async {
  final uri = Uri.tryParse(address);
  final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showDsToast(context: context, title: context.t.iptv.sourceAddressOpenFailed, status: DsStatus.danger);
  }
}

/// A tiny address action beside a source's URL: copy, or open a remote one.
final class _SourceAddressAction extends StatelessWidget {
  const _SourceAddressAction({required this.icon, required this.label, required this.onPressed});

  final DsIconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, _) => Padding(
        padding: const EdgeInsets.all(DsSpace.s3),
        child: DsIcon(
          icon,
          size: 13,
          color: (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused))
              ? colors.text
              : colors.textSubtle,
        ),
      ),
    );
  }
}

/// One source in the order draft: the grip, its name and address, the
/// format badge and the four arrow actions. The grip drags; the arrows move
/// one place or to an end, so a pointer, a remote and a screen reader all
/// have a way to arrange it.
final class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.item,
    required this.last,
    this.onMoveTop,
    this.onMoveUp,
    this.onMoveDown,
    this.onMoveBottom,
    super.key,
  });

  final Object item;
  final bool last;
  final VoidCallback? onMoveTop;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onMoveBottom;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final playlist = item is IptvPlaylist ? item as IptvPlaylist : null;
    final guide = item is EpgSource ? item as EpgSource : null;
    final name = playlist?.name ?? guide!.name;
    final address = playlist?.url ?? guide!.source;
    final format = playlist != null ? _playlistBadge(playlist) : _guideBadge(guide!);
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
        ),
        if (address.isNotEmpty)
          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
      ],
    );
    final arrows = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s3,
      children: [
        IptvIconAction(icon: DsIcons.arrowUpToLine, label: t.iptv.moveToTop, onPressed: onMoveTop),
        IptvIconAction(icon: DsIcons.arrowUp, label: t.iptv.moveUp, onPressed: onMoveUp),
        IptvIconAction(icon: DsIcons.arrowDown, label: t.iptv.moveDown, onPressed: onMoveDown),
        IptvIconAction(icon: DsIcons.arrowDownToLine, label: t.iptv.moveToBottom, onPressed: onMoveBottom),
      ],
    );
    final badge = DsBadge(dot: false, label: Text(format));
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!LiveWindow.isCompact(constraints.maxWidth)) {
            return Row(
              spacing: DsSpace.s8,
              children: [
                const DsReorderableHandle(),
                const SizedBox(width: DsSpace.s4),
                Expanded(child: names),
                badge,
                const SizedBox(width: DsSpace.s4),
                arrows,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s8,
            children: [
              const DsReorderableHandle(),
              const SizedBox(width: DsSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s6,
                  children: [
                    names,
                    Row(children: [badge, const Spacer(), arrows]),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A local time as "08:00" today, "09-30 12:05" this year, or a full date
/// before that; null when there is no time to show.
String? _stamp(DateTime? time) {
  if (time == null) return null;
  final local = time.toLocal();
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(local.hour)}:${two(local.minute)}';
  if (local.year == now.year && local.month == now.month && local.day == now.day) return clock;
  if (local.year == now.year) return '${two(local.month)}-${two(local.day)} $clock';
  return '${local.year}-${two(local.month)}-${two(local.day)} $clock';
}

/// The format badge of [playlist], read from the address it was imported
/// from; pasted text and local files record no address, so they show M3U —
/// the format the importer reads first.
String _playlistBadge(IptvPlaylist playlist) {
  final path = (Uri.tryParse(playlist.url ?? '')?.path ?? '').toLowerCase();
  if (path.endsWith('.m3u8')) return 'M3U8';
  if (path.endsWith('.txt')) return 'TXT';
  return 'M3U';
}

/// The format badge of [source], by its address; the importer reads the
/// content, so this is only a hint.
String _guideBadge(EpgSource source) {
  final path = (Uri.tryParse(source.source)?.path ?? source.source).toLowerCase();
  if (path.endsWith('.gz')) return 'XML.GZ';
  if (path.endsWith('.json')) return 'JSON';
  return 'XML';
}
