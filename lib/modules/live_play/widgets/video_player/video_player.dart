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

class _VideoPlayerState extends State<VideoPlayer> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 注册监听
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 销毁监听
    super.dispose();
  }

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

  bool _isPausedByLifecycle = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final settingsService = Get.find<SettingsService>();
    final player = GlobalPlayerService.instance.playerManager;

    if (state == AppLifecycleState.paused) {
      if (!settingsService.enableBackgroundPlay.value) {
        if (player.isPlayingNow) {
          _isPausedByLifecycle = true;
          player.pause();
        }
      } else {
        player.resume();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isPausedByLifecycle) {
        player.resume();
        _isPausedByLifecycle = false; // 重置标记
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideo();
  }
}
