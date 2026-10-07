import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';

class VideoKeyboardShortcuts extends StatefulWidget {
  final VideoController? controller;
  final Widget child;

  const VideoKeyboardShortcuts({super.key, required this.controller, required this.child});

  @override
  State<VideoKeyboardShortcuts> createState() => _VideoKeyboardShortcutsState();
}

class _VideoKeyboardShortcutsState extends State<VideoKeyboardShortcuts> {
  /// The room's own focus scope, held for the life of the page.
  ///
  /// Entering or leaving a presentation (fullscreen, widescreen, PiP) rebuilds
  /// the content below, and on desktop the window's fullscreen transition can
  /// drop the OS-level focus with it. An `autofocus: true` that already fired
  /// does not come back on its own, which is what made Space/Escape stop
  /// answering exactly in fullscreen. Re-asserting after every presentation
  /// change fixes that without stealing the keyboard from anything that
  /// currently holds it.
  final FocusScopeNode _node = FocusScopeNode(debugLabel: 'VideoKeyboardShortcuts');

  final List<StreamSubscription<bool>> _presentationSubs = <StreamSubscription<bool>>[];

  @override
  void initState() {
    super.initState();
    final player = GlobalPlayerService.instance.player;
    for (final flag in <RxBool>[player.isInPip, player.isSystemFullscreen, player.isWindowFullscreen]) {
      _presentationSubs.add(flag.listen((_) => _reassertFocus()));
    }
    _reassertFocus();
  }

  @override
  void dispose() {
    for (final subscription in _presentationSubs) {
      subscription.cancel();
    }
    _node.dispose();
    super.dispose();
  }

  void _reassertFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _node.hasFocus) return;
      if (FocusManager.instance.primaryFocus != null) return;
      _node.requestFocus();
    });
  }

  void _handleEscape(BuildContext context) {
    final controller = widget.controller;
    // A popup/opaque route owns its focus and its first Escape. HardwareKeyboard
    // global handlers also run when Flutter has already handled the same key,
    // which used to change the room presentation behind an open menu.
    if (ModalRoute.of(context)?.isCurrent == false) return;

    switch (resolveEscapePresentationAction(
      pip: GlobalPlayerService.instance.player.isInPip.value,
      // A room which failed before creating its VideoController can still
      // inherit a stale global presentation flag.  It has no controller with
      // which to exit that presentation, so Escape must retain its route-pop
      // contract instead of becoming a dead key.
      fullscreen: controller != null && GlobalPlayerService.instance.player.isSystemFullscreen.value,
      widescreen: controller != null && GlobalPlayerService.instance.player.isWindowFullscreen.value,
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

  /// The keys whose meaning is decided by [resolveVideoKeyAction]. Escape and
  /// the dedicated media-play/media-pause keys are bound separately below:
  /// Escape leaves a presentation (see [resolveEscapePresentationAction]) and
  /// those two are not toggles.
  static const List<SingleActivator> _playbackActivators = <SingleActivator>[
    SingleActivator(LogicalKeyboardKey.space),
    SingleActivator(LogicalKeyboardKey.keyK),
    SingleActivator(LogicalKeyboardKey.keyM),
    SingleActivator(LogicalKeyboardKey.keyR),
    SingleActivator(LogicalKeyboardKey.keyF),
    SingleActivator(LogicalKeyboardKey.arrowUp),
    SingleActivator(LogicalKeyboardKey.arrowDown),
  ];

  static const double _volumeStep = 0.05;

  void _run(VideoKeyAction action) {
    final controller = widget.controller;
    switch (action) {
      case VideoKeyAction.none:
        break;
      case VideoKeyAction.togglePlay:
        unawaited(GlobalPlayerService.instance.player.togglePlayPause());
      case VideoKeyAction.toggleMute:
        if (controller != null) _toggleMute(controller);
      case VideoKeyAction.refresh:
        if (controller != null) unawaited(controller.refresh());
      case VideoKeyAction.toggleFullscreen:
        if (controller != null) unawaited(controller.toggleFullScreen());
      case VideoKeyAction.volumeUp:
        if (controller != null) _adjustVolume(controller, _volumeStep);
      case VideoKeyAction.volumeDown:
        if (controller != null) _adjustVolume(controller, -_volumeStep);
    }
  }

  void _adjustVolume(VideoController controller, double step) {
    unawaited(() async {
      final volume = await controller.volume();
      if (volume == null) return;
      final next = (volume + step).clamp(0.0, 1.0);
      await controller.setVolume(next);
      controller.updateVolumn(next);
    }());
  }

  /// The level M puts back. Mute is a toggle, not "set zero": a room muted
  /// at 40% comes back at 40%, not at full volume.
  double? _lastAudibleVolume;

  void _toggleMute(VideoController controller) {
    unawaited(() async {
      final volume = await controller.volume();
      if (volume == null) return;
      if (volume > 0.001) {
        _lastAudibleVolume = volume;
        await controller.setVolume(0);
        controller.updateVolumn(0);
        return;
      }
      final back = _lastAudibleVolume ?? 1.0;
      await controller.setVolume(back);
      controller.updateVolumn(back);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () => _handleEscape(context),
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () =>
            unawaited(GlobalPlayerService.instance.player.resume()),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () =>
            unawaited(GlobalPlayerService.instance.player.pause()),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () => _run(VideoKeyAction.togglePlay),
        for (final activator in _playbackActivators)
          activator: () => _run(resolveVideoKeyAction(activator.trigger, hasController: controller != null)),
      },
      // Rooms with no initialized player still need a focus target. Descendant
      // controls/text inputs retain their own focus and key handling priority.
      child: FocusScope(node: _node, autofocus: true, child: widget.child),
    );
  }
}

/// What one key means on the room surface.
enum VideoKeyAction { none, togglePlay, toggleMute, refresh, toggleFullscreen, volumeUp, volumeDown }

/// The room's key map, as a decision instead of a pile of closures.
///
/// A room whose player never initialized has no [VideoController], and the
/// controller-bound keys must then resolve to nothing rather than throw: the
/// transport keys (play/pause) live on the global player and keep working.
@visibleForTesting
VideoKeyAction resolveVideoKeyAction(LogicalKeyboardKey key, {required bool hasController}) {
  if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) return VideoKeyAction.togglePlay;
  if (!hasController) return VideoKeyAction.none;
  if (key == LogicalKeyboardKey.keyR) return VideoKeyAction.refresh;
  if (key == LogicalKeyboardKey.keyF) return VideoKeyAction.toggleFullscreen;
  if (key == LogicalKeyboardKey.keyM) return VideoKeyAction.toggleMute;
  if (key == LogicalKeyboardKey.arrowUp) return VideoKeyAction.volumeUp;
  if (key == LogicalKeyboardKey.arrowDown) return VideoKeyAction.volumeDown;
  return VideoKeyAction.none;
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
