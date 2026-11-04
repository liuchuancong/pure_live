import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_iptv/live_iptv.dart';
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_head_actions.dart';
import 'package:pure_live/layouts/page_layout_scope.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart'
    show IptvBrowseSettings, iptvBrowseSettingsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_recent.dart';
import 'package:pure_live/modules/iptv/views/iptv_group_rail.dart';
import 'package:pure_live/modules/iptv/views/iptv_guide_panel.dart' show iptvStartOfDay;
import 'package:pure_live/modules/iptv/views/iptv_panels.dart' show IptvChannelLogo, IptvNowCell;
import 'package:pure_live/shared/shared.dart' show LiveWindow, NavigationItem, showActionsPanel;

/// One watched channel and the record that says when.
typedef _Watched = ({IptvRecentEntry entry, IptvChannel channel});

/// The IPTV module's 最近观看: the channels the player has opened, newest
/// first. The record is this module's own — it follows the library's channel
/// ids, so a re-import keeps the entries attached to the same channels.
///
/// The list is read by when it happened: one head per day, the same three the
/// live module's history page walks. The group is a filter behind one entry,
/// exactly as it is on the channel and guide surfaces, and the same rule
/// follows — a row only names its group while the list runs across more than
/// one. Each row also says what its channel is showing **now**, in the same
/// cell the channel table reads, because going back to a channel is a question
/// about this minute and not about the record. The head is the module's page
/// head, with the filter and the clearing at its end.
final class IptvRecentPage extends ConsumerStatefulWidget {
  /// The module's history page.
  const IptvRecentPage({super.key});

  @override
  ConsumerState<IptvRecentPage> createState() => _IptvRecentPageState();
}

final class _IptvRecentPageState extends ConsumerState<IptvRecentPage> {
  /// The group the list is narrowed to; null walks every watched channel. Held
  /// here rather than on the channels controller: this page reads its own
  /// archive, and the browser's favourites scope and reveal are no part of it.
  String? _group;

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The on-air mark and its progress follow the clock, not a reload — the
    // rule the channel, guide and player surfaces already keep.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _open(IptvChannel channel) {
    unawaited(context.push(RouteNames.iptvPlay.replaceFirst(':channelId', channel.id), extra: channel));
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.iptv.recentClearTitle,
      description: t.iptv.recentClearDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(iptvRecentProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final recent = ref.watch(iptvRecentProvider);
    // Read here, not in the row: a sliver builds its rows while the list
    // scrolls, and a provider watched then would be watched outside the page's
    // own build.
    final browse = ref.watch(iptvBrowseSettingsProvider);
    final library = ref.watch(iptvLibraryProvider).value;
    final channels = {for (final channel in library?.channels ?? const <IptvChannel>[]) channel.id: channel};
    final rows = [
      for (final entry in recent)
        if (channels[entry.channelId] case final channel?) (entry: entry, channel: channel),
    ];
    // The groups the archive itself holds, in the library's own display order.
    final counts = <String, int>{};
    for (final row in rows) {
      final group = iptvGroupKeyOf(row.channel);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    final order = library?.groupNames ?? const <String>[];
    final filter = (
      groups: [
        for (final name in order)
          if (counts.containsKey(name)) name,
        for (final name in counts.keys)
          if (!order.contains(name)) name,
      ],
      groupCounts: counts,
      totalCount: rows.length,
      // A group whose last row was just removed is not a filter any more; the
      // entry says 分组 and the list shows every channel again.
      selectedGroup: _group != null && counts.containsKey(_group) ? _group : null,
    );
    final shown = [
      for (final row in rows)
        if (filter.selectedGroup == null || iptvGroupKeyOf(row.channel) == filter.selectedGroup) row,
    ];
    // What each listed channel is on air with, read at one shared instant: a
    // "now" that moved per row would disagree with the progress bar under it.
    // Skipped whole when the module's 正在播出 switch is off — a guide read is
    // not work to do for a line nobody asked to see.
    final moment = DateTime.now();
    final slots = library == null || !browse.showProgrammeLine
        ? const <String, IptvProgrammeSlot>{}
        : {for (final row in shown) row.channel.id: library.programmeSlot(row.channel, now: moment)};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecentToolbar(
          filter: filter,
          showing: shown.length,
          onSelectGroup: (group) => setState(() => _group = group),
          // The archive is kept most-recent-first, so the head of what this
          // filter shows is the channel the viewer walked away from last;
          // opening it from the head is the shortest way back to the picture.
          onResume: shown.isEmpty ? null : () => _open(shown.first.channel),
          onClear: rows.isEmpty ? null : () => unawaited(_clear(context, ref)),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.history),
                    title: Text(t.iptv.recentEmptyTitle),
                    description: Text(t.iptv.recentEmptyDescription),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    for (final section in _daySections(t, shown, DateTime.now())) ...[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
                        sliver: SliverToBoxAdapter(
                          child: _DayHeader(label: section.label, count: section.rows.length),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: inset),
                        sliver: SliverList.separated(
                          itemCount: section.rows.length,
                          separatorBuilder: (_, _) => const DsDivider(),
                          itemBuilder: (context, index) => _row(
                            context,
                            ref,
                            section.rows[index],
                            browse,
                            slots,
                            nameGroup: filter.selectedGroup == null,
                            // 今天 and 昨天 name the very day the rows
                            // happened on, so their rows only owe the clock;
                            // 更早 spans days and has to say which.
                            namedDay: section.oneDay,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: DsSpace.s24)),
                  ],
                ),
        ),
      ],
    );
  }

  /// One watched channel: the row language the module's channel list uses —
  /// logo, name over its dial number, what is on it right now, the record's
  /// own stamp, and the one action that takes this record out again.
  Widget _row(
    BuildContext context,
    WidgetRef ref,
    _Watched row,
    IptvBrowseSettings browse,
    Map<String, IptvProgrammeSlot> slots, {
    required bool nameGroup,
    required bool namedDay,
  }) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final (:entry, :channel) = row;
    final watched = t.iptv.recentWatched(time: recentTimeLabel(entry.watchedAt, withDate: !namedDay));
    final number = browse.showChannelNumber ? channel.number : null;
    final stamp = Text(
      nameGroup ? '${iptvGroupLabel(t, iptvGroupKeyOf(channel))} · $watched' : watched,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.caption.copyWith(color: colors.textSubtle),
    );
    final slot = slots[channel.id];
    // A row says what is on only where the guide answers. Its absence is the
    // channel table's column to report — a hundred rows each reading
    // 「暂无节目单」is one sentence said a hundred times.
    final programme = slot != null && !slot.isEmpty
        ? ConstrainedBox(
            // The measure the module's other now-playing lines keep (the
            // music bar's): a bar that runs the whole width of a wide row
            // reads as a rule line, not as progress.
            constraints: const BoxConstraints(maxWidth: 420),
            child: IptvNowCell(slot: slot),
          )
        : null;
    return DsListRow(
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
      description: programme == null
          ? stamp
          : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [programme, stamp]),
      trailing: DsButton.icon(
        variant: DsButtonVariant.ghost,
        size: DsSize.sm,
        semanticLabel: t.iptv.recentRemove,
        onPressed: () => unawaited(ref.read(iptvRecentProvider.notifier).remove(channel.id)),
        icon: const DsIcon(DsIcons.x, size: 16),
      ),
      onPressed: () => _open(channel),
    );
  }

  /// The archive cut at the days it happened: 今天, 昨天, then everything
  /// before — the three the live module's history page uses, and the three a
  /// viewer counts in when asking "when did I leave that channel on".
  /// A section's `oneDay` says whether its head already names the calendar day,
  /// which is what decides whether its rows still owe the date.
  static List<({bool oneDay, String label, List<_Watched> rows})> _daySections(
    Translations t,
    List<_Watched> rows,
    DateTime now,
  ) {
    final today = iptvStartOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final buckets = <(String, List<_Watched>)>[(t.iptv.today, []), (t.iptv.yesterday, []), (t.iptv.recentEarlier, [])];
    for (final row in rows) {
      final day = iptvStartOfDay(row.entry.watchedAt);
      final index = day == today
          ? 0
          : day == yesterday
          ? 1
          : 2;
      buckets[index].$2.add(row);
    }
    return [
      for (final (index, (label, section)) in buckets.indexed)
        if (section.isNotEmpty) (oneDay: index < 2, label: label, rows: section),
    ];
  }
}

/// The page's one tool line: the count the filter makes at its start, the
/// open-channel verb, the group's entry and the clearing at its end. A narrow
/// page keeps the count alone and hands the verbs to the shell's head — the
/// filter entry among them, since narrowing is a filter and filters travel
/// with the rest of the head's verbs.
final class _RecentToolbar extends ConsumerWidget {
  const _RecentToolbar({
    required this.filter,
    required this.showing,
    required this.onSelectGroup,
    required this.onResume,
    required this.onClear,
  });

  /// The groups the archive holds, with the open one.
  final IptvGroupFilter filter;

  /// How many channels the list shows under the open filter.
  final int showing;

  /// Narrows the list to one group; null takes every watched channel.
  final ValueChanged<String?> onSelectGroup;

  /// Goes back to the most recently watched channel of what the filter shows;
  /// null while the list is empty, since there is nothing to go back to.
  final VoidCallback? onResume;

  /// Drops every record; null while there is nothing to drop.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final narrow = PageLayoutScope.isNarrow(context);
    // One group in the archive is nothing to choose; the rows would only be
    // narrowed to the list they already are.
    final groupEntry = filter.groups.length > 1 ? IptvGroupEntry(filter: filter, onSelect: onSelectGroup) : null;
    final resume = onResume == null
        ? null
        : DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            onPressed: onResume,
            leading: const DsIcon(DsIcons.play, size: 15),
            child: Text(t.iptv.openChannel),
          );
    final clear = onClear == null
        ? null
        : DsButton(
            variant: DsButtonVariant.dangerSoft,
            size: DsSize.sm,
            onPressed: onClear,
            leading: const DsIcon(DsIcons.trash2, size: 15),
            child: Text(t.iptv.recentClear),
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
                if (onResume != null)
                  DsListRow(
                    leading: const DsIcon(DsIcons.play, size: 16),
                    title: Text(t.iptv.openChannel),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onResume!();
                    },
                  ),
                if (onClear != null)
                  DsListRow(
                    leading: const DsIcon(DsIcons.trash2, size: 16),
                    title: Text(t.iptv.recentClear),
                    destructive: true,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onClear!();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (narrow) {
      publishPageHeadActions(context, ref, NavigationItem.iptvRecent, [?groupEntry, more]);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = LiveWindow.pageInset(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
          child: SizedBox(
            height: 44,
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: t.iptv.recentTitle,
                          style: theme.typography.labelStrong.copyWith(color: colors.text),
                        ),
                        TextSpan(
                          text: '  ·  ',
                          style: theme.typography.small.copyWith(color: colors.textSubtle),
                        ),
                        TextSpan(
                          text: t.iptv.recentCount(count: showing),
                          style: theme.typography.small.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!narrow) ...[?resume, ?groupEntry, ?clear],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One day's head: its name and how many channels it holds, the pair the live
/// module's history page already puts over each of its days.
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

/// A history record's moment: "HH:mm", or "MM-DD HH:mm" once the day it
/// happened on is no longer named above it.
String recentTimeLabel(DateTime time, {bool withDate = true}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(time.hour)}:${two(time.minute)}';
  return withDate ? '${two(time.month)}-${two(time.day)} $clock' : clock;
}
