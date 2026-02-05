import 'package:flutter/material.dart';
// unified_player_interface.dart

abstract class UnifiedPlayer {
  // 初始化
  Future<void> init();

  // 设置播放源
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers);

  // 播放 / 暂停
  Future<void> play();

  Future<void> pause();

  Future<void> setVolume(double volume);

  // 获取用于渲染的 Widget（由具体实现返回 Video 或 FijkView）
  Widget getVideoWidget(int index, Widget? controls);

  // 释放资源
  void dispose();

  // 可选：监听播放状态（playing, error 等）
  Stream<bool> get onPlaying;

  Stream<String?> get onError;

  Stream<bool> get onLoading;

  Stream<bool> get onComplete;

  Stream<int?> get width;

  Stream<int?> get height;

  bool get isPlayingNow;

  void stop() {}

  void release() {}
}
