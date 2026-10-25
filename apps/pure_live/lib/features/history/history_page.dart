import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart' show browseLayoutProvider, browseSettingsProvider;
import 'package:pure_live/app/providers/refresh_settings_providers.dart' show historyLimitProvider;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/routing/app_router.dart' show RoomRoute;
import 'package:pure_live/features/history/history_limit_dialog.dart';
import 'package:pure_live/features/history/history_repository.dart';
import 'package:pure_live/features/room/room_details.dart' show copyRoomLink, roomLinkOf;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart' show CardLayout;
import 'package:pure_live/shared/grids/room_cover_chip.dart' show RoomCoverChip;
import 'package:pure_live/shared/images/app_image_cache.dart';
import 'package:pure_live/shared/platforms/platform_display.dart' show localizedSiteName;

/// The live module's history (the reference's `HistoryPage`): the watched
/// rooms grouped by day — Today / Yesterday / Earlier, like the reference's history
/// sections — each as a full-width list card; one row's x drops its
/// record, the header's button drops them all.
///
/// The header also counts the records against the cap, shows the cap's
/// dialog, and toggles a filter over the records (title, streamer, room id
/// and platform); Escape closes the filter first. Every destructive action
/// asks first and reports its outcome.
final class HistoryPage extends ConsumerStatefulWidget {
  /// The history page.
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

final class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  bool _filtering = false;

  /// A destructive change is running; its buttons wait.
  bool _busy = false;

  /// The refresh's progress (0..1); null when none runs.
  double? _progress;

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final history = ref.watch(historyProvider);
    if (!history.ready) {
      return const _SkeletonList();
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
    return CallbackShortcuts(
      // Escape answers the filter first: it clears the query, then closes.
      // Closed, Escape stays available to the layers above.
      bindings: {if (_filtering) const SingleActivator(LogicalKeyboardKey.escape): _handleEscape},
      child: PopScope(
        canPop: !_filtering,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _filtering) _closeFilter();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              total: history.records.length,
              limit: limit,
              matches: shown.length,
              filtering: _filtering,
              busy: _busy,
              canClear: shown.isNotEmpty,
              query: _query,
              queryFocus: _queryFocus,
              onQueryChanged: (_) => setState(() {}),
              onToggleFilter: _toggleFilter,
              onEditLimit: () => unawaited(_editLimit()),
              onRefresh: () => unawaited(_refreshAll(history.records)),
              onClear: () => unawaited(_clear()),
            ),
            if (_progress case final progress?)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s6),
                child: DsProgressBar(value: progress, semanticLabel: t.history.refresh),
              ),
            Expanded(child: _body(t, history.records, shown)),
          ],
        ),
      ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          for (final (header, records) in sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.s8, bottom: DsSpace.s4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  header,
                  style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
                ),
              ),
            ),
            if (layout == CardLayout.list)
              for (final (room, _) in records)
                _HistoryCard(
                  room: room,
                  onOpen: () => unawaited(
                    context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
                  ),
                  onRemove: _busy ? null : () => unawaited(_remove(room)),
                )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: settings.homeCardExtent,
                  crossAxisSpacing: settings.crossSpacing,
                  mainAxisSpacing: settings.mainSpacing,
                  childAspectRatio: 1.35,
                ),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final (room, watchedAt) = records[index];
                  return _HistoryGridCard(
                    room: room,
                    watchedAt: watchedAt,
                    onOpen: () => unawaited(
                      context.push(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
                    ),
                    onRemove: _busy ? null : () => unawaited(_remove(room)),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  /// The records the filter keeps; all of them while it is closed or its
  /// query is blank.
  List<(LiveRoom, DateTime)> _filtered(List<(LiveRoom, DateTime)> records) {
    final needle = _filtering ? _query.text.trim().toLowerCase() : '';
    if (needle.isEmpty) return records;
    return [
      for (final record in records)
        if (_matches(record.$1, needle)) record,
    ];
  }

  /// Whether [room]'s title, streamer, room id, platform id or platform
  /// name contains [needle] (any case).
  bool _matches(LiveRoom room, String needle) {
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

  void _toggleFilter() {
    if (_filtering) {
      _closeFilter();
    } else {
      setState(() => _filtering = true);
    }
  }

  void _closeFilter() {
    if (!_filtering) return;
    setState(() {
      _filtering = false;
      _query.clear();
    });
  }

  /// Clears the query but leaves the field open.
  void _resetFilter() {
    _query.clear();
    setState(() {});
  }

  /// Escape clears the query, and closes the filter once it is empty.
  void _handleEscape() {
    if (!_filtering) return;
    if (_query.text.isNotEmpty) {
      _resetFilter();
    } else {
      _closeFilter();
    }
  }

  /// Re-reads every record's room state, keeping each watch moment; the
  /// failures are counted rather than hidden.
  Future<void> _refreshAll(List<(LiveRoom, DateTime)> records) async {
    if (_busy || records.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final failed = await ref.read(historyProvider.notifier).refreshRooms(
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

/// The page's header: the count against the cap, the filter toggle, the cap
/// button and clear. Open, the filter's field and its live match count sit
/// under them in the same block.
final class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.limit,
    required this.matches,
    required this.filtering,
    required this.busy,
    required this.canClear,
    required this.query,
    required this.queryFocus,
    required this.onQueryChanged,
    required this.onToggleFilter,
    required this.onEditLimit,
    required this.onRefresh,
    required this.onClear,
  });

  final int total;
  final int limit;
  final int matches;
  final bool filtering;
  final bool busy;
  final bool canClear;
  final TextEditingController query;
  final FocusNode queryFocus;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleFilter;
  final VoidCallback onEditLimit;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s8,
        children: [
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                t.history.recordCount(count: total, limit: limit),
                style: theme.typography.small.copyWith(color: colors.textMuted),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.refreshCw),
                onPressed: busy || total == 0 ? null : onRefresh,
                child: Text(t.history.refresh),
              ),
              DsButton(
                variant: filtering ? DsButtonVariant.tinted : DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: DsIcon(filtering ? DsIcons.filterX : DsIcons.filter),
                onPressed: total == 0 && !filtering ? null : onToggleFilter,
                child: Text(filtering ? t.history.filterClose : t.history.filter),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.gauge),
                onPressed: busy ? null : onEditLimit,
                child: Text(t.history.limitAction),
              ),
              DsButton(
                variant: DsButtonVariant.dangerSoft,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.trash2),
                onPressed: busy || !canClear ? null : onClear,
                child: Text(t.history.clear),
              ),
            ],
          ),
          if (filtering) ...[
            DsSearchField(
              key: const ValueKey('history-filter-field'),
              controller: query,
              focusNode: queryFocus,
              autofocus: true,
              placeholder: t.history.filterHint,
              semanticLabel: t.history.filter,
              onChanged: onQueryChanged,
            ),
            if (query.text.trim().isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  t.history.filterMatches(count: matches),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One watched room as a list card: the cover as a thumb, the title, the
/// streamer, and the record's remove button.
final class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.room, required this.onOpen, required this.onRemove});

  final LiveRoom room;

  /// Opens the room again.
  final VoidCallback onOpen;

  /// Null while another change runs.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    return DsContextMenuRegion(
      semanticLabel: t.common.more,
      items: _historyMenuItems(context, room, onOpen: onOpen, onRemove: onRemove),
      child: DsPressable(
        onPressed: onOpen,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
          padding: const EdgeInsets.all(DsSpace.s8),
          decoration: DsBoxDecoration(
            color: hovered ? colors.hover : null,
            borderRadius: BorderRadius.circular(theme.radii.card),
            shadows: hovered
                ? [DsShadow(color: colors.overlay, blur: 24, offset: const Offset(0, 8))]
                : const <DsShadow>[],
          ),
          child: Row(
            spacing: DsSpace.s12,
            children: [
              SizedBox(
                width: theme.sizes.lg * 2,
                child: DsImage(
                  image: cachedImage(room.content.coverUrl),
                  aspectRatio: 16 / 9,
                  semanticLabel: room.content.title,
                  style: DsImageStyle(
                    borderRadius: BorderRadius.circular(theme.radii.nested(theme.radii.card, DsSpace.s8)),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      room.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Text(
                      room.anchor?.name ?? room.ref.roomId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              DsPressable(
                semanticLabel: context.t.history.remove,
                onPressed: onRemove,
                builder: (context, states, _) {
                  final hovered = states.contains(WidgetState.hovered);
                  return DsIcon(
                    DsIcons.x,
                    size: theme.sizes.iconSm,
                    color: hovered ? colors.danger.fill : colors.textSubtle,
                  );
                },
              ),
            ],
          ),
        );
        },
      ),
    );
  }
}

/// The history card's context menu: open, copy the room's link, remove.
List<Widget> _historyMenuItems(
  BuildContext context,
  LiveRoom room, {
  required VoidCallback onOpen,
  required VoidCallback? onRemove,
}) {
  final t = context.t;
  final link = roomLinkOf(room);
  return [
    DsMenuItem(
      leading: const DsIcon(DsIcons.play),
      label: Text(t.history.openRoom),
      onPressed: onOpen,
    ),
    if (link.isNotEmpty)
      DsMenuItem(
        leading: const DsIcon(DsIcons.link),
        label: Text(t.room.copyLink),
        onPressed: () => unawaited(copyRoomLink(context, room)),
      ),
    const DsMenuDivider(),
    DsMenuItem(
      leading: const DsIcon(DsIcons.trash2),
      label: Text(t.history.remove),
      destructive: true,
      onPressed: onRemove,
    ),
  ];
}

/// One watched room as a grid card: its cover, the title and streamer
/// beneath, and the watch clock over the picture; the same context menu as
/// the list card.
final class _HistoryGridCard extends StatelessWidget {
  const _HistoryGridCard({
    required this.room,
    required this.watchedAt,
    required this.onOpen,
    required this.onRemove,
  });

  final LiveRoom room;
  final DateTime watchedAt;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsContextMenuRegion(
      semanticLabel: context.t.common.more,
      items: _historyMenuItems(context, room, onOpen: onOpen, onRemove: onRemove),
      child: DsCard(
        onPressed: onOpen,
        style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                DsImage(
                  image: cachedImage(room.content.coverUrl),
                  aspectRatio: 16 / 9,
                  semanticLabel: room.content.title,
                  style: DsImageStyle(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
                  ),
                ),
                PositionedDirectional(
                  bottom: DsSpace.s6,
                  end: DsSpace.s6,
                  child: RoomCoverChip(text: _watchClock(watchedAt)),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 3,
                  children: [
                    Text(
                      room.content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                    Text(
                      room.anchor?.name ?? room.ref.roomId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The moment watched, as a clock on today's records and a short date
  /// otherwise.
  static String _watchClock(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final clock = '${two(local.hour)}:${two(local.minute)}';
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay ? clock : '${two(local.month)}-${two(local.day)}';
  }
}

/// The list's opening placeholder.
final class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      children: [
        for (var i = 0; i < 8; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: DsSpace.s8),
            child: _HistoryCardSkeleton(),
          ),
      ],
    );
  }
}

/// One history card's placeholder.
final class _HistoryCardSkeleton extends StatelessWidget {
  const _HistoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(DsSpace.s8),
      child: Row(
        spacing: DsSpace.s12,
        children: [
          DsSkeleton.block(width: theme.sizes.lg * 2, height: theme.sizes.lg * 2 * 9 / 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                DsSkeleton(width: DsSpace.s32),
                DsSkeleton(width: DsSpace.s20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
