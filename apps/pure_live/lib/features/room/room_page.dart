import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core_ui/media_core_ui.dart';
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// The live room: media_core's player surface above, the room's facts and
/// controls under it, the chat beside them on a wide window.
///
/// The player brings its own control bar (media_core_ui's built-in one);
/// the room's own row picks the quality and the line, retries on failure,
/// and follows the streamer. Chat is the danmaku session's messages, a
/// scrolling list; the flying-danmaku overlay is the next floor.
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
  @override
  void initState() {
    super.initState();
    // The room never opens from inside its own build; the page asks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(roomProvider.notifier).open(platform: widget.platform, roomId: widget.roomId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: _PlayerSurface(room: room)),
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

/// The player: media_core's view over the live handle, an honest stand-in
/// while the room has none (loading, or a room that cannot play).
final class _PlayerSurface extends ConsumerWidget {
  const _PlayerSurface({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final handle = room.handle;
    if (handle == null) {
      final message = room.error ?? context.t.room.opening;
      return ColoredBox(
        color: colors.overlay,
        child: Center(
          child: DsEmptyState(
            icon: DsIcon(DsIcons.tv, size: DsTheme.of(context).sizes.iconLg),
            title: Text(message, style: DsTheme.of(context).typography.caption.copyWith(color: colors.text)),
            actions: room.error == null ? const [] : [_RetryButton()],
          ),
        ),
      );
    }
    return MediaCorePlayerView(handle: handle);
  }
}

/// The retry the error state offers.
final class _RetryButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DsButton(
      onPressed: () => unawaited(ref.read(roomProvider.notifier).retry()),
      child: Text(context.t.common.retry),
    );
  }
}

/// The room's facts: the title, the streamer, the audience figure and the
/// follow button.
final class _RoomFacts extends ConsumerWidget {
  const _RoomFacts({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final detail = room.room;
    if (detail == null) {
      return DsSkeleton(width: DsSpace.s32, height: theme.sizes.iconMd);
    }
    final figure =
        detail.audience.primaryMetric == LiveAudienceMetricType.onlineViewers
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
          child: Text(followed ? t.room.unfollow : t.room.follow),
        ),
      ],
    );
  }
}

/// The follows the room page reads (the follow button's watched list).
final followsRoomProvider = Provider<List<LiveRoom>>((ref) {
  ref.watch(followsProvider);
  return ref.read(followsProvider).rooms;
});

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
            options: [
              for (final quality in room.qualities) DsSelectOption(value: quality, label: quality.label),
            ],
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
                DsSelectOption(value: index, label: line.lineLabel ?? t.room.line(n: index + 1)),
            ],
            placeholder: t.room.lineLabel,
            leading: DsIcon(DsIcons.route, size: DsTheme.of(context).sizes.iconSm),
            semanticLabel: t.room.lineLabel,
          ),
        const Spacer(),
        DsButton(
          onPressed: () => unawaited(controller.togglePlayPause()),
          leading: DsIcon(
            room.playback.playing ? DsIcons.pause : DsIcons.play,
            size: DsTheme.of(context).sizes.iconSm,
          ),
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
      return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.messageCircle), title: Text(t.room.noChat)));
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
      color: message.color == null ? colors.textMuted : Color.fromARGB(255, message.color!.r, message.color!.g, message.color!.b),
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
            TextSpan(text: message.text, style: theme.typography.caption.copyWith(color: colors.text)),
          ],
        ),
      ),
    );
  }
}
