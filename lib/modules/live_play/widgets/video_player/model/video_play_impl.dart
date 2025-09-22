import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart'
    as video_player;

/// 视频播放器接口
abstract class VideoPlayerInterFace {
  /// 播放链接
  Future<void> openVideo(String datasource, Map<String, String> headers);

  /// 播放
  Future<void> play();

  /// 暂停
  Future<void> pause();

  /// 播放或者暂停
  Future<void> togglePlayPause();

  /// 进入全屏
  Future<void> enterFullscreen();

  /// 退出全屏
  Future<void> exitFullScreen();

  Future<void> toggleFullScreen();

  Future<void> toggleWindowFullScreen() async {
    if (Platform.isWindows || Platform.isLinux) {
      if (!isWindowFullscreen.value) {
        Get.to(() => DesktopFullscreen(
          key: UniqueKey(),
          widget: getVideoPlayerWidget(),
        ));
      } else {
        Navigator.of(Get.context!).pop();
      }
      isWindowFullscreen.toggle();
    } else {
      throw UnimplementedError('Unsupported Platform');
    }
  }

  /// 设置视频填充
  void setVideoFit(BoxFit fit);

  /// 销毁
  void dispose();

  /// 错误播放
  final hasError = false.obs;

  /// 是否播放
  final isPlaying = false.obs;

  /// 是否在缓冲中
  final isBuffering = false.obs;

  /// 是否 画中画
  final isPipMode = false.obs;

  /// 是否 全屏
  final isFullscreen = false.obs;

  /// 是否 窗口全屏
  final isWindowFullscreen = false.obs;

  /// 是否 销毁全屏
  bool isDestoried = false;

  /// 是否 竖屏
  final isVertical = false.obs;

  /// 是否 支持画中画
  bool get supportPip =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid || Platform.isIOS;


  void enterPipMode() async {
    if (Platform.isWindows || Platform.isLinux|| Platform.isMacOS) {
      if (!isPipMode.value) {
        Get.to(() => DesktopPip(
          key: UniqueKey(),
          widget: getVideoPlayerWidget(),
        ));
      } else {
        Navigator.of(Get.context!).pop();
      }
      isPipMode.toggle();
    } else {
      throw UnimplementedError('Unsupported Platform');
    }
  }

  /// 是否 支持 窗口全屏
  bool get supportWindowFull =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// 是否 进入 窗口全屏
  bool get fullscreenUI => isFullscreen.value || isWindowFullscreen.value;

  final List<String> winPlatformList = ["linux", "macos", "windows"];

  /// 支持的平台
  List<String> get supportPlatformList;

  /// 是否支持
  bool get isSupport => supportPlatformList.contains(Platform.operatingSystem);

  /// 设置横屏
  Future<void> setLandscapeOrientation() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// 设置竖屏
  Future<void> setPortraitOrientation() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values);
  }

  /// 锁屏
  void disableRotation() {}

  /// 解锁屏
  void enableRotation() {}

  /// 播放器名称
  String get playerName;

  /// 初始化
  void init({required video_player.VideoController controller});

  /// 获取 播放器视图
  Widget getVideoPlayerWidget();

  /// 获取 播放器全屏视图
  Widget getDesktopFullscreenWidget() => getVideoPlayerWidget();
}

class DesktopFullscreen extends StatelessWidget {
  const DesktopFullscreen(
      {super.key,
        required this.widget});

  final Widget widget;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            widget
          ],
        ),
      ),
    );
  }
}

class DesktopPip extends StatelessWidget {
  const DesktopPip(
      {super.key,
        required this.widget});

  final Widget widget;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              widget
            ],
          ),
        ),
    );
  }
}
