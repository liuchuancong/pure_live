import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_loading.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

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
      final audioOnly = controller.audioOnlyState.value;
      final state = controller.livePlayController.state.value;
      final displayVideo = state.ui.displayVideoLayer;

      return StableVideoLayer(
        visible: displayVideo,
        // Android SurfaceProducer instances are expensive and historically
        // failed to recover when a covered route rebuilt the video subtree.
        // Windows uses a native media_kit texture with different lifetime
        // rules: leaving it mounted while another Flutter route animates over
        // it can race the compositor and crash flutter_windows.dll.  Tear the
        // texture widget down only on Windows; the Player itself stays alive.
        preserveMountedVideo: !PlatformUtils.isWindows,
        placeholder: const VideoLoading(),
        video: GlobalPlayerService.instance.player.getVideoWidget(
          SettingsService.to.player.videoFitIndex.v,
          fitList: SettingsService.to.player.videoFitArray,
          trackPipSource: true,
          audioOnlyOverride: audioOnly,
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

/// Controls native-texture ownership while another route temporarily covers it.
///
/// Replacing the texture with a loading widget used to tear down and recreate
/// the Flutter video subtree around the recording page. On Android that races
/// SurfaceProducer cleanup/availability callbacks and can leave a black frame,
/// paused decoder or stale portrait geometry after returning, so Android keeps
/// it offstage. Windows detaches it until the covering route has fully popped
/// to avoid a native-texture teardown race.
class StableVideoLayer extends StatelessWidget {
  const StableVideoLayer({
    super.key,
    required this.visible,
    required this.video,
    required this.placeholder,
    this.preserveMountedVideo = true,
  });

  final bool visible;
  final Widget video;
  final Widget placeholder;
  final bool preserveMountedVideo;

  @override
  Widget build(BuildContext context) {
    if (!visible && !preserveMountedVideo) {
      return placeholder;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: !visible, child: video),
        if (!visible) placeholder,
      ],
    );
  }
}
