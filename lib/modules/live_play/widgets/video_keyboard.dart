import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class VideoKeyboardShortcuts extends StatefulWidget {
  final VideoController controller;
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
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _handleEscExit();
      return true;
    }
    return false;
  }

  void _handleEscExit() async {
    if (GlobalPlayerState.to.isPipMode.value) {
      return;
    }
    widget.controller.toggleFullScreen();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () => GlobalPlayerService.instance.playerManager.resume(),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () => GlobalPlayerService.instance.playerManager.pause(),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            GlobalPlayerService.instance.playerManager.togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            GlobalPlayerService.instance.playerManager.togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.keyR): () => widget.controller.refresh(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () async {
          double? volume = await widget.controller.volume();
          volume = (volume ?? 1.0) + 0.05;
          volume = volume.clamp(0.0, 1.0);
          widget.controller.setVolume(volume);
          widget.controller.updateVolumn(volume);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () async {
          double? volume = await widget.controller.volume();
          volume = (volume ?? 1.0) - 0.05;
          volume = volume.clamp(0.0, 1.0);
          widget.controller.setVolume(volume);
          widget.controller.updateVolumn(volume);
        },
      },
      child: widget.child,
    );
  }
}
