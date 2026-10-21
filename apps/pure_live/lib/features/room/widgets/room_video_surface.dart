import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;
import 'package:pure_live/features/room/local/local_gift_overlay.dart';
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/widgets/room_barrage_overlay.dart';
import 'package:pure_live/features/room/widgets/room_control_overlay.dart';
import 'package:pure_live/features/room/widgets/room_gesture_layer.dart';
import 'package:pure_live/features/room/widgets/room_on_video_controls.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The video and everything drawn on it: the surface or the state that stands
/// in for it, the barrage, the tap layer and the control bars.
///
/// The frame is the caller's business — a phone column letterboxes it at the
/// source's ratio, an immersed presentation lets it fill — so [aspectRatio] is
/// null here and the layouts own the box.
///
/// What is not the caller's business is the chrome: it always overlays the
/// picture. A control strip under a video costs a phone both a line of danmaku
/// and the height to show it in.
final class RoomVideoSurface extends ConsumerStatefulWidget {
  /// The surface for [identity].
  const new({
    required this.identity,
    required this.controller,
    required this.state,
    this.aspectRatio,
    this.immersive = false,
    this.compact = false,
    this.twoRows = false,
    this.onPortraitRestore,
    this.barrageRows = 4,
    this.barrageFontSize,
    this.barrageArea,
    this.barrageHidden = false,
    this.onExitImmersive,
    super.key,
  });

  /// The room playing.
  final RoomIdentity identity;

  /// The page logic the tap layer and the bars drive.
  final RoomController controller;

  /// The snapshot they read.
  final RoomState state;

  /// The box the picture keeps; null fills whatever it is given.
  final double? aspectRatio;

  /// Whether the video owns the window (the bars then carry the title too).
  final bool immersive;

  /// Narrow bars: fewer buttons.
  final bool compact;

  /// The portrait-fullscreen bars: the top chrome takes its second row
  /// (clock, battery, picture mode) beside the first.
  final bool twoRows;

  /// The portrait fullscreen's 上滑恢复弹幕栏 (A07.2): a deliberate upward
  /// fling on the leading half of the picture brings the sheet back. The
  /// trailing half stays the reference's volume drag.
  final VoidCallback? onPortraitRestore;

  /// How many barrage rows fit this surface.
  final int barrageRows;

  /// The barrage text size; null follows the setting, a shell that needs its
  /// own (desktop, TV) pins one.
  final double? barrageFontSize;

  /// A band rule for the flying barrage (the portrait page's 竖屏弹幕布局);
  /// null follows the stored display area.
  final double? barrageArea;

  /// Takes the flying barrage off this surface (竖屏弹幕布局 隐藏) without
  /// touching the room's own switch or the stored style numbers.
  final bool barrageHidden;

  /// Leaves the immersive presentation.
  final VoidCallback? onExitImmersive;

  @override
  ConsumerState<RoomVideoSurface> createState() => _RoomVideoSurfaceState();
}

final class _RoomVideoSurfaceState extends ConsumerState<RoomVideoSurface> {
  @override
  Widget build(BuildContext context) {
    final core = _tapLayer(context);
    return ColoredBox(
      color: Colors.black,
      child: widget.aspectRatio == null ? core : AspectRatio(aspectRatio: widget.aspectRatio!, child: core),
    );
  }

  Widget _tapLayer(BuildContext context) {
    final locked = widget.state.locked;
    // The picture's gesture grammar lives in its own layer: tap, double tap,
    // the volume and brightness halves and the wheel — the lock silences all
    // of it, and only the unlock chip answers.
    return RoomGestureLayer(
      controller: widget.controller,
      state: widget.state,
      immersive: widget.immersive,
      onPortraitRestore: widget.onPortraitRestore,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _picture(context),
          if (widget.state.barrageOn && widget.state.playing && !widget.barrageHidden)
            RoomBarrageOverlay(
              identity: widget.identity,
              laneCap: widget.barrageRows,
              fontSize: widget.barrageFontSize,
              areaOverride: widget.barrageArea,
            ),
          // A gift the viewer sends crosses the picture on its own layer,
          // apart from the barrage and the controls.
          LocalGiftOverlay(identity: widget.identity),
          if (!locked)
            RoomControlOverlay(
              identity: widget.identity,
              immersive: widget.immersive,
              compact: widget.compact,
              twoRows: widget.twoRows,
              onExit: widget.onExitImmersive ?? () => widget.controller.setPresentation(RoomPresentation.normal),
            ),
          if (locked)
            // The one control the lock leaves on screen — the reference's
            // unlock chip, at the leading edge of the bottom bar.
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 20),
                child: RoomOnVideoButton(
                  key: const ValueKey('room-unlock'),
                  tooltip: context.t.room.unlock,
                  onPressed: widget.controller.toggleLock,
                  icon: Icons.lock,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The live surface, or the state that stands in for it: a room that never
  /// resolved, a stream that failed, a platform that says the anchor is off.
  Widget _picture(BuildContext context) {
    final adapter = widget.controller.adapter;
    if (adapter != null) {
      return MediaKitVideoView(adapter: adapter);
    }
    if (widget.state.loadingLines || widget.state.loadingDetail) {
      return const Center(child: PureSpinner(size: 40));
    }
    if (widget.state.engineStopped || widget.state.streamError != null) {
      return _Failed(
        onRetry: () => unawaited(widget.controller.retry()),
        message: context.t.room.failed,
        // The auto-reconnect ladder speaks for a stream it is bringing
        // back; the button waits until the ladder is spent.
        reconnecting: widget.state.reconnecting,
        attempt: widget.state.reconnectAttempt,
      );
    }
    if (widget.state.explicitlyOffline) {
      return PureEmpty(
        title: context.t.room.offline,
        icon: Icons.tv_off_outlined,
        message: widget.state.room?.content.title,
      );
    }
    if (widget.state.detailError != null) {
      return PureError(
        message: context.t.room.entryFailed,
        retryLabel: context.t.common.retry,
        onRetry: () => unawaited(widget.controller.load()),
      );
    }
    return const SizedBox.shrink();
  }
}

/// The stopped stream: the message and one way back.
final class _Failed extends StatelessWidget {
  const new({required this.message, required this.onRetry, this.reconnecting = false, this.attempt = 0});

  final String message;
  final VoidCallback onRetry;

  /// Whether the auto-reconnect ladder is running.
  final bool reconnecting;

  /// The ladder's attempt, 1-based.
  final int attempt;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off, size: 34, color: Colors.white54),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        if (reconnecting) const PureSpinner(size: 22) else const SizedBox.shrink(),
        if (reconnecting) const SizedBox(height: 8),
        if (reconnecting)
          Text(
            context.t.room.autoReconnecting(count: attempt),
            key: const ValueKey('room-reconnecting'),
            style: const TextStyle(color: Colors.white70),
          )
        else
          PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: onRetry),
      ],
    ),
  );
}
