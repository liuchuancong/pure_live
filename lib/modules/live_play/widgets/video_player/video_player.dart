import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
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

class _VideoPlayerState extends State<VideoPlayer> with WidgetsBindingObserver {
  VideoController get controller => widget.controller;

  bool _isPausedByLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final player = GlobalPlayerService.instance.player;

    if (state == AppLifecycleState.paused) {
      if (player.isAudioOnlyMode) {
        unawaited(player.commitAudioOnlyPowerSaving());
      }

      if (!LiveAudioService.shouldContinueInBackground) {
        if (player.isPlayingNow) {
          _isPausedByLifecycle = true;
          unawaited(player.pause());
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (player.isAudioOnlyMode && !LiveAudioService.isSleepSessionActive) {
        unawaited(player.prepareAudioOnlyVideoRestore());
      }

      if (_isPausedByLifecycle) {
        unawaited(player.resume());
        _isPausedByLifecycle = false;
      }
    }
  }

  Widget _buildVideo() {
    return Obx(() {
      final audioOnly = controller.audioOnlyState.value;
      final state = controller.livePlayController.state.value;
      final displayVideo = state.ui.displayVideoLayer;
      return StableVideoLayer(
        visible: displayVideo,
        preserveMountedVideo: !PlatformUtils.isWindows,
        placeholder: const VideoLoading(),
        video: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedRotation(
              turns: state.ui.uiRotation / 360,
              duration: const Duration(milliseconds: 300),
              child: GlobalPlayerService.instance.player.getVideoWidget(
                SettingsService.to.player.videoFitIndex.v,
                fitList: SettingsService.to.player.videoFitArray,
                trackPipSource: true,
                audioOnlyOverride: audioOnly,
              ),
            ),
            VideoControllerPanel(controller: controller),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideo();
  }
}

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
