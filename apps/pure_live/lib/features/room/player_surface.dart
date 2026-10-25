import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/providers/presentation_providers.dart' show roomPresentationProvider;
import 'package:pure_live/features/recorder/recording_repository.dart' show recordingTasksProvider;
import 'package:pure_live/features/recorder/recording_task.dart' show RecordingTaskState;
import 'package:pure_live/features/room/cast_dialog.dart' show showCastDialog;
import 'package:pure_live/features/room/room_controller.dart';
import 'package:pure_live/features/room/room_status.dart'
    show RoomPictureAction, RoomPictureDim, RoomPictureKind, pictureStateOf, roomSlowProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart' show danmakuStyleProvider;
import 'package:pure_live/features/settings/playback_settings_providers.dart' show playbackSettingsProvider;
import 'package:pure_live/l10n/translations.dart';

/// The picture's own ink: the frame is dark whatever the app's theme, so
/// the bars, the state overlay and the position line never borrow the
/// surface's ink (which turns dark-on-dark in a light theme).
const Color _onVideo = Color(0xFFFFFFFF);
const Color _onVideoMuted = Color(0xCCFFFFFF);
const Color _onVideoSubtle = Color(0x99FFFFFF);
const Color _onVideoHover = Color(0x24FFFFFF);

/// One action the overlay offers, pressed through the room controller.
final class PictureActionButton extends ConsumerWidget {
  const PictureActionButton({required this.action, this.autofocus = false, super.key});

  final RoomPictureAction action;

  /// Takes the focus when first built (the TV room's first stop while the
  /// stream is not playable).
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.read(roomProvider.notifier);
    final room = ref.read(roomProvider).room;
    final (label, onPressed) = switch (action) {
      RoomPictureAction.back => (
        t.common.close,
        () async {
          final presentation = ref.read(roomPresentationProvider);
          final player = ref.read(roomProvider).handle?.id;
          if (presentation != PresentationMode.normal && player != null) {
            await ref.read(roomPresentationProvider.notifier).exit(player);
          } else if (context.mounted) {
            context.pop();
          }
        },
      ),
      RoomPictureAction.refresh => (
        t.common.retry,
        room == null ? null : () => unawaited(controller.open(platform: room.ref.platform, roomId: room.ref.roomId)),
      ),
      RoomPictureAction.retry => (t.common.retry, () => unawaited(controller.retry())),
      RoomPictureAction.switchLine => (
        t.room.lineLabel,
        () {
          final current = ref.read(roomProvider);
          if (current.lines.length < 2) return;
          unawaited(controller.selectLine((current.lineIndex + 1) % current.lines.length));
        },
      ),
      RoomPictureAction.playAgain => (t.room.play, () => unawaited(controller.retry())),
    };
    return DsButton(onPressed: onPressed, autofocus: autofocus, child: Text(label));
  }
}

/// The player surface the room owns: media_core's bare picture
/// (`MediaPlayerView`) with the app's own control layer over it.
///
/// The layer carries what a live room needs: play/pause, mute and volume,
/// the live position, the quality and the line (menus over the site's own
/// catalogues), the flying danmaku's switch, the DLNA cast entry, and the
/// three presentation buttons — system fullscreen, window fullscreen and
/// picture-in-picture — each routed through media_core's presentation
/// drivers. It hides while the stream plays and a tap wakes it.
final class PlayerSurface extends ConsumerStatefulWidget {
  /// Shows [roomState]'s stream with the room's own controls.
  const PlayerSurface({
    required this.roomState,
    required this.barrage,
    required this.onLeave,
    this.immersive = false,
    this.keepControls = false,
    this.autofocusFirstControl = false,
    super.key,
  });

  /// The room's state (the picture and the playback facts).
  final RoomState roomState;

  /// The room's flying danmaku engine; null until the pipeline exists.
  final BarrageController? barrage;

  /// Leaves the surface: the page pops in its inline layout, and leaves the
  /// presentation mode while one holds the window.
  final VoidCallback onLeave;

  /// Whether the surface fills the page (fullscreen, window fullscreen or
  /// PiP), where the bar starts visible and the top bar carries the way out.
  final bool immersive;

  /// Keeps the bars on screen (a TV room): a remote has no pointer to wake
  /// them, so hidden controls would strand the focus.
  final bool keepControls;

  /// Focuses the play button (or the first picture action) when the bars
  /// first build: the TV room's starting stop for the remote.
  final bool autofocusFirstControl;

  @override
  ConsumerState<PlayerSurface> createState() => _PlayerSurfaceState();
}

final class _PlayerSurfaceState extends ConsumerState<PlayerSurface> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  StreamSubscription<PlayerTransportState>? _transportSub;

  /// The volume the viewer is dragging, and the bar that shows it; null
  /// when no drag or wheel is in flight.
  double? _volumeHud;
  Timer? _volumeHudTimer;
  double _dragVolume = 0;

  /// Watches the bars' controls: while one of them holds the focus the
  /// bars stay (a remote cannot tap the picture to bring them back).
  final FocusNode _controlsFocus = FocusNode(
    debugLabel: 'player controls',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// The transport facts the bar reads (position, buffer, volume); the
  /// handle's ValueStream updates faster than the room state's rebuilds.
  PlayerTransportState? _transport;

  PlayerHandle? _boundHandle;

  @override
  void initState() {
    super.initState();
    _controlsFocus.addListener(_onControlsFocus);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _volumeHudTimer?.cancel();
    _controlsFocus
      ..removeListener(_onControlsFocus)
      ..dispose();
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  void _onControlsFocus() {
    if (_controlsFocus.hasFocus) {
      _wake();
      return;
    }
    // The remote left the bars: let them settle away as before.
    _scheduleHide();
  }

  void _watchTransport(PlayerHandle? handle) {
    if (identical(handle, _boundHandle)) return;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    _boundHandle = handle;
    _transportSub = handle?.playbackStream.listen((state) {
      if (mounted) setState(() => _transport = state);
    });
  }

  /// Shows the bar and, while the stream plays, lets it settle away again.
  void _wake() {
    if (mounted) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.roomState.playback.playing) return;
    // A TV room keeps its bars: with no pointer there is no way to wake a
    // hidden bar, and the focused control would go with it.
    if (widget.keepControls || _controlsFocus.hasFocus) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.roomState.playback.playing && !_controlsFocus.hasFocus) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    // The TV room cannot tap: its bars never hide, so a control always
    // exists for the remote to come back to.
    if (widget.keepControls) {
      _wake();
      return;
    }
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  /// Shows the volume the viewer is setting and lets the bar go after a
  /// moment on its own.
  void _showVolume(double value) {
    _volumeHudTimer?.cancel();
    setState(() => _volumeHud = value.clamp(0.0, 1.0));
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  /// A vertical drag takes the volume from where it is: up is louder, the
  /// whole picture is the track (no brightness half to confuse the pinch).
  void _beginVolumeDrag() {
    _dragVolume = ref.read(roomProvider.notifier).volume;
    _showVolume(_dragVolume);
  }

  void _dragVolumeBy(double delta) {
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showVolume(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  /// A wheel step takes a twentieth of the range, so a desktop mouse has a
  /// usable granularity without a slider.
  void _wheelVolume(double delta) {
    final next = (ref.read(roomProvider.notifier).volume + (delta > 0 ? -0.05 : 0.05)).clamp(0.0, 1.0);
    _showVolume(next);
    unawaited(ref.read(roomProvider.notifier).setVolume(next));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final room = widget.roomState;
    final handle = room.handle;
    final transport = _transport;
    final picture = pictureStateOf(context.t, room, slow: ref.watch(roomSlowProvider));
    final style = ref.watch(danmakuStyleProvider);
    final playback = ref.watch(playbackSettingsProvider);
    final presentation = ref.watch(roomPresentationProvider);
    final mini = presentation == PresentationMode.pip;
    final showDanmaku = playback.danmakuVisible && (!mini || playback.miniDanmakuVisible);
    final playing = room.playback.playing;
    // A paused or failed stream keeps the bar up; a playing one lets it go.
    final showBar = handle != null && picture.kind == RoomPictureKind.none && (_controlsVisible || !playing);
    _watchTransport(handle);
    ref.listen(roomProvider.select((state) => state.playback.playing), (previous, next) {
      if (next) {
        _scheduleHide();
      } else if (mounted) {
        _hideTimer?.cancel();
        setState(() => _controlsVisible = true);
      }
    });
    return Focus(
      focusNode: _controlsFocus,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (handle == null)
            ColoredBox(color: colors.overlay, child: const SizedBox.expand())
          else
            MediaPlayerView(handle: handle, fit: playback.fit.boxFit, backgroundColor: colors.overlay),
          if (widget.barrage case final barrage? when showDanmaku)
            Positioned.fill(
              child: IgnorePointer(
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
            ),
          // The gesture layer: a tap shows or hides the bar, a double tap
          // plays or pauses, a vertical drag and the wheel set the volume.
          // The overlay's own buttons stay above it.
          if (picture.kind == RoomPictureKind.none)
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                  _wheelVolume(event.scrollDelta.dy);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTap: () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
                onVerticalDragStart: (_) => _beginVolumeDrag(),
                onVerticalDragUpdate: (details) => _dragVolumeBy(details.delta.dy),
                child: const SizedBox.expand(),
              ),
            ),
          if (_volumeHud case final volume?)
            PositionedDirectional(
              end: DsSpace.s20,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
                    decoration: DsBoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(DsTheme.of(context).radii.card),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: DsSpace.s4,
                      children: [
                        DsIcon(
                          volume <= 0.001 ? DsIcons.volumeX : DsIcons.volume2,
                          size: 24,
                          color: _onVideo,
                        ),
                        Text(
                          '${(volume * 100).round()}%',
                          style: DsTheme.of(context).typography.numeric(
                            DsTheme.of(context).typography.caption.copyWith(color: _onVideo),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                    if (picture.busy) const DsSpinner(style: DsSpinnerStyle(color: _onVideoSubtle)),
                    Text(
                      picture.title,
                      textAlign: TextAlign.center,
                      style: DsTheme.of(context).typography.title.copyWith(color: _onVideo),
                    ),
                    if (picture.reason case final reason?)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          reason,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DsTheme.of(context).typography.caption.copyWith(color: _onVideoMuted),
                        ),
                      ),
                    if (picture.actions.isNotEmpty)
                      Wrap(
                        spacing: DsSpace.s8,
                        runSpacing: DsSpace.s8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final (index, action) in picture.actions.indexed)
                            PictureActionButton(action: action, autofocus: widget.autofocusFirstControl && index == 0),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (showBar)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: _PlayerTopBar(room: room, onLeave: widget.onLeave),
            ),
          if (showBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ControlBar(
                handle: handle,
                transport: transport,
                onWake: _wake,
                autofocusPlay: widget.autofocusFirstControl,
              ),
            ),
        ],
      ),
    );
  }
}

/// The strip over the picture: the way out (back to the page, or out of a
/// presentation mode) and the room's name in the viewer's own type.
final class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.room, required this.onLeave});

  final RoomState room;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final title = room.room?.content.title;
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          _BarIcon(icon: DsIcons.chevronLeft, label: t.common.close, onPressed: onLeave),
          if (title != null)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: _onVideo),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

/// The bar itself: the live position over the buffer, then the transport,
/// the stream pickers, the danmaku switch and the presentation buttons.
final class _ControlBar extends ConsumerWidget {
  const _ControlBar({required this.handle, required this.transport, required this.onWake, this.autofocusPlay = false});

  final PlayerHandle handle;

  /// The latest transport snapshot, null until the first event.
  final PlayerTransportState? transport;

  /// Resets the bar's auto-hide timer after an interaction.
  final VoidCallback onWake;

  /// Focuses the play button when it first builds (the TV room's start).
  final bool autofocusPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    final settings = ref.watch(playbackSettingsProvider);
    final presentation = ref.watch(roomPresentationProvider);
    final controller = ref.read(roomProvider.notifier);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final player = room.handle?.id;
    final playing = room.playback.playing;
    final muted = controller.muted;
    final volume = transport?.volume ?? controller.volume;
    final position = transport?.position ?? Duration.zero;
    final buffered = transport?.buffer.bufferedDuration ?? Duration.zero;
    final duration = transport?.duration ?? Duration.zero;
    final quality = room.quality ?? (room.qualities.isEmpty ? null : room.qualities.first);
    final line = room.lines.isEmpty ? null : room.lines[room.lineIndex.clamp(0, room.lines.length - 1)];
    final immersive = presentation != PresentationMode.normal;
    return Container(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          _LiveBar(position: position, buffered: buffered, duration: duration),
          LayoutBuilder(
            builder: (context, constraints) {
              // The compact window (and a phone's 16:9 strip) has no room
              // for labels: the pickers keep their icons, and a small
              // window only keeps the transport and the way out.
              final pip = presentation == PresentationMode.pip;
              final compact = constraints.maxWidth < 560;
              final narrow = constraints.maxWidth < 420;
              return Row(
                spacing: DsSpace.s4,
                children: [
                  _BarIcon(
                    icon: playing ? DsIcons.pause : DsIcons.play,
                    label: playing ? t.room.pause : t.room.play,
                    autofocus: autofocusPlay,
                    onPressed: () {
                      onWake();
                      unawaited(controller.togglePlayPause());
                    },
                  ),
                  _BarIcon(
                    icon: muted ? DsIcons.volumeOff : DsIcons.volume,
                    label: muted ? t.room.unmute : t.room.mute,
                    onPressed: () {
                      onWake();
                      unawaited(controller.setMuted(value: !muted));
                    },
                  ),
                  if (!compact)
                    SizedBox(
                      width: 90,
                      child: DsSlider(
                        value: volume,
                        onChanged: (value) {
                          onWake();
                          unawaited(controller.setVolume(value));
                        },
                        semanticLabel: t.room.volume,
                      ),
                    ),
                  const Spacer(),
                  if (!pip && quality != null)
                    _StreamMenu(
                      label: quality.label,
                      showLabel: !compact,
                      icon: DsIcons.gauge,
                      semanticLabel: t.room.quality,
                      items: [
                        for (final option in room.qualities)
                          DsMenuItem(
                            label: Text(option.label),
                            checked: option == quality,
                            onPressed: () {
                              onWake();
                              unawaited(controller.selectQuality(option));
                            },
                          ),
                      ],
                    ),
                  if (!pip && line != null && room.lines.length > 1)
                    _StreamMenu(
                      label: line.lineLabel ?? t.room.line(n: room.lineIndex + 1),
                      showLabel: !compact,
                      icon: DsIcons.route,
                      semanticLabel: t.room.lineLabel,
                      items: [
                        for (final (index, option) in room.lines.indexed)
                          DsMenuItem(
                            label: Text(option.lineLabel ?? t.room.line(n: index + 1)),
                            checked: index == room.lineIndex,
                            onPressed: () {
                              onWake();
                              unawaited(controller.selectLine(index));
                            },
                          ),
                      ],
                    ),
                  if (!pip && line != null) _RecordButton(room: room),
                  if (!pip)
                    _BarIcon(
                      icon: settings.danmakuVisible ? DsIcons.captions : DsIcons.captionsOff,
                      label: settings.danmakuVisible ? t.room.danmakuOff : t.room.danmakuOn,
                      selected: settings.danmakuVisible,
                      onPressed: () {
                        onWake();
                        unawaited(
                          ref
                              .read(playbackSettingsProvider.notifier)
                              .setDanmakuVisible(value: !settings.danmakuVisible),
                        );
                      },
                    ),
                  if (!pip && !narrow && line != null)
                    _BarIcon(
                      icon: DsIcons.cast,
                      label: t.room.cast,
                      onPressed: () {
                        onWake();
                        unawaited(showCastDialog(context, line: line, title: room.room?.content.title));
                      },
                    ),
                  if (!pip && !narrow && _desktop && player != null)
                    _BarIcon(
                      icon: DsIcons.rectangleHorizontal,
                      label: presentation == PresentationMode.windowFullscreen
                          ? t.room.windowFullscreenOff
                          : t.room.windowFullscreenOn,
                      selected: presentation == PresentationMode.windowFullscreen,
                      onPressed: () {
                        onWake();
                        unawaited(presentationController.toggleWindowFullscreen(player));
                      },
                    ),
                  if (!pip && player != null)
                    _BarIcon(
                      icon: immersive ? DsIcons.minimize2 : DsIcons.fullscreen,
                      label: immersive ? t.room.fullscreenOff : t.room.fullscreenOn,
                      selected: immersive,
                      onPressed: () {
                        onWake();
                        unawaited(presentationController.toggleFullscreen(player));
                      },
                    ),
                  if (player != null && presentationController.pipAvailable)
                    _BarIcon(
                      icon: presentation == PresentationMode.pip
                          ? DsIcons.pictureInPictureExit
                          : DsIcons.pictureInPicture,
                      label: presentation == PresentationMode.pip ? t.room.pipOff : t.room.pipOn,
                      selected: presentation == PresentationMode.pip,
                      onPressed: () {
                        onWake();
                        unawaited(presentationController.togglePip(player));
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Whether this host offers the desktop-only window-fullscreen button.
bool get _desktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// A labelled menu over a stream dimension: the current quality or line,
/// its catalogue, the tick on the one playing.
final class _StreamMenu extends StatelessWidget {
  const _StreamMenu({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.showLabel = true,
  });

  /// The current choice; shown when [showLabel], the tooltip otherwise.
  final String label;
  final DsIconData icon;
  final String semanticLabel;
  final List<Widget> items;

  /// Whether the bar has room for the choice's words (a narrow strip and
  /// the small window keep only the icon).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsMenuAnchor(
      side: DsSide.top,
      semanticLabel: semanticLabel,
      items: items,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: semanticLabel,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return DsTooltip(
            message: '$label · $semanticLabel',
            child: Container(
              height: theme.sizes.sm,
              padding: EdgeInsets.symmetric(horizontal: showLabel ? DsSpace.s8 : DsSpace.s6),
              decoration: DsBoxDecoration(
                color: hovered ? _onVideoHover : null,
                borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: theme.sizes.iconSm, color: _onVideoMuted),
                  if (showLabel) Text(label, style: theme.typography.caption.copyWith(color: _onVideo)),
                  const DsIcon(DsIcons.chevronUp, size: 12, color: _onVideoMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The record toggle: a disc while idle, a stop square while this room is
/// being captured. The task store is the truth the button follows, so a
/// recording started in an earlier visit still reads as running.
final class _RecordButton extends ConsumerWidget {
  const _RecordButton({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final detail = room.room;
    final id = detail == null ? null : '${detail.ref.platform}:${detail.ref.roomId}';
    final task = id == null ? null : ref.watch(recordingTasksProvider).tasks.where((task) => task.id == id).firstOrNull;
    final recording = task?.state == RecordingTaskState.recording;
    return _BarIcon(
      icon: recording ? DsIcons.squareStop : DsIcons.disc,
      label: recording ? t.room.stopRecording : t.room.record,
      selected: recording,
      onPressed: () async {
        final failure = await ref.read(roomProvider.notifier).toggleRecording();
        if (!context.mounted) return;
        showDsToast(
          context: context,
          title: failure == null ? (recording ? t.room.recordStopped : t.room.recordStarted) : t.room.recordFailed,
          status: failure == null ? DsStatus.success : DsStatus.danger,
        );
      },
    );
  }
}

/// One icon button on the dark bar: a slight hover fill, the selected
/// state's tint, and the label a screen reader reads.
final class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.autofocus = false,
  });

  final DsIconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  /// Takes the focus when first built (the TV room's first control).
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: onPressed,
        autofocus: autofocus,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: theme.sizes.sm,
            height: theme.sizes.sm,
            decoration: DsBoxDecoration(
              color: hovered ? _onVideoHover : null,
              borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
            ),
            child: Center(
              child: DsIcon(icon, size: theme.sizes.iconSm, color: selected ? _onVideo : _onVideoMuted),
            ),
          );
        },
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
    final total = duration.inMilliseconds;
    if (total <= 0) {
      return const DsLine(color: _onVideoSubtle);
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
              const ColoredBox(color: Color(0x33FFFFFF), child: SizedBox.expand()),
              FractionallySizedBox(
                widthFactor: bufferedFraction,
                child: const ColoredBox(color: _onVideoSubtle, child: SizedBox.expand()),
              ),
              FractionallySizedBox(
                widthFactor: positionFraction,
                child: const ColoredBox(color: _onVideo, child: SizedBox.expand()),
              ),
              PositionedDirectional(
                start: width * positionFraction - 4,
                top: -2.5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: DsBoxDecoration(color: _onVideo, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
