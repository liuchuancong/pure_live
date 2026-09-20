import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class VideoKeyboardShortcuts extends StatelessWidget {
  final VideoController? controller;
  final Widget child;

  const VideoKeyboardShortcuts({super.key, required this.controller, required this.child});

  void _handleEscape(BuildContext context) {
    // A popup/opaque route owns its focus and its first Escape. HardwareKeyboard
    // global handlers also run when Flutter has already handled the same key,
    // which used to change the room presentation behind an open menu.
    if (ModalRoute.of(context)?.isCurrent == false) return;

    switch (resolveEscapePresentationAction(
      pip: GlobalPlayerState.to.isPipMode.value,
      // A room which failed before creating its VideoController can still
      // inherit a stale global presentation flag.  It has no controller with
      // which to exit that presentation, so Escape must retain its route-pop
      // contract instead of becoming a dead key.
      fullscreen: controller != null && GlobalPlayerState.to.isFullscreen.value,
      widescreen: controller != null && GlobalPlayerState.to.isWindowFullscreen.value,
    )) {
      case EscapePresentationAction.exitFullscreen:
        controller!.toggleFullScreen();
        return;
      case EscapePresentationAction.exitWidescreen:
        controller!.toggleWindowFullScreen();
        return;
      case EscapePresentationAction.popRoute:
        // Desktop Flutter does not translate an unhandled Escape key into a
        // Navigator pop. Returning false here left a normal live room open,
        // even though the same key correctly exited fullscreen. Route the
        // normal-room action explicitly while preserving the page's existing
        // PopScope/lifecycle cleanup.
        unawaited(Navigator.of(context).maybePop());
        return;
      case EscapePresentationAction.none:
        // PiP owns its own close path and must not be mutated by the parent
        // room shortcut.
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () => _handleEscape(context),
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () => GlobalPlayerService.instance.player.resume(),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () => GlobalPlayerService.instance.player.pause(),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            GlobalPlayerService.instance.player.togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.space): () => GlobalPlayerService.instance.player.togglePlayPause(),
        if (controller != null) const SingleActivator(LogicalKeyboardKey.keyR): () => controller.refresh(),
        if (controller != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): () async {
            double? volume = await controller.volume();
            if (volume == null) return;
            volume = volume + 0.05;
            volume = volume.clamp(0.0, 1.0);
            await controller.setVolume(volume);
            controller.updateVolumn(volume);
          },
        if (controller != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): () async {
            double? volume = await controller.volume();
            if (volume == null) return;
            volume = volume - 0.05;
            volume = volume.clamp(0.0, 1.0);
            await controller.setVolume(volume);
            controller.updateVolumn(volume);
          },
      },
      // Rooms with no initialized player still need a focus target. Descendant
      // controls/text inputs retain their own focus and key handling priority.
      child: FocusScope(autofocus: true, child: child),
    );
  }
}

@visibleForTesting
enum EscapePresentationAction { none, exitFullscreen, exitWidescreen, popRoute }

@visibleForTesting
EscapePresentationAction resolveEscapePresentationAction({
  required bool pip,
  required bool fullscreen,
  required bool widescreen,
}) {
  if (pip) return EscapePresentationAction.none;
  if (fullscreen) return EscapePresentationAction.exitFullscreen;
  if (widescreen) return EscapePresentationAction.exitWidescreen;
  return EscapePresentationAction.popRoute;
}
