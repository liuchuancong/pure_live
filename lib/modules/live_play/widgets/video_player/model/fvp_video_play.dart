import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart' as video_player;
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/modules/util/listen_list_util.dart';
import 'package:pure_live/modules/util/rx_util.dart';
import 'package:video_player/video_player.dart';

import 'video_play_impl.dart';

/// FVP 播放器
class FvpVideoPlay extends VideoPlayerInterFace {
  // Video player control
  late Rx<VideoPlayerController> videoPlayerController = VideoPlayerController.networkUrl(Uri.parse("")).obs;

  // late ChewieController chewieController;

  late Rx<ChewieController> chewieController = ChewieController(videoPlayerController: videoPlayerController.value).obs;

  /// 存储 Stream 流监听
  /// 默认视频 MPV 视频监听流
  final defaultVideoStreamSubscriptionList = <StreamSubscription>[];

  final SettingsService settings = Get.find<SettingsService>();

  /// 存储 视频控制器，用于没有释放的视频流
  static final controllerList = <VideoPlayerController>[];

  @override
  late final String playerName;

  FvpVideoPlay({
    required this.playerName,
  });

  late video_player.VideoController controller;

  @override
  void init({required video_player.VideoController controller}) {
    this.controller = controller;
    ListenListUtil.clearStreamSubscriptionList(defaultVideoStreamSubscriptionList);

    VideoPlayerOptions options = VideoPlayerOptions(allowBackgroundPlayback: true);
    videoPlayerController.value = VideoPlayerController.networkUrl(
      Uri.parse(""),
      videoPlayerOptions: options,
    );
    chewieController.value = ChewieController(
      videoPlayerController: videoPlayerController.value,
      autoPlay: false,
      looping: false,
      draggableProgressBar: false,
      overlay: VideoControllerPanel(
        controller: controller,
      ),
      showControls: false,
      useRootNavigator: true,
      showOptions: false,
    );

    // var enableCodec = settings.enableCodec.value;

    //notifyListeners();
  }

  // void EventsListener(VideoEventType event) {
  //   if (event == VideoEventType.onError) {
  //     hasError.value = true;
  //     isPlaying.value = false;
  //     CoreLog.d('VideoPlayer error ${videoPlayerController.value.value.what}');
  //   } else {
  //     isPlaying.value = videoPlayerController.value.value.isPlaying;
  //   }
  // }

  /// VideoPlayer 释放监听
  void disposeVideoPlayerListener() {
    // chewieController.value.videoPlayerController.value.value.
    // chewieController.value.removeListener(EventsListener);
  }

  @override
  Future<void> dispose() async {
    ListenListUtil.clearStreamSubscriptionList(defaultVideoStreamSubscriptionList);
    disposeVideoPlayerListener();
    videoPlayerController.value.removeListener(listenerVideo);
    // chewieController.value.addListener(chewieControllerListener);
    videoPlayerController.value.dispose();
    chewieController.value.dispose();
    for (var i = 0; i < controllerList.length; i++) {
      var controller = controllerList[i];
      try {
        await controller.dispose();
      } catch (e) {
        //
      }
    }
    // super.dispose();
  }

  @override
  Future<void> enterFullscreen() async {
    chewieController.value.enterFullScreen();
  }

  @override
  Future<void> exitFullScreen() async {
    chewieController.value.exitFullScreen();
  }

  @override
  Future<void> openVideo(String datasource, Map<String, String> headers) async {
    isBuffering.updateValueNotEquate(true);
    isPlaying.updateValueNotEquate(false);
    CoreLog.d("play url: $datasource");
    // fix datasource empty error
    if (datasource.isEmpty) {
      hasError.value = true;
      return;
    } else {
      hasError.value = false;
    }
    VideoPlayerOptions options = VideoPlayerOptions(allowBackgroundPlayback: true);

    var oldVideo = videoPlayerController.value;
    videoPlayerController.value.removeListener(listenerVideo);
    try {
      oldVideo.dispose();
    } catch (e) {
      CoreLog.error(e);
    }
    // videoPlayerController.value.remove
    var videoPlayerController2 = VideoPlayerController.networkUrl(
      Uri.parse(datasource),
      videoPlayerOptions: options,
      httpHeaders: headers,
    );
    videoPlayerController.value = videoPlayerController2;

    controllerList.add(videoPlayerController2);

    videoPlayerController.value.addListener(listenerVideo);
    // await videoPlayerController.value.initialize();
    var oldValue = chewieController.value;
    initChewieController();
    try {
      oldValue.removeListener(chewieControllerListener);
      oldValue.dispose();
    } catch (e) {
      CoreLog.error(e);
    }

  }

  /// 视频宽和高比
  double? aspectRatio;

  void initChewieController() {
    try {
      chewieController.value.removeListener(chewieControllerListener);
      // chewieController.value.dispose();
    } catch (e) {
      CoreLog.error(e);
    }
    chewieController.value = ChewieController(
      videoPlayerController: videoPlayerController.value,
      autoPlay: true,
      looping: false,
      aspectRatio: aspectRatio,
      //视频宽和高比
      draggableProgressBar: true,
      overlay: VideoControllerPanel(
        controller: controller,
      ),
      showControls: false,
      useRootNavigator: true,
      showOptions: false,
      // fullScreenByDefault: true,
      // systemOverlaysOnEnterFullScreen: SystemUiOverlay.values,
      // deviceOrientationsOnEnterFullScreen: [
      //   DeviceOrientation.landscapeLeft,
      //   DeviceOrientation.landscapeRight
      // ],
      // systemOverlaysAfterFullScreen: SystemUiOverlay.values,
      // deviceOrientationsAfterFullScreen: [
      //   DeviceOrientation.portraitUp,
      //   DeviceOrientation.portraitDown
      // ],
      // isLive: true,
    );

    chewieController.value.addListener(chewieControllerListener);
  }

  void chewieControllerListener() {
    var tmpIsLive = chewieController.value.isLive;
    var tmpIsPlaying = chewieController.value.isPlaying;
    var tmpIsFullScreen = chewieController.value.isFullScreen;
    CoreLog.d("isLive $tmpIsLive isPlaying $tmpIsPlaying isFullScreen $tmpIsFullScreen");
    isFullscreen.updateValueNotEquate(tmpIsFullScreen);
    isPlaying.updateValueNotEquate(tmpIsPlaying);
  }

  void listenerVideo() {
    // videoPlayerController.value.printInfo();
    // videoPlayerController.value.printError();
    var isError = videoPlayerController.value.value.errorDescription != null;
    if (isError) {
      CoreLog.d("Error: ${videoPlayerController.value.value.errorDescription}");
    }
    hasError.updateValueNotEquate(videoPlayerController.value.value.errorDescription != null);
    isPlaying.updateValueNotEquate(videoPlayerController.value.value.isPlaying);
    isBuffering.updateValueNotEquate(videoPlayerController.value.value.isBuffering);
    isVertical.updateValueNotEquate(videoPlayerController.value.value.size.width < videoPlayerController.value.value.size.height);

    // CoreLog.d("isPlaying: ${isPlaying} isBuffering: $isBuffering hasError: $hasError");

    var tmpAspectRatio = videoPlayerController.value.value.size.width / videoPlayerController.value.value.size.height;

    /// 重新设置宽高比
    if (tmpAspectRatio != aspectRatio) {
      aspectRatio = tmpAspectRatio;
      initChewieController();
    }
  }

  @override
  Future<void> pause() async {
    return chewieController.value.pause();
  }

  @override
  Future<void> play() {
    return chewieController.value.play();
  }

  @override
  void setVideoFit(BoxFit fit) {
    // chewieController.value.aspectRatio = 1.0;
  }

  @override
  bool get supportPip => true;

  @override
  List<String> get supportPlatformList => ["linux", "macos", "windows", "android", "ios"];

  @override
  Widget getVideoPlayerWidget() {
    try {
      return StreamBuilder(
          initialData: chewieController.value,
          stream: chewieController.stream,
          builder: (s, d) => d.data == null
              ? Container()
              : Chewie(
            key: UniqueKey(),
            controller: d.data!,
          ));
    } catch (e) {
      CoreLog.error(e);
      return Container();
    }
  }

  @override
  Future<void> toggleFullScreen() async {
    isFullscreen.toggle();
    chewieController.value.toggleFullScreen();
  }

  @override
  Future<void> togglePlayPause() async {
    chewieController.value.togglePause();
  }

  // @override
  // Future<void> setLandscapeOrientation() async {
  //   super.setLandscapeOrientation();
  //   // chewieController.value.resolveByClick();
  // }

  // @override
  // Future<void> setPortraitOrientation() async {
  //   super.setPortraitOrientation();
  //   // chewieController.value.backToProtVideo();
  // }

  @override
  void disableRotation() {
    // chewieController.value.disableRotation();
  }

  @override
  void enableRotation() {
    // chewieController.value.enableRotation();
  }
}
