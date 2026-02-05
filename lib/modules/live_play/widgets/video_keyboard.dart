import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class VideoKeyboardShortcuts extends StatelessWidget {
  final VideoController controller;
  final Widget child;

  const VideoKeyboardShortcuts({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlay): () => controller.globalPlayer.play(),
        const SingleActivator(LogicalKeyboardKey.mediaPause): () => controller.globalPlayer.pause(),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () => controller.globalPlayer.togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.space): () => controller.globalPlayer.togglePlayPause(),
        const SingleActivator(LogicalKeyboardKey.keyR): () => controller.refresh(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () async {
          double? volume = await controller.volume();
          volume = (volume ?? 1.0) + 0.05;
          volume = volume.clamp(0.0, 1.0);
          controller.setVolume(volume);
          controller.updateVolumn(volume);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () async {
          double? volume = await controller.volume();
          volume = (volume ?? 1.0) - 0.05;
          volume = volume.clamp(0.0, 1.0);
          controller.setVolume(volume);
          controller.updateVolumn(volume);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () => controller.toggleFullScreen(),
      },
      child: child,
    );
  }
}
