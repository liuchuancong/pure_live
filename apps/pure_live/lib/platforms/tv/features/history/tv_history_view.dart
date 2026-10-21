import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show HistoryRepository, WatchRecord;
import 'package:live_sites/live_sites.dart' show LiveRoom;
import 'package:pure_live/app/app_providers.dart' show historyRepositoryProvider, sitesProvider;
import 'package:pure_live/features/follow/live_alert_service.dart' show liveAlertServiceProvider;
import 'package:pure_live/features/room/room_playlist.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/tv/widgets/tv_pill.dart';
import 'package:pure_live/platforms/tv/widgets/tv_room_wall.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// When a watch happened, in the four sections the TV pane offers as tabs.
enum TvHistoryDay {
  /// Today.
  today,

  /// Yesterday.
  yesterday,

  /// Two to six days ago.
  week,

  /// Earlier, or no watch time at all.
  earlier;

  /// The section of a watch at [watchedAt] seen [now] — the reference's
  /// `HistorySection.of`.
  static TvHistoryDay of(DateTime? watchedAt, DateTime now) {
    if (watchedAt == null) {
      return earlier;
    }
    // Rounded: a day across a daylight-saving change is 23 or 25 hours.
    final days =
        (DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).difference(DateTime(watchedAt.year, watchedAt.month, watchedAt.day)).inHours /
                24)
            .round();
    return switch (days) {
      <= 0 => today,
      1 => yesterday,
      < 7 => week,
      _ => earlier,
    };
  }
}

/// 观看记录 on the ten-foot screen: the count against the cap, the day tabs
/// (今天/昨天/近 7 天/更早) and the platforms with their counts, then the wall
/// of watched rooms — newest first inside the section.
///
/// 刷新 asks the platforms which of these rooms still broadcast (the same pass
/// the follows tab runs), 保留数量 sets the cap and 清空 asks first. The panes
/// follow the reference's TV history: sections and platforms as pills, so the
/// D-pad never leaves the wall's row.
final class TvHistoryView extends ConsumerStatefulWidget {
  /// The TV history pane.
  const new({super.key});

  @override
  ConsumerState<TvHistoryView> createState() => _TvHistoryViewState();
}

final class _TvHistoryViewState extends ConsumerState<TvHistoryView> {
  static const String _allPlatforms = '';

  /// The sizes 保留数量 offers; 0 is no limit (the phone's presets).
  static const List<int> _limits = [20, 50, 100, 200, 0];

  TvHistoryDay _day = TvHistoryDay.today;
  String _platform = _allPlatforms;

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_repository.load());
  }

  List<WatchRecord> get _records => _repository.records;

  List<WatchRecord> _inDay() {
    final now = DateTime.now();
    return [
      for (final record in _records)
        if (TvHistoryDay.of(record.watchedAt, now) == _day &&
            (_platform == _allPlatforms || record.room.ref.platform == _platform))
          record,
    ];
  }

  String _dayLabel(Translations t, TvHistoryDay day) => switch (day) {
    TvHistoryDay.today => t.history.today,
    TvHistoryDay.yesterday => t.history.yesterday,
    TvHistoryDay.week => t.history.week,
    TvHistoryDay.earlier => t.history.earlier,
  };

  String _platformLabel(String id) {
    if (id == _allPlatforms) {
      return context.t.follow.all;
    }
    final site = ref.read(sitesProvider).registry.getById(id);
    return site?.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN') ?? id;
  }

  Future<void> _refresh() async {
    await ref.read(liveAlertServiceProvider).refresh();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _clear() async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.history.clear,
      child: Text(context.t.history.clearConfirm),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.history.clear,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true) {
      return;
    }
    await _repository.clear();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _chooseLimit() async {
    final current = ref.read(appPreferencesProvider).historyLimit;
    final picked = await showPureDialog<int>(
      context: context,
      title: context.t.history.limitTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final limit in _limits)
            ListTile(
              // The unlimited row says how many records it keeps (全部
              // 保留), the numbered rows say the cap itself.
              title: Text(limit == 0 ? context.t.history.countUnlimited(count: _repository.records.length) : '$limit'),
              trailing: limit == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(limit),
            ),
        ],
      ),
    );
    if (picked == null) {
      return;
    }
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(historyLimit: picked));
    await _repository.applyCapacity(picked);
    if (mounted) {
      setState(() {});
    }
  }

  void _open(LiveRoom room) =>
      unawaited(openRoomWithPlaylist(context, ref, [for (final record in _inDay()) record.room], room));

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final limit = ref.watch(appPreferencesProvider).historyLimit;
    final records = _records;
    final platforms = <String>[
      _allPlatforms,
      ...{for (final record in records) record.room.ref.platform},
    ];
    final platform = platforms.contains(_platform) ? _platform : _allPlatforms;
    final shown = _inDay();
    final now = DateTime.now();
    final dayCounts = [
      for (final day in TvHistoryDay.values)
        [
          for (final record in records)
            if (TvHistoryDay.of(record.watchedAt, now) == day &&
                (platform == _allPlatforms || record.room.ref.platform == platform))
              record,
        ].length,
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
            child: Row(
              children: [
                Text(t.tabs.history, style: theme.text.title.copyWith(color: theme.colors.text)),
                const SizedBox(width: 12),
                Text(
                  limit == 0
                      ? t.history.countUnlimited(count: records.length)
                      : t.history.countOfLimit(count: records.length, limit: limit),
                  style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
                ),
                const Spacer(),
                TvPill(
                  key: const ValueKey('tv-history-refresh'),
                  label: t.common.refresh,
                  onTap: () => unawaited(_refresh()),
                ),
                const SizedBox(width: 12),
                TvPill(
                  key: const ValueKey('tv-history-limit'),
                  label: t.history.limitTitle,
                  onTap: () => unawaited(_chooseLimit()),
                ),
                const SizedBox(width: 12),
                TvPill(
                  key: const ValueKey('tv-history-clear'),
                  label: t.history.clear,
                  onTap: () => unawaited(_clear()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 48, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var index = 0; index < TvHistoryDay.values.length; index++)
                  TvPill(
                    key: ValueKey('tv-history-day-$index'),
                    label: '${_dayLabel(t, TvHistoryDay.values[index])} ${dayCounts[index]}',
                    selected: _day == TvHistoryDay.values[index],
                    onTap: () => setState(() => _day = TvHistoryDay.values[index]),
                  ),
                const SizedBox(width: 24),
                for (final id in platforms.where((id) => id.isNotEmpty))
                  TvPill(
                    key: ValueKey('tv-history-platform-$id'),
                    label: _platformLabel(id),
                    selected: platform == id,
                    onTap: () => setState(() => _platform = id),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TvRoomWall(
              rooms: [for (final record in shown) record.room],
              onSelect: _open,
              emptyTitle: t.history.empty,
              emptyIcon: Icons.history_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
