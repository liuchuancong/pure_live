import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class VideoKeyboardShortcuts extends StatefulWidget {
  final VideoController? controller;
  final Widget child;

  const VideoKeyboardShortcuts({super.key, required this.controller, required this.child});

  @override
  State<VideoKeyboardShortcuts> createState() => _VideoKeyboardShortcutsState();
}

class _VideoKeyboardShortcutsState extends State<VideoKeyboardShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;

    switch (resolveEscapePresentationAction(
      pip: GlobalPlayerState.to.isPipMode.value,
      // A room which failed before creating its VideoController can still
      // inherit a stale global presentation flag.  It has no controller with
      // which to exit that presentation, so Escape must retain its route-pop
      // contract instead of becoming a dead key.
      fullscreen: widget.controller != null && GlobalPlayerState.to.isFullscreen.value,
      widescreen: widget.controller != null && GlobalPlayerState.to.isWindowFullscreen.value,
    )) {
      case EscapePresentationAction.exitFullscreen:
        widget.controller!.toggleFullScreen();
        return true;
      case EscapePresentationAction.exitWidescreen:
        widget.controller!.toggleWindowFullScreen();
        return true;
      case EscapePresentationAction.popRoute:
        // Desktop Flutter does not translate an unhandled Escape key into a
        // Navigator pop. Returning false here left a normal live room open,
        // even though the same key correctly exited fullscreen. Route the
        // normal-room action explicitly while preserving the page's existing
        // PopScope/lifecycle cleanup.
        unawaited(Navigator.of(context).maybePop());
        return true;
      case EscapePresentationAction.none:
        // PiP owns its own close path and must not be mutated by the parent
        // room shortcut.
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () =>
            GlobalPlayerService.instance.player.resume(),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
            GlobalPlayerService.instance.player.pause(),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            GlobalPlayerService.instance.player.togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            GlobalPlayerService.instance.player.togglePlayPause(),
        if (controller != null)
          const SingleActivator(LogicalKeyboardKey.keyR): controller.refresh,
        if (controller != null)
          const SingleActivator(LogicalKeyboardKey.arrowUp): () async {
            double? volume = await controller.volume();
            volume = (volume ?? 1.0) + 0.05;
            volume = volume.clamp(0.0, 1.0);
            controller.setVolume(volume);
            controller.updateVolumn(volume);
          },
        if (controller != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): () async {
            double? volume = await controller.volume();
            volume = (volume ?? 1.0) - 0.05;
            volume = volume.clamp(0.0, 1.0);
            controller.setVolume(volume);
            controller.updateVolumn(volume);
          },
      },
      child: widget.child,
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
