import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class VideoPlayer extends StatefulWidget {
  final VideoController controller;

  const VideoPlayer({
    super.key,
    required this.controller,
  });

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  bool hasRender = false;

  // Widget _buildVideoPanel() {
  //   return VideoControllerPanel(
  //     controller: widget.controller,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    /// 使用 mpv 解码
    return Stack(children: [
      widget.controller.videoPlayer.getVideoPlayerWidget(),

      /// 视频加载中
      StreamBuilder(
          stream: widget.controller.videoPlayer.isBuffering.stream,
          builder: (s, d) => Visibility(
              visible: widget.controller.videoPlayer.isBuffering.value,
              child: const Center(
                child: CircularProgressIndicator(),
              ))),

      /// 封面
      // Obx(() => Visibility(
      //     visible: !widget.controller.mediaPlayerControllerInitialized.value,
      //     child: Card(
      //       elevation: 0,
      //       margin: const EdgeInsets.all(0),
      //       shape:
      //           const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      //       clipBehavior: Clip.antiAlias,
      //       color: Get.theme.focusColor,
      //       child: CacheNetWorkUtils.getCacheImageV2(widget.controller.room.cover!),
      //     ))),
    ]);
  }
}
