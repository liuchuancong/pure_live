import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_loading.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class VideoPlayer extends StatefulWidget {
  final VideoController controller;
  final Color surfaceColor;
  final double? videoViewportAspectRatio;
  const VideoPlayer({
    super.key,
    required this.controller,
    this.surfaceColor = Colors.black,
    this.videoViewportAspectRatio,
  });

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  VideoController get controller => widget.controller;
  Widget _buildVideo() {
    return Obx(() {
      final audioOnly = controller.audioOnlyState.value;
      final state = controller.livePlayController.state.value;
      final displayVideo = state.ui.displayVideoLayer;

      return StableVideoLayer(
        visible: displayVideo,
        placeholder: const VideoLoading(),
        video: GlobalPlayerService.instance.player.getVideoWidget(
          SettingsService.to.player.videoFitIndex.v,
          fitList: SettingsService.to.player.videoFitArray,
          trackPipSource: true,
          audioOnlyOverride: audioOnly,
          controls: VideoControllerPanel(controller: controller),
          surfaceColor: widget.surfaceColor,
          videoViewportAspectRatio: widget.videoViewportAspectRatio,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideo();
  }
}

/// Keeps the native texture mounted while another route temporarily covers it.
///
/// Replacing the texture with a loading widget used to tear down and recreate
/// the Flutter video subtree around the recording page. On Android that races
/// SurfaceProducer cleanup/availability callbacks and can leave a black frame,
/// paused decoder or stale portrait geometry after returning.
class StableVideoLayer extends StatelessWidget {
  const StableVideoLayer({super.key, required this.visible, required this.video, required this.placeholder});

  final bool visible;
  final Widget video;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: !visible, child: video),
        if (!visible) placeholder,
      ],
    );
  }
}
