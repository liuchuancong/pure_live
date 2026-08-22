import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_loading.dart';
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
    return Obx(() {
      final audioOnly = controller.audioOnlyState.value;
      final state = controller.livePlayController.state.value;
      final displayVideo = state.ui.displayVideoLayer;

      return _DelayedVideoWidget(
        displayVideo: displayVideo,
        audioOnly: audioOnly,
        videoFitIndex: SettingsService.to.player.videoFitIndex.v,
        fitList: SettingsService.to.player.videoFitArray,
        controller: controller,
      );
    });
  }

  bool _isPausedByLifecycle = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final player = GlobalPlayerService.instance.player;

    if (state == AppLifecycleState.paused) {
      // A short foreground-only warm window makes a manual audio/video toggle
      // instant. Once the app backgrounds, prefer the real low-power path so
      // overnight listening never keeps the video decoder running.
      if (player.isAudioOnlyMode) {
        unawaited(player.commitAudioOnlyPowerSaving());
      }
      if (!LiveAudioService.shouldContinueInBackground) {
        if (player.isPlayingNow) {
          _isPausedByLifecycle = true;
          player.pause();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (player.isAudioOnlyMode && !LiveAudioService.isSleepSessionActive) {
        unawaited(player.prepareAudioOnlyVideoRestore());
      }
      if (_isPausedByLifecycle) {
        player.resume();
        _isPausedByLifecycle = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideo();
  }
}

class _DelayedVideoWidget extends StatefulWidget {
  final bool displayVideo;
  final bool audioOnly;
  final int videoFitIndex;
  final List<BoxFit> fitList;
  final VideoController controller;

  const _DelayedVideoWidget({
    required this.displayVideo,
    required this.audioOnly,
    required this.videoFitIndex,
    required this.fitList,
    required this.controller,
  });

  @override
  State<_DelayedVideoWidget> createState() => _DelayedVideoWidgetState();
}

class _DelayedVideoWidgetState extends State<_DelayedVideoWidget> {
  Timer? _timer;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    if (widget.displayVideo) {
      _startDelay();
    }
  }

  @override
  void didUpdateWidget(covariant _DelayedVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.displayVideo != widget.displayVideo) {
      if (!widget.displayVideo) {
        _timer?.cancel();
        _timer = null;
        if (_showVideo) {
          setState(() {
            _showVideo = false;
          });
        }
      } else {
        _startDelay();
      }
    }
  }

  void _startDelay() {
    _timer?.cancel();
    if (_showVideo) {
      setState(() {
        _showVideo = false;
      });
    }
    _timer = Timer(const Duration(milliseconds: 20), () {
      if (!mounted || !widget.displayVideo) {
        return;
      }
      setState(() {
        _showVideo = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showVideo) {
      return VideoLoading();
    }

    return GlobalPlayerService.instance.player.getVideoWidget(
      widget.videoFitIndex,
      fitList: widget.fitList,
      trackPipSource: true,
      audioOnlyOverride: widget.audioOnly,
      controls: VideoControllerPanel(controller: widget.controller),
    );
  }
}
