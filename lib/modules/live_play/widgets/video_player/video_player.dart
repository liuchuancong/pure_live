import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class VideoPlayer extends StatefulWidget {
  final VideoController controller;
  const VideoPlayer({super.key, required this.controller});

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  VideoController get controller => widget.controller;
  Widget _buildVideo() {
    return Obx(
      () => GlobalPlayerService.instance.playerManager.getVideoWidget(
        controller.settings.videoFitIndex.value,
        fitList: controller.settings.videofitArrary,
        controls: VideoControllerPanel(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideo();
  }
}
