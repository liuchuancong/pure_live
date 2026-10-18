import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;
import 'package:pure_live/features/room/room_controller.dart' show RoomController, RoomPresentation, RoomState;
import 'package:pure_live/features/room/room_providers.dart' show RoomIdentity;
import 'package:pure_live/features/room/widgets/room_barrage_overlay.dart';
import 'package:pure_live/features/room/widgets/room_control_overlay.dart';
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
final class RoomVideoSurface extends ConsumerWidget {
  /// The surface for [identity].
  const new({
    required this.identity,
    required this.controller,
    required this.state,
    this.aspectRatio,
    this.immersive = false,
    this.compact = false,
    this.barrageRows = 4,
    this.barrageFontSize,
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

  /// How many barrage rows fit this surface.
  final int barrageRows;

  /// The barrage text size; null follows the setting, a shell that needs its
  /// own (desktop, TV) pins one.
  final double? barrageFontSize;

  /// Leaves the immersive presentation.
  final VoidCallback? onExitImmersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = _tapLayer(context);
    return ColoredBox(
      color: Colors.black,
      child: aspectRatio == null ? core : AspectRatio(aspectRatio: aspectRatio!, child: core),
    );
  }

  Widget _tapLayer(BuildContext context) {
    final locked = state.locked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // One tap brings the chrome up (or takes it back down); two take the
      // window, the reference's own surface grammar. The lock silences all
      // of it — only the unlock chip answers.
      onTap: locked ? null : () => controller.revealChrome(toggle: immersive),
      onDoubleTap: locked
          ? null
          : () => controller.setPresentation(immersive ? RoomPresentation.normal : RoomPresentation.fullscreen),
      // A vertical drag on the right half is volume, on the left it is nothing
      // — brightness needs a system channel this app does not own.
      onVerticalDragUpdate: locked
          ? null
          : (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          return;
        }
        final local = box.globalToLocal(details.globalPosition);
        if (local.dx < box.size.width * 0.5) {
          return;
        }
        controller.setVolume(state.volume - details.delta.dy / box.size.height);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _picture(context),
          if (state.barrageOn && state.playing)
            RoomBarrageOverlay(identity: identity, lanes: barrageRows, fontSize: barrageFontSize),
          if (!locked)
            RoomControlOverlay(
              identity: identity,
              immersive: immersive,
              compact: compact,
              onExit: onExitImmersive ?? () => controller.setPresentation(RoomPresentation.normal),
            ),
          if (locked)
            // The one control the lock leaves on screen — the reference's
            // unlock chip, at the leading edge of the bottom bar.
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 20),
                child: IconButton(
                  key: const ValueKey('room-unlock'),
                  tooltip: context.t.room.unlock,
                  onPressed: controller.toggleLock,
                  icon: const Icon(Icons.lock, color: Colors.white),
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
    final adapter = controller.adapter;
    if (adapter != null) {
      return MediaKitVideoView(adapter: adapter);
    }
    if (state.loadingLines || state.loadingDetail) {
      return const Center(child: PureSpinner(size: 40));
    }
    if (state.engineStopped || state.streamError != null) {
      return _Failed(onRetry: () => unawaited(controller.retry()), message: context.t.room.failed);
    }
    if (state.explicitlyOffline) {
      return PureEmpty(title: context.t.room.offline, icon: Icons.tv_off_outlined, message: state.room?.content.title);
    }
    if (state.detailError != null) {
      return PureError(
        message: context.t.room.entryFailed,
        retryLabel: context.t.common.retry,
        onRetry: () => unawaited(controller.load()),
      );
    }
    return const SizedBox.shrink();
  }
}

/// The stopped stream: the message and one way back.
final class _Failed extends StatelessWidget {
  const new({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off, size: 34, color: Colors.white54),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: onRetry),
      ],
    ),
  );
}
