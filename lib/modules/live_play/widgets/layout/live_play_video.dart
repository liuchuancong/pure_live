import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_player.dart';
import 'package:pure_live/modules/live_play/widgets/placeholder/not_living_video_widget.dart';

class LivePlayVideo extends StatelessWidget {
  const LivePlayVideo({super.key, required this.controller});

  final LivePlayController controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Obx(() {
          final state = controller.state.value;
          final videoController = state.player.videoController;
          if (videoController == null) {
            if (state.room.isLoading || state.room.isLiving) {
              return const _VideoLoading();
            }
            return NotLivingVideoWidget(controller: controller);
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: VideoPlayer(controller: videoController),
              ),
              if (state.room.isLoading) const _VideoLoading(),
            ],
          );
        }),
      ),
    );
  }
}

class _VideoLoading extends StatelessWidget {
  const _VideoLoading();

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ColoredBox(color: Colors.black),
          AppStatusView(type: AppStatusType.loading, title: '', subtitle: '', iconColor: Colors.white, isMini: true),
        ],
      ),
    );
  }
}
