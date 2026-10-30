import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/room/room_card_settings.dart'
    show kRoomCardListDesignHeight, roomCardTileHeight;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/history/history_limit_dialog.dart';
import 'package:pure_live/modules/live/history/history_repository.dart';
import 'package:pure_live/modules/live/popular/popular.dart' show RoomCard, RoomCardMenu;
import 'package:pure_live/shared/shared.dart';

/// The live module's history (the reference's `HistoryPage`): the watched
/// rooms grouped by day — Today / Yesterday / Earlier, like the reference's history
/// sections — each as the shared room card carrying its watch time; one
/// card's ✕ drops its record, the header's button drops them all.
///
/// The header counts the records against the cap and opens the filter and
/// the cap's dialog; the filter itself lives in a panel — a keyword over the
/// room's wording and a watched-between range of days — so the records keep
/// the page and the conditions stay in one place. Every destructive action
/// asks first and reports its outcome.
final class HistoryPage extends ConsumerStatefulWidget {
  /// The history page.
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

/// The history page's filter: a word over the room's wording and the days
/// (midnight boundaries) the record must fall in; a null day leaves that
/// side unbounded.
typedef _HistoryFilter = ({String query, DateTime? from, DateTime? to});

final class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// The filter in force; all-empty keeps every record.
  _HistoryFilter _filter = (query: '', from: null, to: null);

  /// A destructive change is running; its buttons wait.
  bool _busy = false;

  /// The refresh's progress (0..1); null when none runs.
  double? _progress;

  /// Whether the filter keeps anything out.
  bool get _filterActive => _filterCount > 0;

  /// How many conditions the filter holds: the word and each open end.
  int get _filterCount =>
      (_filter.query.trim().isNotEmpty ? 1 : 0) + (_filter.from != null ? 1 : 0) + (_filter.to != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final history = ref.watch(historyProvider);
    if (!history.ready) {
      // The same grid the records will fill, so the page never reflows when
      // the store opens.
      final settings = ref.watch(browseSettingsProvider);
      return CardGrid<(LiveRoom, DateTime)>(
        items: const [],
        layout: ref.watch(browseLayoutProvider),
        listMatchesGridWidth: true,
        listMainAxisExtent: kRoomCardListDesignHeight,
        crossSpacing: settings.crossSpacing,
        mainSpacing: settings.mainSpacing,
        isLoading: true,
        padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s24),
        itemBuilder: (_, _) => const SizedBox.shrink(),
      );
    }
    if (history.error != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.history.openFailedTitle),
          description: Text(history.error!),
          actions: [
            DsButton(
              onPressed: () {
                ref
                  ..invalidate(historyRepositoryProvider)
                  ..invalidate(historyProvider);
              },
              child: Text(t.common.retry),
            ),
          ],
        ),
      );
    }
    final limit = ref.watch(historyLimitProvider);
    final shown = _filtered(history.records);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          total: history.records.length,
          limit: limit,
          matches: shown.length,
          filterCount: _filterCount,
          filtering: _filterActive,
          busy: _busy,
          canClear: shown.isNotEmpty,
          onOpenFilter: () => unawaited(_openFilter(history.records)),
          onEditLimit: () => unawaited(_editLimit()),
          onRefresh: () => unawaited(_refreshAll(history.records)),
          onClear: () => unawaited(_clear()),
        ),
        if (_progress case final progress?)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s6),
            child: DsProgressBar(value: progress, semanticLabel: t.history.refresh),
          ),
        // The filter's conditions in force, worded over the page like the
        // areas and popular pages word their search: what is being narrowed,
        // and the one control that widens it again.
        if (_filterActive)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
            child: DsAlert(
              title: Text(t.history.filterMatches(count: shown.length)),
              action: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.x, size: 14),
                onPressed: _resetFilter,
                child: Text(t.history.filterReset),
              ),
            ),
          ),
        Expanded(child: _body(t, history.records, shown)),
      ],
    );
  }

  Widget _body(Translations t, List<(LiveRoom, DateTime)> all, List<(LiveRoom, DateTime)> shown) {
    if (all.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.history),
          title: Text(t.history.emptyTitle),
          description: Text(t.history.emptyDescription),
        ),
      );
    }
    if (shown.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(t.history.filterEmptyTitle),
          description: Text(t.history.filterEmptyDescription),
          actions: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: _resetFilter,
              child: Text(t.history.filterReset),
            ),
          ],
        ),
      );
    }
    final sections = _daySections(t, shown, DateTime.now());
    final layout = ref.watch(browseLayoutProvider);
    final settings = ref.watch(browseSettingsProvider);
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossSpacing = settings.crossSpacing;
        // The feed's own measure — the viewer's column cap included — so a
        // history tile is the feed's tile and a list row is a card's width.
        // The width is the one the grid really gets: the page's inset is the
        // grid's padding, and counting it twice used to ask for one column
        // more than the delegate drew, which squeezed the rows.
        final content = math.max(0, constraints.maxWidth - 2 * inset).toDouble();
        final capped = cappedColumnsForWidth(
          content,
          spacing: crossSpacing,
          ceiling: settings.gridColumns,
          minWidth: kBrowseCardMinWidth,
        );
        final listRow = layout == CardLayout.list;
        final extent = capped > 0 && content > 0
            ? columnExtentForWidth(content, capped, crossSpacing)
            : browseCardExtentForWidth(content, crossSpacing: crossSpacing);
        final columns = math.max(1, (content / (extent + crossSpacing)).ceil());
        final tileWidth = content > 0 ? (content - crossSpacing * (columns - 1)) / columns : 0.0;
        final tileExtent = listRow ? kRoomCardListDesignHeight : roomCardTileHeight(tileWidth);
        // One scroll for every day: the sections are slivers, so a long
        // record list builds its cards lazily instead of all at once.
        return CustomScrollView(
          slivers: [
            for (final (header, records) in sections) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
                sliver: SliverToBoxAdapter(
                  child: _DayHeader(label: header, count: records.length),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: extent,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: settings.mainSpacing,
                    mainAxisExtent: tileExtent,
                  ),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final (room, watchedAt) = records[index];
                    return _historyCard(context, room, watchedAt: watchedAt, listRow: listRow);
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: DsSpace.s24)),
          ],
        );
      },
    );
  }

  /// One watched room as the shared card: the watch time in the cover's
  /// corner, the record's removal in the heart's, and the card's menu around
  /// it — open, copy the link, then this page's own remove.
  Widget _historyCard(BuildContext context, LiveRoom room, {required DateTime watchedAt, bool listRow = false}) {
    final t = context.t;
    void open() => unawaited(openRoom(context, platform: room.ref.platform, roomId: room.ref.roomId));
    final remove = _busy ? null : () => unawaited(_remove(room));
    return RoomCardMenu(
      room: room,
      onOpen: open,
      items: [
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.history.remove),
          destructive: true,
          onPressed: remove,
        ),
      ],
      child: RoomCard(
        room: room,
        listRow: listRow,
        cornerNote: _watchClock(watchedAt),
        onOpen: open,
        onRemove: remove,
        removeLabel: t.history.remove,
      ),
    );
  }

  /// The records the filter keeps: the word over the room and the day range
  /// over when it was watched; every empty piece keeps its side open.
  List<(LiveRoom, DateTime)> _filtered(List<(LiveRoom, DateTime)> records) {
    if (!_filterActive) return records;
    final needle = _filter.query.trim().toLowerCase();
    return [
      for (final record in records)
        if (_matches(record.$1, needle) && _watchedWithin(record.$2)) record,
    ];
  }

  /// Whether [room]'s title, streamer, room id, platform id or platform
  /// name contains [needle] (any case); a blank word matches every room.
  bool _matches(LiveRoom room, String needle) {
    if (needle.isEmpty) return true;
    final site = ref.read(sitesProvider).getById(room.ref.platform);
    final platformName = site == null ? '' : localizedSiteName(site);
    return [
      room.content.title,
      room.anchor?.name ?? '',
      room.ref.roomId,
      room.ref.platform,
      platformName,
    ].any((text) => text.toLowerCase().contains(needle));
  }

  /// Whether [watchedAt]'s day falls in the filter's range; either end may
  /// be open, and both ends are inclusive days.
  bool _watchedWithin(DateTime watchedAt) {
    final day = DateTime(watchedAt.year, watchedAt.month, watchedAt.day);
    final from = _filter.from;
    final to = _filter.to;
    if (from != null && day.isBefore(from)) return false;
    if (to != null && day.isAfter(to)) return false;
    return true;
  }

  /// Opens the filter's panel over the records: the panel edits the word and
  /// the two days and reports each change, so the page thins out behind it
  /// as conditions arrive.
  Future<void> _openFilter(List<(LiveRoom, DateTime)> records) {
    DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);
    DateTime? earliest;
    for (final (_, watchedAt) in records) {
      final day = dayOf(watchedAt);
      if (earliest == null || day.isBefore(earliest)) earliest = day;
    }
    return showDsPanel<void>(
      context: context,
      builder: (context) => _FilterPanel(
        filter: _filter,
        firstDay: earliest ?? dayOf(DateTime.now()),
        onChanged: (filter) {
          if (mounted) setState(() => _filter = filter);
        },
      ),
    );
  }

  /// Clears every condition; every record shows again.
  void _resetFilter() => setState(() => _filter = (query: '', from: null, to: null));

  /// Re-reads every record's room state, keeping each watch moment; the
  /// failures are counted rather than hidden.
  Future<void> _refreshAll(List<(LiveRoom, DateTime)> records) async {
    if (_busy || records.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final failed = await ref
          .read(historyProvider.notifier)
          .refreshRooms(
            [for (final (room, _) in records) room],
            onProgress: (done, total) {
              if (mounted) setState(() => _progress = total == 0 ? null : done / total);
            },
          );
      if (failed > 0 && mounted) {
        showDsToast(
          context: context,
          title: context.t.history.refreshFailed(count: failed),
          status: DsStatus.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  /// Removes [room] after asking; a record watched again since stays.
  Future<void> _remove(LiveRoom room) async {
    if (_busy) return;
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.history.deleteConfirmTitle,
      description: t.history.deleteConfirmDesc(title: _roomLabel(room)),
      confirmLabel: t.history.deleteAction,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    await _runChange(() => ref.read(historyProvider.notifier).remove(room.ref.identityKey), done: t.history.deleteDone);
  }

  /// Removes the records the page shows — all of them, or the filter's
  /// matches — after asking; the wording says which when a filter is
  /// active.
  Future<void> _clear() async {
    if (_busy) return;
    final t = context.t;
    final all = ref.read(historyProvider).records;
    final shown = _filtered(all);
    if (shown.isEmpty) return;
    final filtered = shown.length != all.length;
    final count = shown.length;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.history.clearConfirmTitle,
      description: filtered
          ? t.history.clearFilteredConfirmDesc(count: count)
          : t.history.clearConfirmDesc(count: count),
      confirmLabel: t.history.clear,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    await _runChange(
      () =>
          ref.read(historyProvider.notifier).clear(identityKeys: [for (final (room, _) in shown) room.ref.identityKey]),
      done: t.history.clearDone(count: count),
    );
  }

  Future<void> _editLimit() async {
    if (_busy) return;
    final saved = await showHistoryLimitDialog(
      context,
      limit: ref.read(historyLimitProvider),
      save: (limit) => ref.read(historyLimitProvider.notifier).setLimit(limit),
    );
    if (!mounted || saved == null) return;
    showDsToast(
      context: context,
      title: context.t.history.limitSaved(limit: saved),
      status: DsStatus.success,
    );
  }

  /// Runs [change] once at a time, then says it worked or that it failed.
  Future<void> _runChange(Future<void> Function() change, {required String done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await change();
      if (!mounted) return;
      showDsToast(context: context, title: done, status: DsStatus.success);
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: context.t.history.changeFailed, status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _roomLabel(LiveRoom room) {
    final title = room.content.title.trim();
    return title.isEmpty ? room.ref.roomId : title;
  }

  /// Splits the records into Today / Yesterday / Earlier, keeping each section's
  /// order; an empty day never shows.
  List<(String, List<(LiveRoom, DateTime)>)> _daySections(
    Translations t,
    List<(LiveRoom, DateTime)> records,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sections = <(String, List<(LiveRoom, DateTime)>)>[
      (t.history.today, []),
      (t.history.yesterday, []),
      (t.history.earlier, []),
    ];
    for (final record in records) {
      final (_, watchedAt) = record;
      final day = DateTime(watchedAt.year, watchedAt.month, watchedAt.day);
      if (day == today) {
        sections[0].$2.add(record);
      } else if (day == yesterday) {
        sections[1].$2.add(record);
      } else {
        sections[2].$2.add(record);
      }
    }
    return [
      for (final section in sections)
        if (section.$2.isNotEmpty) section,
    ];
  }
}

/// The page's header, the popular and areas pages' toolbar: the count
/// against the cap (and how many the filter leaves) on the left; the
/// card/row switch, refresh, the filter with its condition count, the cap
/// and clear on the right. A small screen keeps the count, the filter and
/// one more icon — the rest of the verbs, the layout switch included, move
/// into its menu.
final class _Header extends ConsumerWidget {
  const _Header({
    required this.total,
    required this.limit,
    required this.matches,
    required this.filterCount,
    required this.filtering,
    required this.busy,
    required this.canClear,
    required this.onOpenFilter,
    required this.onEditLimit,
    required this.onRefresh,
    required this.onClear,
  });

  final int total;
  final int limit;
  final int matches;

  /// How many filter conditions are set.
  final int filterCount;

  final bool filtering;
  final bool busy;
  final bool canClear;
  final VoidCallback onOpenFilter;
  final VoidCallback onEditLimit;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final layout = ref.watch(browseLayoutProvider);
    void chooseLayout(CardLayout value) => unawaited(ref.read(browseLayoutProvider.notifier).set(value));
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = LiveWindow.stacksToolbar(constraints.maxWidth);
        final inset = LiveWindow.pageInset(constraints.maxWidth);
        final count = Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: t.history.recordCount(count: total, limit: limit),
                style: theme.typography.small.copyWith(color: colors.textMuted),
              ),
              if (filtering) ...[
                TextSpan(
                  text: ' · ',
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                ),
                TextSpan(
                  text: t.history.filterMatches(count: matches),
                  style: theme.typography.small.copyWith(color: colors.accentText, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        final filter = DsButton(
          variant: filtering ? DsButtonVariant.tinted : DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: const DsIcon(DsIcons.filter, size: 16),
          trailing: filterCount == 0 ? null : DsCount(filterCount),
          semanticLabel: filterCount == 0 ? t.history.filter : '${t.history.filter}, $filterCount',
          onPressed: total == 0 && !filtering ? null : onOpenFilter,
          child: Text(t.history.filter),
        );
        // The small screen's menu: everything the wide row shows beside the
        // count, the card/row switch included.
        final more = DsMenuAnchor(
          semanticLabel: t.common.more,
          align: DsAlign.end,
          items: [
            DsMenuItem(
              leading: const DsIcon(DsIcons.refreshCw, size: 16),
              label: Text(t.history.refresh),
              onPressed: busy || total == 0 ? null : onRefresh,
            ),
            DsMenuItem(
              leading: const DsIcon(DsIcons.gauge, size: 16),
              label: Text(t.history.limitAction),
              onPressed: busy ? null : onEditLimit,
            ),
            const DsMenuDivider(),
            DsMenuItem(
              label: Text(t.common.layoutGrid),
              checked: layout == CardLayout.grid,
              onPressed: () => chooseLayout(CardLayout.grid),
            ),
            DsMenuItem(
              label: Text(t.common.layoutList),
              checked: layout == CardLayout.list,
              onPressed: () => chooseLayout(CardLayout.list),
            ),
            const DsMenuDivider(),
            DsMenuItem(
              leading: const DsIcon(DsIcons.trash2, size: 16),
              label: Text(t.history.clear),
              destructive: true,
              onPressed: busy || !canClear ? null : onClear,
            ),
          ],
          builder: (context, controller, _) => DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            semanticLabel: t.common.more,
            onPressed: controller.open,
            icon: const DsIcon(DsIcons.ellipsisVertical),
          ),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
          child: SizedBox(
            height: 44,
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(child: count),
                if (narrow) ...[
                  filter,
                  more,
                ] else ...[
                  const LayoutToggle(),
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.history.refresh,
                    onPressed: busy || total == 0 ? null : onRefresh,
                    icon: const DsIcon(DsIcons.refreshCw, size: 16),
                  ),
                  filter,
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.history.limitAction,
                    onPressed: busy ? null : onEditLimit,
                    icon: const DsIcon(DsIcons.gauge, size: 16),
                  ),
                  DsButton(
                    variant: DsButtonVariant.dangerSoft,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.trash2, size: 16),
                    onPressed: busy || !canClear ? null : onClear,
                    child: Text(t.history.clear),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One day's heading over its cards: the day in the toolbar's label weight
/// and how many records it holds, so a long history reads as sections.
final class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Row(
      spacing: DsSpace.s8,
      children: [
        Text(label, style: theme.typography.labelStrong.copyWith(color: colors.text)),
        DsBadge(label: Text('$count'), dot: false),
      ],
    );
  }
}

/// The filter's panel: the word over the room and the watched-between days,
/// each field labelled the kit's way. Every edit reports at once — the page
/// behind a desktop panel thins out as the conditions arrive — and the
/// footer keeps the way back to every record.
final class _FilterPanel extends StatefulWidget {
  const _FilterPanel({required this.filter, required this.firstDay, required this.onChanged});

  /// The conditions when the panel opened.
  final _HistoryFilter filter;

  /// The earliest record's day: the first day either picker offers.
  final DateTime firstDay;

  /// Reports every edit, whole.
  final ValueChanged<_HistoryFilter> onChanged;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

final class _FilterPanelState extends State<_FilterPanel> {
  late final TextEditingController _query = TextEditingController(text: widget.filter.query);
  late DateTime? _from = widget.filter.from;
  late DateTime? _to = widget.filter.to;

  /// A new key per reset: a date field empties from outside only when its
  /// own state is rebuilt.
  int _clears = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged((query: _query.text, from: _from, to: _to));

  bool get _empty => _query.text.trim().isEmpty && _from == null && _to == null;

  void _reset() {
    _query.clear();
    setState(() {
      _from = null;
      _to = null;
      _clears++;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month, now.day);
    final firstDay = widget.firstDay.isAfter(lastDay) ? lastDay : widget.firstDay;
    // Each picker keeps the other side's choice as its far bound, so the
    // range can never be picked backwards.
    final dates = [
      DsField(
        label: Text(t.history.filterStart),
        child: DsDatePicker(
          key: ValueKey('history-filter-from-$_clears'),
          value: _from,
          firstDate: firstDay,
          lastDate: _to ?? lastDay,
          placeholder: t.history.filterAnyDay,
          semanticLabel: t.history.filterStart,
          onChanged: (day) {
            setState(() => _from = day);
            _emit();
          },
        ),
      ),
      DsField(
        label: Text(t.history.filterEnd),
        child: DsDatePicker(
          key: ValueKey('history-filter-to-$_clears'),
          value: _to,
          firstDate: _from ?? firstDay,
          lastDate: lastDay,
          placeholder: t.history.filterAnyDay,
          semanticLabel: t.history.filterEnd,
          onChanged: (day) {
            setState(() => _to = day);
            _emit();
          },
        ),
      ),
    ];
    return DsPanel(
      title: Text(t.history.filterPanelTitle),
      footer: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: _empty ? null : _reset,
              child: Text(t.history.filterReset),
            ),
          ),
          Expanded(
            child: DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.history.filterDone)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          DsField(
            label: Text(t.history.filterKeyword),
            child: DsSearchField(
              controller: _query,
              autofocus: true,
              placeholder: t.history.filterHint,
              semanticLabel: t.history.filterKeyword,
              onChanged: (_) {
                setState(() {});
                _emit();
              },
            ),
          ),
          ...dates,
        ],
      ),
    );
  }
}

/// The moment a record was watched, as a clock on today's records and a
/// short date otherwise.
String _watchClock(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(local.hour)}:${two(local.minute)}';
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  return sameDay ? clock : '${two(local.month)}-${two(local.day)}';
}
