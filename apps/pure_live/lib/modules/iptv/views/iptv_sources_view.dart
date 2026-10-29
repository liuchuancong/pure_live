import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_auto_update.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvPlaylistIsRemote;
import 'package:pure_live/modules/iptv/controllers/iptv_epg_controller.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart';
import 'package:pure_live/modules/iptv/views/iptv_import_dialog.dart'
    show iptvImportFailureText, runIptvGuideImport, runIptvPlaylistImport;
import 'package:pure_live/modules/iptv/views/iptv_panels.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// What the resources table shows: everything, only playlists or only
/// guides.
enum _SourceFilter { all, playlists, guides }

/// The preference the viewer's source order is kept under: a string list of
/// `p:<playlist id>` and `g:<guide id>` keys, first shown first.
const String _sourceOrderPref = 'iptv.sources.order';

/// The IPTV source manager, in the reference's resource-panel shape: the
/// active guide and the update schedule as two settings cards, then one
/// table over the playlists and guides with a kind filter, a search, the
/// shared sync-all action, per-row sync/delete and the guide switches.
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
  bool _bulkBusy = false;
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
      _toast(t.iptv.syncFailed(name: playlist.name), description: iptvImportFailureText(result, t), danger: true);
    }
  }

  Future<void> _syncGuide(EpgSource source) async {
    final result = await ref.read(iptvEpgProvider.notifier).syncSource(source);
    if (!mounted || result == null) return;
    final t = context.t;
    if (result.isImported) {
      _toast(t.iptv.synced(name: source.name));
    } else {
      _toast(t.iptv.syncFailed(name: source.name), description: iptvImportFailureText(result, t), danger: true);
    }
  }

  // -- Delete --------------------------------------------------------------

  Future<void> _deletePlaylist(IptvPlaylist playlist) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.deletePlaylistTitle,
      description: t.iptv.deletePlaylistMessage(name: playlist.name, count: playlist.channelCount),
      confirmLabel: t.iptv.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash),
    );
    if (!confirmed || !mounted) return;
    final deleted = await ref.read(iptvSourcesProvider.notifier).deletePlaylist(playlist);
    if (!mounted) return;
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

  Future<void> _setAllAutoUpdate(bool value) async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    try {
      await ref.read(iptvEpgProvider.notifier).setAllAutoUpdate(value: value);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

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
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final sources = ref.watch(iptvSourcesProvider);
    final epg = ref.watch(iptvEpgProvider);
    if (!sources.ready || !epg.ready) {
      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    }
    final interval = ref.watch(iptvUpdateIntervalProvider);
    final active = _activeOf(epg);
    final round = sources.syncAll;
    final blocked = sources.importing || epg.importing || round != null;
    final settingsBlocked = blocked || epg.busy.isNotEmpty || sources.busy.isNotEmpty || _bulkBusy;
    final hasRemote = sources.playlists.any(iptvPlaylistIsRemote) || epg.sources.any((source) => source.isRemote);
    final canSync = hasRemote && !blocked && epg.busy.isEmpty && sources.busy.isEmpty;
    final remoteGuides = [
      for (final source in epg.sources)
        if (source.isRemote) source,
    ];
    final autoOn = remoteGuides.where((source) => source.autoUpdate).length;
    final allOn = remoteGuides.isNotEmpty && autoOn == remoteGuides.length;
    final all = _ordered(<Object>[...sources.playlists, ...epg.sources]);
    if (_sorting) {
      return _buildSorting(context);
    }
    final rows = [
      for (final item in all)
        if (_keeps(item) && _matches(item, _query)) item,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          _SettingsRow(
            active: active,
            canChoose: epg.sources.isNotEmpty && !settingsBlocked,
            onChoose: () => unawaited(_chooseGuide()),
            allOn: allOn,
            canToggleAll: remoteGuides.isNotEmpty && !settingsBlocked,
            onToggleAll: (value) => unawaited(_setAllAutoUpdate(value)),
            interval: interval,
            onInterval: ref.read(iptvUpdateIntervalProvider.notifier).select,
            autoOn: autoOn,
            remoteCount: remoteGuides.length,
          ),
          if (round case final progress?) _SyncStrip(done: progress.done, total: progress.total),
          IptvTablePanel(
            toolbar: _SourcesToolbar(
              filter: _filter,
              onFilter: (next) => setState(() => _filter = next),
              count: rows.length,
              search: _search,
              onQuery: (value) => setState(() => _query = value),
              canSync: canSync,
              onSync: () => unawaited(syncAllIptvSources(context, ref)),
              syncing: round != null,
              canEditOrder: all.isNotEmpty,
              onEditOrder: () => _startSorting(all),
            ),
            child: _SourcesTable(
              rows: rows,
              activeId: epg.activeId,
              channelCounts: epg.channelCounts,
              settingsBlocked: settingsBlocked,
              sourceBusy: sources.busy,
              guideBusy: epg.busy,
              onSyncPlaylist: (playlist) => unawaited(_syncPlaylist(playlist)),
              onSyncGuide: (source) => unawaited(_syncGuide(source)),
              onDeletePlaylist: (playlist) => unawaited(_deletePlaylist(playlist)),
              onDeleteGuide: (source) => unawaited(_deleteGuide(source)),
              onAutoUpdate: (source, value) => unawaited(_setAutoUpdate(source, value)),
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
                child: DsEmptyState(icon: const DsIcon(DsIcons.list), title: Text(t.iptv.noSourcesTitle)),
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
      return DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noSourceMatch));
    }
    if (_filter == _SourceFilter.playlists && sources.playlists.isEmpty) {
      return DsEmptyState(
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
      );
    }
    if (_filter == _SourceFilter.guides && epg.sources.isEmpty) {
      return DsEmptyState(
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
      );
    }
    if (sources.playlists.isEmpty && epg.sources.isEmpty) {
      return DsEmptyState(
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
      );
    }
    return DsEmptyState(icon: const DsIcon(DsIcons.searchX), title: Text(t.iptv.noSourceMatch));
  }

  static EpgSource? _activeOf(IptvEpgState epg) {
    for (final source in epg.sources) {
      if (source.id == epg.activeId) return source;
    }
    return null;
  }
}

/// The two settings cards: the guide in use, and the update schedule with
/// its bulk switch, intervals and current-state line.
final class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.active,
    required this.canChoose,
    required this.onChoose,
    required this.allOn,
    required this.canToggleAll,
    required this.onToggleAll,
    required this.interval,
    required this.onInterval,
    required this.autoOn,
    required this.remoteCount,
  });

  final EpgSource? active;
  final bool canChoose;
  final VoidCallback onChoose;
  final bool allOn;
  final bool canToggleAll;
  final ValueChanged<bool> onToggleAll;
  final IptvUpdateInterval interval;
  final ValueChanged<IptvUpdateInterval> onInterval;
  final int autoOn;
  final int remoteCount;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final activeCard = _SettingCard(
      title: t.iptv.activeGuideTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Row(
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
                        style: DsTheme.of(context).typography.caption
                            .copyWith(color: DsTheme.colorsOf(context).textSubtle),
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
          Text(
            t.iptv.activeGuideCardHint,
            style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
          ),
        ],
      ),
    );
    final updateCard = _SettingCard(
      title: t.iptv.autoUpdate,
      trailing: DsSwitch(value: allOn, onChanged: canToggleAll ? onToggleAll : null, semanticLabel: t.iptv.autoUpdate),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Text(
            t.iptv.updateInterval,
            style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
          ),
          DsSegmentedControl<IptvUpdateInterval>(
            value: interval,
            onChanged: onInterval,
            semanticLabel: t.iptv.updateInterval,
            segments: [
              for (final value in IptvUpdateInterval.values) DsSegment(value: value, label: Text(value.label(t))),
            ],
          ),
          _UpdateStatus(autoOn: autoOn, remoteCount: remoteCount),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (LiveWindow.isExpanded(constraints.maxWidth)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: activeCard),
              const SizedBox(width: DsSpace.s16),
              Expanded(flex: 7, child: updateCard),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [activeCard, updateCard],
        );
      },
    );
  }
}

/// The reference's setting card: a title row over a hairline, then the
/// card's controls.
final class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                ),
              ),
              ?trailing,
            ],
          ),
          const DsDivider(),
          child,
        ],
      ),
    );
  }
}

/// The update card's state line: how many guides the schedule covers, or
/// what to do when none does.
final class _UpdateStatus extends StatelessWidget {
  const _UpdateStatus({required this.autoOn, required this.remoteCount});

  final int autoOn;
  final int remoteCount;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final on = autoOn > 0;
    final text = remoteCount == 0
        ? t.iptv.autoUpdateNoRemote
        : on
        ? t.iptv.autoUpdateStatusOn(count: autoOn)
        : t.iptv.autoUpdateStatusNone;
    return Row(
      spacing: DsSpace.s6,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? colors.success.fill : colors.textSubtle),
        ),
        Flexible(
          child: Text(text, style: theme.typography.small.copyWith(color: colors.textMuted)),
        ),
      ],
    );
  }
}

/// The sync round's progress under the cards, while one runs.
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

/// The resources table's toolbar: kind filter, count, search and the
/// shared sync-all action.
final class _SourcesToolbar extends StatelessWidget {
  const _SourcesToolbar({
    required this.filter,
    required this.onFilter,
    required this.count,
    required this.search,
    required this.onQuery,
    required this.canSync,
    required this.onSync,
    required this.syncing,
    required this.canEditOrder,
    required this.onEditOrder,
  });

  final _SourceFilter filter;
  final ValueChanged<_SourceFilter> onFilter;
  final int count;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final bool canSync;
  final VoidCallback onSync;
  final bool syncing;
  final bool canEditOrder;
  final VoidCallback onEditOrder;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final segments = DsSegmentedControl<_SourceFilter>(
      value: filter,
      onChanged: onFilter,
      semanticLabel: t.iptv.viewLabel,
      segments: [
        DsSegment(value: _SourceFilter.all, label: Text(t.iptv.filterAll)),
        DsSegment(value: _SourceFilter.playlists, label: Text(t.iptv.filterPlaylists)),
        DsSegment(value: _SourceFilter.guides, label: Text(t.iptv.filterGuides)),
      ],
    );
    final countText = Text(
      t.iptv.sourceCount(count: count),
      style: theme.typography.small.copyWith(color: colors.textMuted),
    );
    final field = DsSearchField(
      controller: search,
      placeholder: t.iptv.searchSources,
      semanticLabel: t.iptv.searchSources,
      onChanged: onQuery,
    );
    final sync = DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      loading: syncing,
      onPressed: canSync ? onSync : null,
      leading: const DsIcon(DsIcons.refreshCw, size: 15),
      child: Text(t.iptv.syncAll),
    );
    final edit = DsButton(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      onPressed: canEditOrder ? onEditOrder : null,
      leading: const DsIcon(DsIcons.listOrdered, size: 15),
      child: Text(t.iptv.editOrder),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!LiveWindow.stacksToolbar(constraints.maxWidth)) {
          return Row(
            spacing: DsSpace.s12,
            children: [
              segments,
              countText,
              const Spacer(),
              edit,
              SizedBox(width: 200, child: field),
              sync,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            segments,
            Row(
              children: [
                Expanded(child: countText),
                const SizedBox(width: DsSpace.s8),
                IptvIconAction(
                  icon: DsIcons.listOrdered,
                  label: t.iptv.editOrder,
                  onPressed: canEditOrder ? onEditOrder : null,
                ),
                IptvIconAction(
                  icon: DsIcons.refreshCw,
                  label: t.iptv.syncAll,
                  busy: syncing,
                  onPressed: canSync ? onSync : null,
                ),
              ],
            ),
            field,
          ],
        );
      },
    );
  }
}

/// The playlists and guides as one table: name and address, format,
/// channels, last update, the guide's own update switch and the row's
/// sync/delete actions.
final class _SourcesTable extends StatelessWidget {
  const _SourcesTable({
    required this.rows,
    required this.activeId,
    required this.channelCounts,
    required this.settingsBlocked,
    required this.sourceBusy,
    required this.guideBusy,
    required this.onSyncPlaylist,
    required this.onSyncGuide,
    required this.onDeletePlaylist,
    required this.onDeleteGuide,
    required this.onAutoUpdate,
    required this.emptyView,
  });

  final List<Object> rows;
  final String? activeId;
  final Map<String, int> channelCounts;
  final bool settingsBlocked;
  final Set<String> sourceBusy;
  final Set<String> guideBusy;
  final ValueChanged<IptvPlaylist> onSyncPlaylist;
  final ValueChanged<EpgSource> onSyncGuide;
  final ValueChanged<IptvPlaylist> onDeletePlaylist;
  final ValueChanged<EpgSource> onDeleteGuide;
  // The switch reports its own on/off; a named flag would only rename it.
  // ignore: avoid_positional_boolean_parameters
  final void Function(EpgSource source, bool value) onAutoUpdate;
  final Widget emptyView;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = theme.typography.small.copyWith(color: colors.textMuted);
    return DsTable<Object>(
      semanticLabel: t.iptv.viewSources,
      layout: const DsTableLayout.auto(),
      rows: rows,
      rowKey: (item) => item is IptvPlaylist ? 'p:${item.id}' : 'g:${(item as EpgSource).id}',
      columns: [
        DsTableColumn(
          id: 'name',
          label: t.iptv.colName,
          value: (item) => item is IptvPlaylist ? item.name : (item as EpgSource).name,
          width: const DsTableColumnWidth.flex(2, 240),
          cell: (context, item) => _SourceNameCell(item: item, activeId: activeId),
        ),
        DsTableColumn(
          id: 'format',
          label: t.iptv.colFormat,
          value: (item) => item is IptvPlaylist ? _playlistBadge(item) : _guideBadge(item as EpgSource),
          width: const DsTableColumnWidth.fixed(100),
          cell: (context, item) => DsBadge(
            dot: false,
            label: Text(item is IptvPlaylist ? _playlistBadge(item) : _guideBadge(item as EpgSource)),
          ),
        ),
        DsTableColumn(
          id: 'channels',
          label: t.iptv.colChannel,
          value: (item) => item is IptvPlaylist ? item.channelCount : channelCounts[(item as EpgSource).id] ?? 0,
          width: const DsTableColumnWidth.fixed(90),
          numeric: true,
          cell: (context, item) {
            final count = item is IptvPlaylist ? item.channelCount : channelCounts[(item as EpgSource).id] ?? 0;
            return Text(iptvNumber(count), style: theme.typography.numeric(meta));
          },
        ),
        DsTableColumn(
          id: 'updated',
          label: t.iptv.colUpdated,
          value: (item) =>
              (item is IptvPlaylist ? item.importedAt : (item as EpgSource).lastRefresh)?.millisecondsSinceEpoch ?? 0,
          width: const DsTableColumnWidth.fixed(150),
          cell: (context, item) {
            final updated = item is IptvPlaylist ? item.importedAt : (item as EpgSource).lastRefresh;
            return Text(
              _stamp(updated) ?? t.iptv.neverUpdated,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: meta,
            );
          },
        ),
        DsTableColumn(
          id: 'auto',
          label: t.iptv.colAutoUpdate,
          width: const DsTableColumnWidth.fixed(104),
          alignment: DsTableCellAlignment.center,
          cell: (context, item) {
            if (item is! EpgSource || !item.isRemote) {
              return Text('—', style: meta);
            }
            final busy = guideBusy.contains('g:${item.id}');
            return DsSwitch(
              value: item.autoUpdate,
              onChanged: settingsBlocked || busy ? null : (value) => onAutoUpdate(item, value),
              semanticLabel: t.iptv.autoUpdate,
            );
          },
        ),
        DsTableColumn(
          id: 'actions',
          label: t.iptv.colActions,
          width: const DsTableColumnWidth.fixed(92),
          alignment: DsTableCellAlignment.center,
          cell: (context, item) {
            final playlist = item is IptvPlaylist ? item : null;
            final guide = item is EpgSource ? item : null;
            final remote = playlist != null ? iptvPlaylistIsRemote(playlist) : guide!.isRemote;
            final busy = playlist != null
                ? sourceBusy.contains('p:${playlist.id}')
                : guideBusy.contains('g:${guide!.id}');
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (remote)
                  IptvIconAction(
                    icon: DsIcons.refreshCw,
                    label: t.iptv.sync,
                    busy: busy,
                    onPressed: settingsBlocked && !busy
                        ? null
                        : () {
                            if (playlist != null) {
                              onSyncPlaylist(playlist);
                            } else {
                              onSyncGuide(guide!);
                            }
                          },
                  ),
                IptvIconAction(
                  icon: DsIcons.trash,
                  label: t.iptv.delete,
                  destructive: true,
                  onPressed: settingsBlocked || busy
                      ? null
                      : () {
                          if (playlist != null) {
                            onDeletePlaylist(playlist);
                          } else {
                            onDeleteGuide(guide!);
                          }
                        },
                ),
              ],
            );
          },
        ),
      ],
      style: iptvTableStyle(context),
      emptyView: emptyView,
    );
  }
}

/// A row's name, its local/network origin, the active-guide mark and the
/// address it came from.
final class _SourceNameCell extends StatelessWidget {
  const _SourceNameCell({required this.item, required this.activeId});

  final Object item;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final playlist = item is IptvPlaylist ? item as IptvPlaylist : null;
    final guide = item is EpgSource ? item as EpgSource : null;
    final name = playlist?.name ?? guide!.name;
    final address = playlist?.url ?? guide!.source;
    final remote = playlist != null ? iptvPlaylistIsRemote(playlist) : guide!.isRemote;
    final inUse = guide != null && guide.id == activeId;
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
                name,
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
            if (inUse) DsBadge(dot: false, label: Text(t.iptv.inUse), status: DsStatus.info),
          ],
        ),
        if (address.isNotEmpty)
          Row(
            spacing: DsSpace.s4,
            children: [
              Flexible(
                child: Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
              _SourceAddressAction(
                icon: DsIcons.copy,
                label: t.iptv.copySourceAddress,
                onPressed: () => unawaited(_copyAddress(context, address)),
              ),
              if (remote && (address.startsWith('http://') || address.startsWith('https://')))
                _SourceAddressAction(
                  icon: DsIcons.externalLink,
                  label: t.iptv.openSourceAddress,
                  onPressed: () => unawaited(_openAddress(context, address)),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) showDsToast(context: context, title: context.t.iptv.sourceAddressCopied);
  }

  Future<void> _openAddress(BuildContext context, String address) async {
    final uri = Uri.tryParse(address);
    final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showDsToast(context: context, title: context.t.iptv.sourceAddressOpenFailed, status: DsStatus.danger);
    }
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
        child: DsIcon(icon, size: 13, color: states.contains(WidgetState.hovered) ? colors.text : colors.textSubtle),
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
