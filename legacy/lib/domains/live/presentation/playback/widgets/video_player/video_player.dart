import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/core/portrait_stream_support.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/picture_cover.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/playback_failure_overlay.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';

class VideoPlayer extends StatefulWidget {
  final VideoController controller;
  final Color surfaceColor;
  final double? videoViewportAspectRatio;
  final PortraitFullscreenDisplayMode? portraitFullscreenDisplayMode;
  const VideoPlayer({
    super.key,
    required this.controller,
    this.surfaceColor = Colors.black,
    this.videoViewportAspectRatio,
    this.portraitFullscreenDisplayMode,
  });

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  VideoController get controller => widget.controller;
  Widget _buildVideo() {
    return Obx(() {
      final player = GlobalPlayerService.instance.player;
      final hasError = controller.hasPlaybackError;

      return PlaybackFailureOverlay(
        hasError: hasError,
        onRetry: controller.refresh,
        child: player.getVideoWidgetCompat(
          SettingsService.to.player.videoFitIndex.v,
          fitList: SettingsService.to.player.videoFitArray,
          trackPipSource: true,
          pictureCover: pictureCoverFor(
            audioOnly: controller.audioOnlyState.value,
            dummyVideo: player.isDummyVideo.value,
            room: controller.room,
          ),
          controls: VideoControllerPanel(controller: controller),
          surfaceColor: widget.surfaceColor,
          videoViewportAspectRatio: widget.videoViewportAspectRatio,
          portraitFullscreenDisplayMode: widget.portraitFullscreenDisplayMode,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideo();
  }
}
