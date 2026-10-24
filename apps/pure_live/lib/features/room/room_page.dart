import 'dart:async' show Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/providers/fullscreen_providers.dart' show fullscreenStateProvider;
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

  /// F enters or leaves fullscreen, Escape leaves (the keys the reference
  /// binds and every video player expects).
  late final Map<SingleActivator, VoidCallback> _keys = {
    const SingleActivator(LogicalKeyboardKey.keyF): () => unawaited(ref.read(fullscreenStateProvider.notifier).toggle()),
    const SingleActivator(LogicalKeyboardKey.escape): () => unawaited(ref.read(fullscreenStateProvider.notifier).exit()),
    // Space plays and pauses — every player's reflex. A focused text field
    // consumes the key first, so the composer never flips the playback.
    const SingleActivator(LogicalKeyboardKey.space): () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
  };

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
    final fullscreen = ref.watch(fullscreenStateProvider);
    final colors = DsTheme.colorsOf(context);
    _watchSlow(room);
    // In fullscreen the picture takes the whole page: the facts, the
    // controls and the chat wait behind the surface until it leaves.
    final body = Column(
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
        const Expanded(child: _ChatFeed()),
        const _ChatComposer(),
      ],
    );
    final page = CallbackShortcuts(
      bindings: _keys,
      child: fullscreen
          ? Stack(
              children: [
                Positioned.fill(
                  child: PlayerSurface(roomState: room, barrage: ref.read(roomProvider.notifier).barrage),
                ),
                // A way back without the keyboard: a quiet leave button in
                // the corner.
                const PositionedDirectional(
                  top: DsSpace.s12,
                  end: DsSpace.s12,
                  child: _FullscreenButton(expanded: true),
                ),
              ],
            )
          : body,
    );
    // On a phone the room is a pushed page with no shell chrome of its
    // own: the app bar carries the way back and the room's name.
    final compact = MediaQuery.sizeOf(context).width < 768;
    if (!compact) return page;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        title: Text(
          room.room?.content.title ?? context.t.common.appTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: page,
    );
  }
}

/// The fullscreen toggle: the icon button in the controls row, and the
/// quiet corner button while fullscreen holds the page.
final class _FullscreenButton extends ConsumerWidget {
  const _FullscreenButton({required this.expanded});

  /// Whether the button sits on the fullscreen surface (true) or in the
  /// controls row (false); only the styling differs.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final active = ref.watch(fullscreenStateProvider);
    final leave = expanded || active;
    return DsTooltip(
      message: leave ? t.room.fullscreenOff : t.room.fullscreenOn,
      child: DsPressable(
        semanticLabel: leave ? t.room.fullscreenOff : t.room.fullscreenOn,
        onPressed: () {
          final controller = ref.read(fullscreenStateProvider.notifier);
          unawaited(active ? controller.exit() : controller.toggle());
        },
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: 30,
            height: 30,
            decoration: DsBoxDecoration(
              color: expanded ? colors.overlay.withValues(alpha: hovered ? 0.7 : 0.45) : hovered ? colors.hover : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: DsIcon(
                active ? DsIcons.minimize : DsIcons.maximize2,
                size: 16,
                color: expanded ? colors.text : colors.textMuted,
              ),
            ),
          );
        },
      ),
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
        const _FullscreenButton(expanded: false),
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
  const _ChatFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final chat = ref.watch(roomChatProvider);
    if (chat.isEmpty) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.messageCircle), title: Text(t.room.noChat)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
      itemCount: chat.length,
      itemBuilder: (context, index) => _ChatLine(message: chat[index]),
    );
  }
}

/// The chat composer: the field and the send button, only when the room's
/// chat accepts a posted message; a failure toasts, a success clears the
/// field.
final class _ChatComposer extends ConsumerStatefulWidget {
  const _ChatComposer();

  @override
  ConsumerState<_ChatComposer> createState() => _ChatComposerState();
}

final class _ChatComposerState extends ConsumerState<_ChatComposer> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canSend = ref.watch(roomProvider.notifier).canSendDanmaku;
    if (!canSend) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: DsTextField(
              controller: _field,
              clearable: true,
              placeholder: t.room.sendHint,
              onSubmitted: (word) => unawaited(_send(word)),
            ),
          ),
          DsButton(
            onPressed: () => unawaited(_send(_field.text)),
            child: Text(t.room.send),
          ),
        ],
      ),
    );
  }

  Future<void> _send(String word) async {
    if (word.trim().isEmpty) return;
    final failure = await ref.read(roomProvider.notifier).sendDanmaku(word);
    if (!mounted) return;
    if (failure == null) {
      _field.clear();
    } else {
      showDsToast(context: context, title: context.t.room.sendFailed);
    }
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
