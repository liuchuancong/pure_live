import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/history/history.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The switcher's groups, in the reference's order minus the source list:
/// the followed rooms on air, the watch history and followed replays.
enum RoomSwitchGroup { onAir, history, replays }

/// The rooms each group offers, the current room left out.
({List<LiveRoom> onAir, List<LiveRoom> history, List<LiveRoom> replays}) roomSwitcherLists({
  required List<LiveRoom> follows,
  required List<LiveRoom> history,
  required LiveRoom current,
}) {
  bool other(LiveRoom room) => room.ref.identityKey != current.ref.identityKey;
  return (
    onAir: [
      for (final room in follows)
        if (room.broadcast.isLiveNow && other(room)) room,
    ],
    history: [
      for (final room in history)
        if (other(room)) room,
    ],
    replays: [
      for (final room in follows)
        if (room.broadcast.isRecord && other(room)) room,
    ],
  );
}

/// The portrait fullscreen's swipe list: followed rooms on air, or the
/// history when none is on. The current room stays in the list so its
/// neighbours can be found; an absent current room starts from the
/// first/last.
List<LiveRoom> roomSwipeList({
  required List<LiveRoom> follows,
  required List<LiveRoom> history,
  required LiveRoom current,
}) {
  final onAir = [
    for (final room in follows)
      if (room.broadcast.isLiveNow) room,
  ];
  final watched = [for (final room in history) room];
  if (onAir.any((room) => room.ref.identityKey == current.ref.identityKey)) return onAir;
  if (watched.any((room) => room.ref.identityKey == current.ref.identityKey)) return watched;
  return onAir.isNotEmpty ? onAir : watched;
}

/// Opens the room switcher over [current]: the followed rooms on air, the
/// watch history and followed replays, in the grid or list style. A pick
/// replaces the room page, so going back does not return to the old room.
Future<void> showRoomSwitcher(BuildContext context, {required LiveRoom current}) =>
    showDsDialog<void>(context: context, builder: (context) => _RoomSwitcherDialog(current: current));

final class _RoomSwitcherDialog extends ConsumerStatefulWidget {
  const _RoomSwitcherDialog({required this.current});

  final LiveRoom current;

  @override
  ConsumerState<_RoomSwitcherDialog> createState() => _RoomSwitcherDialogState();
}

final class _RoomSwitcherDialogState extends ConsumerState<_RoomSwitcherDialog> {
  RoomSwitchGroup? _group;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final follows = ref.watch(followsProvider).rooms;
    final history = [for (final (room, _) in ref.watch(historyProvider).records) room];
    final lists = roomSwitcherLists(follows: follows, history: history, current: widget.current);
    final firstNonEmpty = lists.onAir.isNotEmpty
        ? RoomSwitchGroup.onAir
        : lists.history.isNotEmpty
        ? RoomSwitchGroup.history
        : RoomSwitchGroup.replays;
    final group = _group ?? firstNonEmpty;
    final rooms = switch (group) {
      RoomSwitchGroup.onAir => lists.onAir,
      RoomSwitchGroup.history => lists.history,
      RoomSwitchGroup.replays => lists.replays,
    };
    final layout = ref.watch(roomSwitcherLayoutProvider);
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = math.max(280, math.min(720, screen.width - 32)).toDouble();
    final dialogHeight = math.max(260, math.min(480, screen.height - 160)).toDouble();
    final counts = {
      RoomSwitchGroup.onAir: lists.onAir.length,
      RoomSwitchGroup.history: lists.history.length,
      RoomSwitchGroup.replays: lists.replays.length,
    };
    String label(RoomSwitchGroup value) => switch (value) {
      RoomSwitchGroup.onAir => t.room.switchOnAir,
      RoomSwitchGroup.history => t.room.switchHistory,
      RoomSwitchGroup.replays => t.room.switchReplays,
    };
    return DsDialog(
      title: Text(t.room.switchRoom),
      description: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            Row(
              children: [
                Expanded(
                  child: DsChoiceChips<RoomSwitchGroup>(
                    value: group,
                    semanticLabel: t.room.switchRoom,
                    options: [
                      for (final value in RoomSwitchGroup.values)
                        DsChipOption(value: value, label: Text('${label(value)} ${counts[value]}')),
                    ],
                    onChanged: (value) => setState(() => _group = value),
                  ),
                ),
                const SizedBox(width: DsSpace.s8),
                DsButton.icon(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  semanticLabel: layout == RoomSwitcherLayout.grid ? t.room.switchShowList : t.room.switchShowGrid,
                  onPressed: () => unawaited(
                    ref
                        .read(roomSwitcherLayoutProvider.notifier)
                        .set(layout == RoomSwitcherLayout.grid ? RoomSwitcherLayout.list : RoomSwitcherLayout.grid),
                  ),
                  icon: DsIcon(layout == RoomSwitcherLayout.grid ? DsIcons.list : DsIcons.layoutGrid, size: 16),
                ),
              ],
            ),
            Expanded(
              child: rooms.isEmpty
                  ? Center(
                      child: Text(
                        t.room.switchEmpty,
                        style: theme.typography.body.copyWith(color: colors.textMuted),
                      ),
                    )
                  : layout == RoomSwitcherLayout.grid
                  ? GridView.builder(
                      padding: const EdgeInsets.all(DsSpace.s4),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 224,
                        mainAxisExtent: 164,
                        crossAxisSpacing: DsSpace.s8,
                        mainAxisSpacing: DsSpace.s8,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) => _SwitcherCard(
                        room: rooms[index],
                        onPressed: () => _open(rooms[index]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(DsSpace.s4),
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) => DsLine(color: colors.border),
                      itemBuilder: (context, index) => _SwitcherRow(
                        room: rooms[index],
                        onPressed: () => _open(rooms[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      style: DsDialogStyle(width: dialogWidth + 40),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }

  void _open(LiveRoom room) {
    final router = ref.read(appRouterProvider);
    Navigator.of(context).pop();
    unawaited(
      router.pushReplacement(RoomRoute(platform: room.ref.platform, roomId: room.ref.roomId).location),
    );
  }
}

final class _SwitcherCard extends ConsumerWidget {
  const _SwitcherCard({required this.room, required this.onPressed});

  final LiveRoom room;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final site = ref.watch(sitesProvider).getById(room.ref.platform);
    final platform = site == null ? room.ref.platform : localizedSiteName(site);
    final cover = room.content.coverUrl.trim();
    return DsCard(
      onPressed: onPressed,
      style: DsCardStyle(padding: EdgeInsets.zero, borderRadius: BorderRadius.circular(theme.radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
              child: cover.isEmpty
                  ? ColoredBox(color: colors.control)
                  : DsImage(image: cachedImage(cover)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  room.content.title.trim().isEmpty ? room.ref.roomId : room.content.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.small.copyWith(color: colors.text),
                ),
                Text(
                  room.broadcast.isLiveNow ? '$platform · ${context.t.room.switchLive}' : platform,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _SwitcherRow extends ConsumerWidget {
  const _SwitcherRow({required this.room, required this.onPressed});

  final LiveRoom room;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final site = ref.watch(sitesProvider).getById(room.ref.platform);
    final platform = site == null ? room.ref.platform : localizedSiteName(site);
    final cover = room.content.coverUrl.trim();
    return DsListRow(
      onPressed: onPressed,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 112,
          height: 63,
          child: cover.isEmpty
              ? ColoredBox(color: colors.control)
              : DsImage(image: cachedImage(cover)),
        ),
      ),
      title: Text(
        room.content.title.trim().isEmpty ? room.ref.roomId : room.content.title.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      description: Text(
        room.broadcast.isLiveNow ? '$platform · ${context.t.room.switchLive}' : platform,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
