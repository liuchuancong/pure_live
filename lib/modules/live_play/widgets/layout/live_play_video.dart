import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_player.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_loading.dart';
import 'package:pure_live/modules/live_play/widgets/placeholder/not_living_video_widget.dart';

class LivePlayVideo extends StatelessWidget {
  const LivePlayVideo({
    super.key,
    required this.controller,
    this.expandToParent = false,
    this.surfaceColor = Colors.black,
    this.fitOverride,
  });

  final LivePlayController controller;
  final bool expandToParent;
  final Color surfaceColor;
  final BoxFit? fitOverride;

  @override
  Widget build(BuildContext context) {
    return LivePlayVideoFrame(
      expandToParent: expandToParent,
      child: ColoredBox(
        color: surfaceColor,
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
                color: surfaceColor,
                child: VideoPlayer(controller: videoController, surfaceColor: surfaceColor, fitOverride: fitOverride),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Keeps the legacy 16:9 contract for every ordinary landscape room.
///
/// Only a caller that already owns an explicit adaptive portrait/fullscreen
/// frame may opt into expansion. Making the generic video widget expand by
/// default lets an unrelated parent constraint change every playback mode at
/// once, which caused the v3.0.1 landscape/PiP regression.
@visibleForTesting
class LivePlayVideoFrame extends StatelessWidget {
  const LivePlayVideoFrame({super.key, required this.child, required this.expandToParent});

  final Widget child;
  final bool expandToParent;

  @override
  Widget build(BuildContext context) {
    if (expandToParent) return SizedBox.expand(child: child);
    return AspectRatio(aspectRatio: 16 / 9, child: child);
  }
}
