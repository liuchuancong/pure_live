import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_player.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_loading.dart';
import 'package:pure_live/modules/live_play/widgets/placeholder/not_living_video_widget.dart';

class LivePlayVideo extends StatelessWidget {
  const LivePlayVideo({super.key, required this.controller, this.expandToParent = false});

  final LivePlayController controller;
  final bool expandToParent;

  @override
  Widget build(BuildContext context) {
    return LivePlayVideoFrame(
      expandToParent: expandToParent,
      child: ColoredBox(
        color: Colors.black,
        child: Obx(() {
          final state = controller.state.value;
          final videoController = state.player.videoController;

          if (videoController == null) {
            if (state.room.isLoading || state.room.isLiving) {
              return const VideoLoading();
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
            ],
          );
        }),
      ),
    );
  }
}

@visibleForTesting
class LivePlayVideoFrame extends StatelessWidget {
  const LivePlayVideoFrame({super.key, required this.child, required this.expandToParent});

  final Widget child;
  final bool expandToParent;

  @override
  Widget build(BuildContext context) {
    if (!expandToParent) {
      return AspectRatio(aspectRatio: 16 / 9, child: child);
    }

    final settings = PlayerSettingsController.to;
    final mode = settings.portraitVideoHeightMode;
    final customHeight = settings.portraitCustomHeight.v;

    switch (mode) {
      case PortraitVideoHeightMode.adaptive:
        return SafeArea(top: true, bottom: false, left: false, right: false, child: SizedBox.expand(child: child));

      case PortraitVideoHeightMode.custom:
        return SizedBox(width: double.infinity, height: customHeight, child: child);

      case PortraitVideoHeightMode.full:
        return SizedBox.expand(child: child);
    }
  }
}
