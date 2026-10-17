import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show HistoryRepository, WatchRecord;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/room/room_routes.dart';
import 'package:pure_live/features/popular/room_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// How many records render before the scroll loads more (the repository
/// already holds the whole capped list; the page just reveals it in chunks).
const int _pageChunk = 30;

/// The watch history (3.x `HistoryPage`): what the user watched, newest
/// first, grouped by when — today, yesterday, this week, this month,
/// earlier. An entry re-opens its room; one entry or the whole list can be
/// removed, each behind its own confirmation. The list renders from the
/// repository's own change stream, so a second window's watches appear
/// here too.
final class HistoryPage extends ConsumerStatefulWidget {
  /// The history page.
  const new({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

final class _HistoryPageState extends ConsumerState<HistoryPage> {
  StreamSubscription<void>? _changes;
  late final ScrollController _scroll = ScrollController()..addListener(_onScroll);
  int _limit = _pageChunk;

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_repository.load());
    _changes = _repository.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  /// Reveals the next chunk when the scroll nears the end.
  void _onScroll() {
    final records = _repository.records;
    if (mounted && _limit < records.length && _scroll.position.extentAfter < 600) {
      setState(() => _limit += _pageChunk);
    }
  }

  /// The visible records bucketed by recency; records are newest first, so
  /// the buckets come out in the same order.
  List<({String label, List<WatchRecord> records})> _groups(List<WatchRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<WatchRecord>>{};
    for (final record in records.take(_limit)) {
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

  Future<void> _confirmRemove(WatchRecord record) async {
    final confirmed = await _confirm(
      context.t.history.remove,
      context.t.history.removeConfirm,
      context.t.history.remove,
    );
    if (confirmed) {
      await _repository.remove(record.room);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await _confirm(context.t.history.clear, context.t.history.clearConfirm, context.t.history.clear);
    if (confirmed) {
      await _repository.clear();
    }
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
    final records = _repository.records;
    return PureScaffold(
      appBar: PureAppBar(
        title: context.t.tabs.history,
        actions: [
          if (records.isNotEmpty)
            PureIconButton(
              tooltip: context.t.history.clear,
              icon: Icons.delete_sweep_outlined,
              onPressed: _confirmClear,
            ),
          const SettingsEntryButton(),
        ],
      ),
      body: records.isEmpty
          ? PureEmpty(title: context.t.history.empty, icon: Icons.history_rounded)
          : LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                controller: _scroll,
                slivers: [
                  for (final group in _groups(records)) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.md, PureSpacing.sm, PureSpacing.xs),
                        child: Text(
                          group.label,
                          style: PureTheme.of(context).text.bodySmall.copyWith(
                            color: PureTheme.of(context).colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: PureSpacing.sm),
                      sliver: SliverGrid(
                        gridDelegate: RoomGridMetrics.delegateFor(context, constraints.maxWidth),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _HistoryTile(
                            record: group.records[index],
                            onRemove: () => unawaited(_confirmRemove(group.records[index])),
                          ),
                          childCount: group.records.length,
                        ),
                      ),
                    ),
                  ],
                  if (records.length > _limit)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(PureSpacing.md),
                        child: Center(child: PureSpinner()),
                      ),
                    ),
                ],
              ),
            ),
    );
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
