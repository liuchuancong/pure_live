import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/room/player_surface.dart' show PlayerSurface;
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_status.dart' show roomSlowProvider, slowAfter;
import 'package:pure_live/features/room/sleep_timer.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// The live room: media_core's player surface above, the room's facts and
/// controls under it, the chat beside them on a wide window.
///
/// The player picture is media_core's bare view; the control layer is the app's own,
/// the picture overlay tells the states the stream goes through (the
/// connecting, the slow open, the recovery, the offline room) with the
/// actions each one offers; the room's own row picks the quality and the
/// line, retries on failure, and follows the streamer. Chat is the
/// danmaku session's messages, a scrolling list; the flying-danmaku
/// overlay is the next floor.
final class RoomPage extends ConsumerStatefulWidget {
  /// The room to open, by platform and room id.
  const RoomPage({required this.platform, required this.roomId, super.key});

  /// The room's platform id.
  final String platform;

  /// The room's platform room id.
  final String roomId;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

final class _RoomPageState extends ConsumerState<RoomPage> {
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    // The room never opens from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(roomProvider.notifier).open(platform: widget.platform, roomId: widget.roomId));
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _watchSlow(RoomState room) {
    final connecting = room.room != null && room.handle == null && !room.playback.playing;
    if (connecting && _slowTimer == null) {
      _slowTimer = Timer(slowAfter, () {
        ref.read(roomSlowProvider.notifier).slow = true;
      });
    } else if (!connecting && _slowTimer != null) {
      _slowTimer?.cancel();
      _slowTimer = null;
      ref.read(roomSlowProvider.notifier).slow = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    _watchSlow(room);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PlayerSurface(roomState: room, barrage: ref.read(roomProvider.notifier).barrage),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _RoomFacts(room: room),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: _RoomControls(room: room),
        ),
        Expanded(child: _ChatFeed(room: room)),
      ],
    );
  }
}

/// The follows the room page reads (the follow button's watched list).
final followsRoomProvider = Provider<List<LiveRoom>>((ref) {
  ref.watch(followsProvider);
  return ref.read(followsProvider).rooms;
});

/// The room's facts: the title, the streamer, the audience figure and the
/// follow button.
final class _RoomFacts extends ConsumerWidget {
  const _RoomFacts({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final detail = room.room;
    if (detail == null) {
      return DsSkeleton(width: DsSpace.s32, height: theme.sizes.iconMd);
    }
    final figure = detail.audience.primaryMetric == LiveAudienceMetricType.onlineViewers
        ? detail.audience.onlineViewers
        : detail.audience.popularity;
    final followed = ref.watch(
      followsRoomProvider.select((follows) {
        final key = detail.ref.identityKey;
        return follows.any((followed_) => followed_.ref.identityKey == key);
      }),
    );
    return Row(
      spacing: DsSpace.s12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s3,
            children: [
              Text(
                detail.content.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Row(
                spacing: DsSpace.s8,
                children: [
                  Text(
                    detail.anchor?.name ?? detail.ref.roomId,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                  if (figure != null)
                    Text(
                      AudienceFormat.format(figure),
                      style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                    ),
                ],
              ),
            ],
          ),
        ),
        DsButton(
          onPressed: () => unawaited(ref.read(roomProvider.notifier).toggleFollow()),
          leading: DsIcon(followed ? DsIcons.heart : DsIcons.heartCrack, size: theme.sizes.iconSm),
          child: Text(followed ? context.t.room.unfollow : context.t.room.follow),
        ),
      ],
    );
  }
}

/// The room's own controls: the quality and the line the playback sits
/// on, and the pause.
final class _RoomControls extends ConsumerWidget {
  const _RoomControls({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(roomProvider.notifier);
    final t = context.t;
    return Row(
      spacing: DsSpace.s8,
      children: [
        if (room.qualities.length > 1)
          DsSelect<LivePlayQuality>(
            value: room.quality ?? room.qualities.first,
            onChanged: (quality) => unawaited(controller.selectQuality(quality ?? room.qualities.first)),
            options: [for (final quality in room.qualities) DsSelectOption(value: quality, label: quality.label)],
            placeholder: t.room.quality,
            leading: DsIcon(DsIcons.gauge, size: DsTheme.of(context).sizes.iconSm),
            semanticLabel: t.room.quality,
          ),
        if (room.lines.length > 1)
          DsSelect<int>(
            value: 0,
            onChanged: (index) => unawaited(controller.selectLine(index ?? 0)),
            options: [
              for (final (index, line) in room.lines.indexed)
                DsSelectOption(
                  value: index,
                  label: line.lineLabel ?? t.room.line(n: index + 1),
                ),
            ],
            placeholder: t.room.lineLabel,
            leading: DsIcon(DsIcons.route, size: DsTheme.of(context).sizes.iconSm),
            semanticLabel: t.room.lineLabel,
          ),
        _SleepChip(),
        const Spacer(),
        DsButton(
          onPressed: () => unawaited(controller.togglePlayPause()),
          leading: DsIcon(room.playback.playing ? DsIcons.pause : DsIcons.play, size: DsTheme.of(context).sizes.iconSm),
          child: Text(room.playback.playing ? t.room.pause : t.room.play),
        ),
      ],
    );
  }
}

/// The chat feed: the danmaku session's messages, newest at the bottom,
/// the sender's name before the text in the sender's color.
final class _ChatFeed extends ConsumerWidget {
  const _ChatFeed({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    if (room.chat.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.messageCircle), title: Text(t.room.noChat)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
      itemCount: room.chat.length,
      itemBuilder: (context, index) {
        final message = room.chat[index];
        return _ChatLine(message: message);
      },
    );
  }
}

/// One chat line: the sender and the text, the platform's own colour when
/// it gave one.
final class _ChatLine extends StatelessWidget {
  const _ChatLine({required this.message});

  final LiveMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final sender = message.sender;
    final nameStyle = theme.typography.caption.copyWith(
      color: message.color == null
          ? colors.textMuted
          : Color.fromARGB(255, message.color!.r, message.color!.g, message.color!.b),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s3),
      child: Text.rich(
        TextSpan(
          children: [
            if (sender == null)
              TextSpan(text: '${context.t.room.system}: ', style: nameStyle)
            else
              TextSpan(text: '${sender.userName}: ', style: nameStyle),
            TextSpan(
              text: message.text,
              style: theme.typography.caption.copyWith(color: colors.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sleep timer's chip: off shows a moon that opens the picker; running
/// shows the countdown and the picker's first item stops it.
/// The sleep timer's chip: off shows a moon that opens the picker; running
/// shows the countdown and the picker's first item stops it.
final class _SleepChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final running = timer.minutes != null;
    final label = running ? '${timer.minutes} min' : t.room.sleep;
    return DsMenuAnchor(
      semanticLabel: t.room.sleep,
      side: DsSide.top,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.room.sleep,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            height: theme.sizes.sm,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8),
            decoration: DsBoxDecoration(
              color: running
                  ? theme.selectedFill
                  : hovered
                  ? colors.hover
                  : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s4,
              children: [
                DsIcon(
                  DsIcons.moon,
                  size: theme.sizes.iconSm,
                  color: running ? theme.onSelectedFill : colors.textMuted,
                ),
                Text(
                  label,
                  style: theme.typography.caption.copyWith(color: running ? theme.onSelectedFill : colors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
      items: [
        if (running)
          DsMenuItem(label: Text(t.room.sleepOff), onPressed: () => ref.read(sleepTimerProvider.notifier).start(null)),
        for (final minutes in const [30, 60, 90])
          DsMenuItem(
            label: Text('$minutes min'),
            onPressed: () => ref.read(sleepTimerProvider.notifier).start(minutes),
          ),
      ],
    );
  }
}
