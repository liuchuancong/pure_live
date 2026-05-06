import '../models/player_state.dart';
import 'package:flutter/material.dart';
import '../models/player_exception.dart';

abstract class UnifiedPlayer {
  Future<void> init();

  /// 设置数据源
  /// [url] 当前播放地址
  /// [playUrls] 备用地址列表
  /// [headers] HTTP 请求头
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  // 不销毁播放器
  Future<void> softStop();

  // 真正释放播放器
  Future<void> hardDispose();

  Future<void> setVolume(double volume);

  /// 获取渲染组件
  /// [fitIndex] 对应 BoxFit 的索引
  /// [controls] 覆盖在视频上的 UI 控制层
  Widget getVideoWidget();

  bool get isInitialized;

  bool get isPlayingNow;

  bool get isReusable;

  // --- 状态流 ---

  Stream<PlayerState> get onStateChanged;

  Stream<bool> get onPlaying;

  Stream<PlayerException> get onError;

  Stream<bool> get onLoading;

  Stream<bool> get onComplete;

  Stream<int?> get width;

  Stream<int?> get height;
}
