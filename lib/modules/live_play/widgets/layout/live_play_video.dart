import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_player.dart';
import 'package:pure_live/modules/live_play/widgets/placeholder/not_living_video_widget.dart';

class LivePlayVideo extends StatelessWidget {
  const LivePlayVideo({super.key, required this.controller, this.widescreen = false});

  final LivePlayController controller;
  final bool widescreen;

  @override
  Widget build(BuildContext context) {
    final player = AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Obx(() {
          final state = controller.state.value;

          if (state.room.success && state.player.videoController != null) {
            return Stack(
              children: [
                Positioned.fill(child: VideoPlayer(controller: state.player.videoController!)),

                if (state.room.isLoading) const _VideoLoading(),
              ],
            );
          }

          if (state.room.isLoading || state.room.isLiving) {
            return const _VideoLoading();
          }

          return NotLivingVideoWidget(controller: controller, key: UniqueKey());
        }),
      ),
    );

    return player;
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
