import '../models/player_state.dart';

import 'package:flutter/material.dart';

import '../models/player_exception.dart';

import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/player/models/player_engine.dart';

abstract class UnifiedPlayer {
  Future<void> init({bool audioOnly = false});
  PlayerEngine get engine;

  /// 设置数据源
  /// [url] 当前播放地址
  /// [playUrls] 备用地址列表
  /// [headers] HTTP 请求头
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  // 不销毁播放器
  Future<void> softStop();

  /// Enables or disables video decoding/rendering without replacing the
  /// player or reopening the current live stream. Surface-backed adapters must
  /// serialize this with their surface lifecycle.
  Future<void> setAudioOnly(bool audioOnly);

  // 真正释放播放器
  Future<void> hardDispose();

  Future<void> setVolume(double volume);

  /// 获取渲染组件
  /// [fitIndex] 对应 BoxFit 的索引
  /// [controls] 覆盖在视频上的 UI 控制层
  /// Builds the native video view with [fit] as the only viewport scaling
  /// policy for this widget generation.
  ///
  /// Passing the fit directly avoids mutating an adapter and then wrapping its
  /// still-updating native view in a second [FittedBox]. That ordering was
  /// especially visible for portrait streams while decoder geometry settled.
  Widget getVideoWidget({BoxFit? fit});

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

/// Optional capability implemented by native adapters that can apply the
/// selected viewport fit without wrapping their texture/platform view in a
/// transformed widget.  Keeping the fit inside the adapter also lets the
/// Windows media_kit surface receive the real viewport size instead of the
/// source video's intrinsic dimensions.
abstract interface class VideoFitAwarePlayer {
  void setVideoFit(BoxFit fit);
}

/// Optional capability for adapters which retain one native player while
/// replacing its live source.
///
/// The manager calls this synchronously before it rebinds source-scoped
/// listeners. Implementations must clear cached dimensions, completion and
/// recoverable native errors here, before the asynchronous native open starts.
/// This prevents a BehaviorSubject or a delayed callback from the previous URL
/// being accepted as evidence for the replacement URL.
abstract interface class SourceTransitionAwarePlayer {
  void beginSourceTransition();
}

/// Optional capability for a native player that can retry the current source
/// with software video decoding before the manager allocates another engine.
///
/// Implementations only prepare the next source open; they must not mutate the
/// active decoder immediately because doing so can emit another native error
/// inside the recovery callback that requested the fallback. Returning `true`
/// means the manager should reopen the current URL once on this same player.
abstract interface class DecoderRecoveryAwarePlayer {
  Future<bool> prepareSoftwareDecoderFallback(PlayerException error);
}
