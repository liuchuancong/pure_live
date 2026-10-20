import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show HistoryRepository, WatchRecord;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/list_loading.dart';
import 'package:pure_live/shared/widgets/room_grid.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The watch history, in the reference's v5 shape (A09.9): "观看记录" with
/// "18 / 50 条" under it, the filter, refresh, limit and clear in the bar,
/// and the rooms by day in a width-driven grid whose cards carry the delete
/// corner. Refreshing re-reads every shown room's state (four at a time),
/// keeps what it fetched even if the page closes, and toasts the count.
///
/// The list renders from the repository's own change stream, so a second
/// window's watches appear here too; Esc and Back close the filter before
/// they leave the page.
final class HistoryPage extends ConsumerStatefulWidget {
  /// The history page.
  const new({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

final class _HistoryPageState extends ConsumerState<HistoryPage> {
  StreamSubscription<void>? _changes;
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final ValueNotifier<double?> _progress = ValueNotifier(null);
  Future<void>? _refreshTask;
  bool _loaded = false;
  bool _mutating = false;
  bool _filtering = false;

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  int get _limit => ref.read(appPreferencesProvider).historyLimit;

  @override
  void initState() {
    super.initState();
    // The kept capacity follows the preference — applied now and on every
    // change, trimming the store like the reference's setLimit.
    unawaited(_repository.applyCapacity(_limit));
    unawaited(
      _repository.load().then((_) {
        if (mounted) setState(() => _loaded = true);
      }),
    );
    _changes = _repository.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _query.dispose();
    _queryFocus.dispose();
    _progress.dispose();
    super.dispose();
  }

  List<WatchRecord> get _records => _repository.records;

  List<WatchRecord> _shown() {
    if (!_filtering) return _records;
    final needle = _query.text.trim().toLowerCase();
    if (needle.isEmpty) return _records;
    return [
      for (final record in _records)
        if (record.room.content.title.toLowerCase().contains(needle) ||
            (record.room.anchor?.name.toLowerCase().contains(needle) ?? false))
          record,
    ];
  }

  /// One refresh at a time; a second pull joins the running one (3.x).
  Future<void> _refresh() => _refreshTask ??= _runRefresh().whenComplete(() => _refreshTask = null);

  Future<void> _runRefresh() async {
    final records = _shown();
    if (records.isEmpty) return;
    _progress.value = 0;
    var done = 0;
    var failed = 0;
    final refreshed = <LiveRoom>[];
    // Four rooms in flight, like the reference's refresh concurrency.
    const width = 4;
    for (var start = 0; start < records.length; start += width) {
      final batch = records.skip(start).take(width);
      await Future.wait([
        for (final record in batch)
          () async {
            final provider = ref.read(roomProvider(record.room.ref.platform));
            try {
              final result = provider == null ? null : await provider.getRoom(record.room.ref.roomId);
              if (result == null) {
                failed++;
              } else {
                result.fold((error) => failed++, refreshed.add);
              }
            } on Object {
              failed++;
            }
            done++;
            if (mounted) _progress.value = done / records.length;
          }(),
      ]);
      if (!mounted) break;
    }
    _progress.value = null;
    try {
      // What was fetched is kept even when the page has closed meanwhile.
      await _repository.replaceRooms(refreshed);
    } on Object {
      if (mounted) PureToast.show(context, context.t.history.refreshSaveFailed, type: PureToastType.error);
      return;
    }
    if (!mounted) return;
    if (failed == 0) {
      PureToast.show(context, context.t.history.refreshDone(count: done));
    } else {
      PureToast.show(
        context,
        context.t.history.refreshPartial(failed: failed, count: records.length),
        type: PureToastType.warning,
      );
    }
  }

  Future<void> _confirmRemove(WatchRecord record) async {
    final confirmed = await _confirm(
      context.t.history.remove,
      context.t.history.removeConfirm,
      context.t.history.remove,
    );
    if (confirmed) {
      await _repository.remove(record.room);
      if (mounted) PureToast.show(context, context.t.history.removed);
    }
  }

  Future<void> _confirmClear() async {
    final shown = _shown();
    if (shown.isEmpty) return;
    final filtered = shown.length != _records.length;
    final confirmed = await _confirm(
      context.t.history.clear,
      filtered ? context.t.history.clearConfirm : context.t.history.clearConfirm,
      context.t.history.clear,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      if (filtered) {
        for (final record in shown) {
          await _repository.remove(record.room);
        }
      } else {
        await _repository.clear();
      }
      if (mounted) {
        PureToast.show(context, context.t.history.cleared(count: shown.length));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editLimit() async {
    final t = context.t;
    const options = [0, 20, 50, 100, 200, 500];
    final picked = await showSettingsChooser<int>(
      context,
      ref,
      title: t.history.limitTitle,
      hint: t.history.limitHint,
      current: _limit,
      options: [for (final value in options) (value, value == 0 ? t.common.off : '$value')],
    );
    if (picked == null || !mounted) return;
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(historyLimit: picked));
    await _repository.applyCapacity(picked);
    if (mounted) setState(() {});
  }

  void _toggleFilter() {
    setState(() {
      _filtering = !_filtering;
      if (!_filtering) _query.clear();
    });
    if (_filtering) _queryFocus.requestFocus();
  }

  /// The destructive-confirmation dialog the two removals share; false on
  /// dismissal, like the reference's `showDestructiveConfirmation`.
  Future<bool> _confirm(String title, String message, String actionLabel) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: title,
      child: Text(message),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: actionLabel,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Re-apply the kept capacity whenever the preference moves (the limit
    // dialog writes it, and so does another window).
    ref.listen(appPreferencesProvider, (previous, next) {
      if (previous?.historyLimit != next.historyLimit) {
        unawaited(_repository.applyCapacity(next.historyLimit));
      }
    });
    final records = _records;
    final shown = _shown();
    final limit = _limit;
    return PopScope(
      canPop: !_filtering,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _filtering) _toggleFilter();
      },
      child: PureScaffold(
        appBar: PureAppBar(
          title: t.tabs.history,
          titleWidget: Column(
            // Two lines, kept inside the shortest bar (Cupertino's 44): the
            // count caption is the caption ramp at its own line height, and
            // the title drops to bold body so the pair never overflows the
            // iOS bar.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tabs.history,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PureTheme.of(context).text.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                limit == 0
                    ? t.history.countUnlimited(count: records.length)
                    : t.history.countOfLimit(count: records.length, limit: limit),
                maxLines: 1,
                style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
              ),
            ],
          ),
          actions: [
            PureIconButton(
              key: const ValueKey('history-filter'),
              tooltip: _filtering ? t.history.filterClose : t.history.filterOpen,
              icon: _filtering ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined,
              onPressed: records.isEmpty && !_filtering ? null : _toggleFilter,
            ),
            PureIconButton(
              key: const ValueKey('history-refresh'),
              tooltip: t.history.refreshStatus,
              icon: Icons.refresh,
              onPressed: shown.isEmpty ? null : () => unawaited(_refresh()),
            ),
            PureIconButton(
              key: const ValueKey('history-limit'),
              tooltip: t.history.limitTitle,
              icon: Icons.history_toggle_off_rounded,
              onPressed: _mutating ? null : () => unawaited(_editLimit()),
            ),
            if (shown.isNotEmpty)
              PureIconButton(
                key: const ValueKey('history-clear'),
                tooltip: t.history.clear,
                icon: Icons.delete_sweep_outlined,
                onPressed: _mutating ? null : () => unawaited(_confirmClear()),
              ),
          ],
          bottom: _filtering
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: PureTextField(
                      key: const ValueKey('history-filter-field'),
                      controller: _query,
                      focusNode: _queryFocus,
                      placeholder: t.history.filterHint,
                      prefix: const Icon(Icons.filter_alt_outlined, size: 18),
                      suffix: shown.length != records.length
                          ? Text(
                              t.history.filterMatches(count: shown.length),
                              style: PureTheme.of(context).text.caption,
                            )
                          : null,
                    ),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: switch ((_loaded, records.isEmpty, shown.isEmpty)) {
                (false, _, _) => FeedLoadingPlaceholder(
                  delegateBuilder: (width) => RoomGridMetrics.delegateFor(context, width),
                ),
                (_, true, _) => PureEmpty(title: t.history.empty, icon: Icons.history_rounded),
                (_, _, true) => PureEmpty(title: t.history.filterEmpty, icon: Icons.filter_alt_off_outlined),
                _ => _grid(shown),
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double?>(
                valueListenable: _progress,
                builder: (context, value, _) =>
                    value == null ? const SizedBox.shrink() : PureProgress(value: value, height: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The rooms by day: each day's heading with its count, then a grid whose
  /// columns follow the width.
  Widget _grid(List<WatchRecord> records) {
    final groups = _groups(records);
    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        key: const ValueKey('history-grid'),
        slivers: [
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text(
                  '${group.label} · ${group.records.length}',
                  key: ValueKey('history-section-$group.label'),
                  style: PureTheme.of(context).text.bodySmall
                      .copyWith(color: PureTheme.of(context).colors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: PureSpacing.sm),
              sliver: SliverRoomGrid(
                width: constraints.maxWidth,
                itemCount: group.records.length,
                itemBuilder: (context, index) => _HistoryTile(
                  record: group.records[index],
                  onRemove: () => unawaited(_confirmRemove(group.records[index])),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: PureSpacing.xl)),
        ],
      ),
    );
  }

  /// The visible records bucketed by recency; records are newest first, so
  /// the buckets come out in the same order.
  List<({String label, List<WatchRecord> records})> _groups(List<WatchRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<WatchRecord>>{};
    for (final record in records) {
      final watched = record.watchedAt.toLocal();
      final days = today.difference(DateTime(watched.year, watched.month, watched.day)).inDays;
      final label = days <= 0
          ? context.t.history.today
          : days == 1
          ? context.t.history.yesterday
          : days < 7
          ? context.t.history.thisWeek
          : days < 30
          ? context.t.history.thisMonth
          : context.t.history.earlier;
      (groups[label] ??= []).add(record);
    }
    return [for (final entry in groups.entries) (label: entry.key, records: entry.value)];
  }
}

/// One history entry: the shared room card, tappable to resume the room,
/// with a corner remove control over the cover. An entry with watch
/// progress — a replay or VOD that got part-watched — adds a thin progress
/// bar along the card's foot and a resume pill over the caption's free
/// corner; records without progress render exactly as before.
final class _HistoryTile extends ConsumerWidget {
  const new({required this.record, required this.onRemove});

  final WatchRecord record;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = record.room;
    final progress = record.progress;
    return Stack(
      children: [
        RoomCard(
          room: room,
          onOpen: () => RoomRoute(
            siteId: room.ref.platform,
            roomId: room.ref.roomId,
            roomName: room.content.title,
          ).push<void>(context),
          onLongPress: onRemove,
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Tooltip(
            message: context.t.history.remove,
            child: Material(
              // The same dark scrim as the card's cover pills, so the control
              // reads over any thumbnail.
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        if (progress != null) ...[
          Positioned(
            right: 6,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    context.t.history.resume,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              // The card's own corner preference, so the bar reads as the
              // card's foot instead of a strip glued across it.
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(ref.watch(roomCardStyleProvider).cornerRadius),
              ),
              child: SizedBox(
                height: 3,
                child: ColoredBox(
                  color: PureTheme.of(context).colors.fillQuaternary,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: ColoredBox(color: PureTheme.of(context).colors.primary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
