import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core/media_core.dart';
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, roomPictureProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/l10n/translations.dart';

/// One action the overlay offers, pressed through the room controller.
final class PictureActionButton extends ConsumerWidget {
  const PictureActionButton({required this.action, super.key});

  final RoomPictureAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.read(roomProvider.notifier);
    final room = ref.read(roomProvider).room;
    final (label, onPressed) = switch (action) {
      RoomPictureAction.back => (t.common.close, () async => context.pop()),
      RoomPictureAction.refresh => (
        t.common.retry,
        room == null ? null : () => unawaited(controller.open(platform: room.ref.platform, roomId: room.ref.roomId)),
      ),
      RoomPictureAction.retry => (t.common.retry, () => unawaited(controller.retry())),
      RoomPictureAction.switchLine => (t.room.lineLabel, () => unawaited(controller.selectLine(1))),
      RoomPictureAction.playAgain => (t.room.play, () => unawaited(controller.retry())),
    };
    return DsButton(onPressed: onPressed, child: Text(label));
  }
}

/// The player surface the room owns: media_core's bare picture (the
/// `MediaPlayerView` of the core package — no controls of its own) with a
/// control layer drawn in the app's own design language beneath it.
///
/// The layer hides while the stream plays and a tap wakes it (the
/// auto-hide timer resets on every wake); it carries play/pause, volume,
/// the live position against the buffered span, and the fullscreen toggle
/// later. Muted is a per-room setting the room remembers.
final class PlayerSurface extends ConsumerStatefulWidget {
  /// Shows [roomState]'s stream with the room's own controls.
  const PlayerSurface({required this.roomState, required this.barrage, super.key});

  /// The room's state (the picture and the playback facts).
  final RoomState roomState;

  /// The room's flying danmaku engine; null until the danmaku pipeline
  /// exists (the flame layer waits for it).
  final BarrageController? barrage;

  @override
  ConsumerState<PlayerSurface> createState() => _PlayerSurfaceState();
}

final class _PlayerSurfaceState extends ConsumerState<PlayerSurface> {
  bool _controlsVisible = false;
  Timer? _hideTimer;
  StreamSubscription<PlayerTransportState>? _transportSub;

  /// The transport facts the bar reads (position, buffer, volume); the
  /// handle's ValueStream updates faster than the room state's rebuilds.
  PlayerTransportState? _transport;

  PlayerHandle? _boundHandle;

  @override
  void dispose() {
    _hideTimer?.cancel();
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  void _watchTransport(PlayerHandle? handle) {
    if (identical(handle, _boundHandle)) return;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    _boundHandle = handle;
    _transportSub = handle?.playbackStream.listen((state) {
      if (mounted) setState(() => _transport = state);
    });
  }

  void _wake() {
    setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final room = widget.roomState;
    final handle = room.handle;
    _watchTransport(handle);
    final picture = ref.watch(roomPictureProvider);
    final style = ref.watch(danmakuStyleProvider);
    final transport = _transport;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (handle == null)
          ColoredBox(color: colors.overlay, child: const SizedBox.expand())
        else
          MediaPlayerView(handle: handle),
        if (widget.barrage case final barrage?)
          Positioned.fill(
            child: FlameBarrageWidget(
              // The settings surface's danmaku style, applied live: every
              // slider there rebuilds this config on its next frame.
              config: BarrageConfig(
                fontSize: style.fontSize,
                baseSpeed: style.baseSpeed,
                area: style.area,
                opacity: style.opacity,
                showStroke: style.showStroke,
              ),
              emojiAtlas: EmojiAtlas.instance,
              controller: barrage,
            ),
          ),
        // The tap layer: a playing room wakes the bar, an overlaid one
        // lets the overlay's own buttons through.
        if (picture.kind == RoomPictureKind.none)
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: _wake, child: const SizedBox.expand()),
        if (picture.kind != RoomPictureKind.none)
          ColoredBox(
            color: switch (picture.dim) {
              RoomPictureDim.none => const Color(0x00000000),
              RoomPictureDim.light => const Color(0x66000000),
              RoomPictureDim.heavy => const Color(0xB3000000),
              RoomPictureDim.cover => const Color(0xE6000000),
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s12,
                children: [
                  if (picture.busy) const DsSpinner(),
                  Text(
                    picture.title,
                    textAlign: TextAlign.center,
                    style: theme.typography.title.copyWith(color: colors.text),
                  ),
                  if (picture.reason != null)
                    Text(
                      picture.reason!,
                      textAlign: TextAlign.center,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  if (picture.actions.isNotEmpty)
                    Wrap(
                      spacing: DsSpace.s8,
                      runSpacing: DsSpace.s8,
                      alignment: WrapAlignment.center,
                      children: [for (final action in picture.actions) PictureActionButton(action: action)],
                    ),
                  if (picture.actions.isNotEmpty)
                    Wrap(
                      spacing: DsSpace.s8,
                      runSpacing: DsSpace.s8,
                      alignment: WrapAlignment.center,
                      children: [for (final action in picture.actions) PictureActionButton(action: action)],
                    ),
                ],
              ),
            ),
          ),
        // The bar: only over a playing (or paused) stream, only when woken.
        if (handle != null &&
            picture.kind == RoomPictureKind.none &&
            (picture.kind == RoomPictureKind.paused || _controlsVisible || room.room?.broadcast.isLiveNow == true))
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ControlBar(handle: handle, transport: transport),
          ),
      ],
    );
  }
}

/// The bar itself: play/pause, volume, the live position over the buffer.
/// The live stream's duration is nominal — the bar reads both anyway, so
/// a replay or a carousel behaves the same as a live stream.
final class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.handle, required this.transport});

  final PlayerHandle handle;

  /// The latest transport snapshot, null until the first event.
  final PlayerTransportState? transport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final playing = ref.watch(roomProvider.select((state) => state.playback.playing));
    final muted = handle.muted;
    final volume = transport?.volume ?? handle.volume;
    final position = transport?.position ?? Duration.zero;
    final buffered = transport?.buffer.bufferedDuration ?? Duration.zero;
    final duration = transport?.duration ?? Duration.zero;
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      decoration: const DsBoxDecoration(color: Color(0xCC000000)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          _LiveBar(position: position, buffered: buffered, duration: duration),
          Row(
            spacing: DsSpace.s8,
            children: [
              DsPressable(
                semanticLabel: playing ? t.room.pause : t.room.play,
                onPressed: () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
                builder: (context, states, _) {
                  final hovered = states.contains(WidgetState.hovered);
                  return DsIcon(
                    playing ? DsIcons.pause : DsIcons.play,
                    size: theme.sizes.iconMd,
                    color: hovered ? colors.text : colors.textMuted,
                  );
                },
              ),
              DsPressable(
                semanticLabel: muted ? t.room.unmute : t.room.mute,
                onPressed: () => unawaited(handle.setMute(muted: !muted)),
                builder: (context, states, _) {
                  final hovered = states.contains(WidgetState.hovered);
                  return DsIcon(
                    muted ? DsIcons.volumeOff : DsIcons.volume,
                    size: theme.sizes.iconSm,
                    color: hovered ? colors.text : colors.textMuted,
                  );
                },
              ),
              Expanded(
                child: DsSlider(
                  value: volume,
                  onChanged: (value) => unawaited(handle.setVolume(value)),
                  semanticLabel: t.room.volume,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The live position bar: the buffered span behind, the position over it.
/// A nominal or unknown duration keeps the bar at its start, which is the
/// truth of a live stream.
final class _LiveBar extends StatelessWidget {
  const _LiveBar({required this.position, required this.buffered, required this.duration});

  final Duration position;
  final Duration buffered;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final total = duration.inMilliseconds;
    if (total <= 0) {
      return DsLine(color: colors.textSubtle);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bufferedFraction = (buffered.inMilliseconds / total).clamp(0.0, 1.0);
        final positionFraction = (position.inMilliseconds / total).clamp(0.0, 1.0);
        return SizedBox(
          height: 3,
          child: Stack(
            children: [
              ColoredBox(color: colors.textSubtle.withValues(alpha: 0.3), child: const SizedBox.expand()),
              FractionallySizedBox(
                widthFactor: bufferedFraction,
                child: ColoredBox(color: colors.textSubtle, child: const SizedBox.expand()),
              ),
              FractionallySizedBox(
                widthFactor: positionFraction,
                child: ColoredBox(color: colors.accent, child: const SizedBox.expand()),
              ),
              PositionedDirectional(
                start: width * positionFraction - 4,
                top: -2.5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: DsBoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
