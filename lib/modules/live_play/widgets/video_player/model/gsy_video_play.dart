import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gsy_video_player/gsy_video_player.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/fix_gsy_video_player_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart'
    as video_player;
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/modules/util/listen_list_util.dart';
import 'package:pure_live/modules/util/rx_util.dart';

import 'video_play_impl.dart';

class GsyVideoPlay extends VideoPlayerInterFace {
  // Video player control
  late GsyVideoPlayerController gsyVideoPlayerController;

  late Rx<ChewieController> chewieController =
      ChewieController(videoPlayerController: gsyVideoPlayerController).obs;

  /// 存储 Stream 流监听
  /// 默认视频 MPV 视频监听流
  final defaultVideoStreamSubscriptionList = <StreamSubscription>[];

  final SettingsService settings = Get.find<SettingsService>();

  @override
  late final String playerName;
  late GsyVideoPlayerType playerType;

  GsyVideoPlay(
      {required this.playerName, this.playerType = GsyVideoPlayerType.ijk});

  late video_player.VideoController controller;

  @override
  void init({required video_player.VideoController controller}) {
    this.controller = controller;
    if(isFirstOpenVideo) {
      ListenListUtil.clearStreamSubscriptionList(
          defaultVideoStreamSubscriptionList);
    }
    gsyVideoPlayerController = FixGsyVideoPlayerController(
        allowBackgroundPlayback: settings.enableBackgroundPlay.value,
        player: playerType);
    chewieController.value = ChewieController(
      videoPlayerController: gsyVideoPlayerController,
      autoPlay: false,
      looping: false,
      draggableProgressBar: false,
      overlay: VideoControllerPanel(
        controller: controller,
      ),
      showControls: false,
      useRootNavigator: true,
      showOptions: false,
      rotateWithSystem: settings.enableRotateScreenWithSystem.value,
    );

    var enableCodec = settings.enableCodec.value;

    gsyVideoPlayerController
        .setRenderType(GsyVideoPlayerRenderType.surfaceView);
    gsyVideoPlayerController.setTimeOut(4000);
    gsyVideoPlayerController.setMediaCodec(enableCodec);
    gsyVideoPlayerController.setMediaCodecTexture(enableCodec);

    defaultVideoStreamSubscriptionList.add(
        gsyVideoPlayerController.videoEventStreamController.stream.listen((e) {
      // switch (e.playState) {
      //   case VideoPlayState.playing:
      //   case VideoPlayState.playingBufferingStart:
      //   case VideoPlayState.pause:
      //   case VideoPlayState.completed:
      //   case VideoPlayState.completed:
      //     isBuffering.updateValueNotEquate(e.isPlaying == false || false);
      //     break;
      //
      //   case VideoPlayState.normal:
      //   case VideoPlayState.prepareing:
      //   case VideoPlayState.error:
      //   case VideoPlayState.unknown:
      //     isBuffering.updateValueNotEquate(e.isPlaying == false || true);
      //     break;
      //   default:
      //     isBuffering.updateValueNotEquate(e.isPlaying == false || true);
      //     break;
      // }
      var size = e.size;
      var isBuffering2 = e.isBuffering;
      if (isBuffering2 != null) {
        isBuffering.updateValueNotEquate(!isBuffering2);
      }
      if (size != null) {
        // isVertical.value = (size.height) > (size.width);
        isVertical.updateValueNotEquate((size.height) > (size.width));
      }
    }));
    gsyVideoPlayerController.addEventsListener(gsyEventsListener);
    chewieController.addListener(chewieControllerListener);
  }

  void chewieControllerListener() {
    var tmpIsLive = chewieController.value.isLive;
    var tmpIsPlaying = chewieController.value.isPlaying;
    var tmpIsFullScreen =
        chewieController.value.videoPlayerController.value.isFullScreen;
    CoreLog.d(
        "isLive $tmpIsLive isPlaying $tmpIsPlaying isFullScreen $tmpIsFullScreen");
    isFullscreen.updateValueNotEquate(tmpIsFullScreen);
    isPlaying.updateValueNotEquate(tmpIsPlaying);
  }

  void gsyEventsListener(VideoEventType event) {
    // if (event == VideoEventType.onError) {
    //   hasError.updateValueNotEquate(true);
    //   isPlaying.updateValueNotEquate(false);
    //   CoreLog.d('gsyVideoPlayer error ${gsyVideoPlayerController.value.what}');
    // } else {
    //   isPlaying.value = gsyVideoPlayerController.value.isPlaying;
    // }
    hasError.updateValueNotEquate(event == VideoEventType.onError);
    var tmpIsPlaying = gsyVideoPlayerController.value.isPlaying;
    isPlaying.updateValueNotEquate(tmpIsPlaying);
    if (tmpIsPlaying) {
      isBuffering.updateValueNotEquate(!tmpIsPlaying);
    }
    // isBuffering.updateValueNotEquate(gsyVideoPlayerController.value.isBuffering);
    isVertical.updateValueNotEquate(gsyVideoPlayerController.value.size.width <
        gsyVideoPlayerController.value.size.height);
  }

  /// GSYVideoPlayer 释放监听
  void disposeGSYVideoPlayerListener() {
    gsyVideoPlayerController.removeEventsListener(gsyEventsListener);
    chewieController.removeListener(chewieControllerListener);
  }

  @override
  void dispose() {
    ListenListUtil.clearStreamSubscriptionList(
        defaultVideoStreamSubscriptionList);
    disposeGSYVideoPlayerListener();
    gsyVideoPlayerController.dispose();
    chewieController.dispose();
  }

  @override
  Future<void> enterFullscreen() async {
    gsyVideoPlayerController.enterFullScreen();
  }

  @override
  Future<void> exitFullScreen() async {
    gsyVideoPlayerController.exitFullScreen();
  }


  bool isFirstOpenVideo = true;

  @override
  Future<void> openVideo(String datasource, Map<String, String> headers) async {
    CoreLog.d("play url: $datasource");
    if(isFirstOpenVideo) {
      isFirstOpenVideo = !isFirstOpenVideo;
    } else {
      init(controller: controller);
    }
    // fix datasource empty error
    if (datasource.isEmpty) {
      hasError.value = true;
      return;
    } else {
      hasError.value = false;
    }
    // isBuffering.updateValueNotEquate(true);
    isPlaying.updateValueNotEquate(false);
    // fix bug
    isBuffering.updateValueNotEquate(false);
    gsyVideoPlayerController.setDataSourceBuilder(
      datasource,
      mapHeadData: headers,
      cacheWithPlay: false,
      useDefaultIjkOptions: true,
    );
    play();
  }

  @override
  Future<void> pause() async {
    return gsyVideoPlayerController.pause();
  }

  @override
  Future<void> play() {
    return gsyVideoPlayerController.resume();
  }

  @override
  void setVideoFit(BoxFit fit) {
    gsyVideoPlayerController.setBoxFit(fit);
  }

  @override
  bool get supportPip => true;

  @override
  Future<void> enterPipMode() async {
    await gsyVideoPlayerController.enablePictureInPicture();
  }

  @override
  List<String> get supportPlatformList => ["android"];

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
    gsyVideoPlayerController.toggleFullScreen();
  }

  @override
  Future<void> toggleWindowFullScreen() async {
    return toggleFullScreen();
  }

  @override
  Future<void> togglePlayPause() async {
    gsyVideoPlayerController.playOrPause();
  }

  @override
  Future<void> setLandscapeOrientation() async {
    super.setLandscapeOrientation();
    gsyVideoPlayerController.resolveByClick();
  }

  @override
  Future<void> setPortraitOrientation() async {
    super.setPortraitOrientation();
    gsyVideoPlayerController.backToProtVideo();
  }

  @override
  void disableRotation() {
    chewieController.value.disableRotation();
  }

  @override
  void enableRotation() {
    chewieController.value.enableRotation();
  }
}
