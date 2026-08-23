import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/adapters/media_kit_adapter.dart';

/// multiview 单格播放器契约。
///
/// 释放路径收敛为 pause → disposePlayer 两步。所有权约定：
/// 渲染控制器（VideoController）的原生清理全权由 player.dispose 触发的
/// release 钩子完成（patched media_kit 在该钩子中执行 id/rect notifier
/// 清理、取消订阅、移除静态表并发送 VideoOutputManager.Dispose），
/// 应用层不得再直接调用 platform.dispose——那会造成 id/rect 双重销毁，
/// 触发 ChangeNotifier 断言崩溃（对齐 MediaKitAdapter 主播放器的
/// 所有权模式，其从不直接销毁渲染控制器）。
abstract interface class MultiviewCellPlayerHandle {
  /// 该格的渲染控制器，供 UI 的 Video widget 使用；尚未创建时为 null。
  VideoController? get videoController;

  /// 创建播放内核与渲染控制器并静音起播。
  ///
  /// 音频策略：所有格一律以音量 0 起播，只有获得音频焦点的格才会恢复音量。
  Future<void> start({required String url, required Map<String, String> headers});

  /// 静音/取消静音（音频焦点切换时由控制器调用）。
  Future<void> setMuted(bool muted);

  /// 恢复播放（用户主动的临时暂停后的继续；与释放流程的 [pause] 语义无关）。
  Future<void> resume();

  /// 连续音量（0.0-1.0，会话级不持久化）。
  ///
  /// 与静音状态相互独立：静音期间设置音量只更新目标值，
  /// 取消静音后按该值生效（替代旧的取消静音固定恢复 1.0 行为）。
  Future<void> setVolume(double volume);

  /// 当前是否正在播放（供 UI 播放/暂停按钮态）；未起播时为 false。
  bool get isPlaying;

  /// 会话音量当前值（0.0-1.0）；供 UI 音量控件读取初值。
  double get volume;

  /// 播放状态流；未起播时为空流。UI 订阅以驱动按钮态。
  Stream<bool> get playingStream;

  /// 在既有播放内核上换流（每格清晰度切换）：同 Player 重新 open，
  /// 纹理保持附着、不重建实例；mpv 音量属性跨加载保留，静音状态不丢失。
  /// 未起播前调用属编程错误，实现必须 Fail Fast。
  Future<void> open({required String url, required Map<String, String> headers});

  /// 暂停播放。既作为释放流程第 1 步，也可用于用户主动的临时暂停
  /// （配合 [resume] 恢复）；两种场景共用同一底层调用。
  Future<void> pause();

  /// 释放步骤 2：销毁播放内核；渲染控制器的原生清理随其 release 钩子完成。
  Future<void> disposePlayer();
}

/// 单格播放器工厂：按目标渲染分辨率创建一格播放器。
///
/// 生产环境绑定 [MultiviewCellPlayer]；测试注入记录调用序列的假实现。
typedef MultiviewCellPlayerFactory = MultiviewCellPlayerHandle Function({
  required int renderWidth,
  required int renderHeight,
});

/// 单格播放器持有者（非 widget）。
///
/// 自持独立的 media_kit Player + VideoController，绕开全局单实例的
/// PlayerManager/GlobalPlayerService/PlayerPool。每格渲染分辨率在构造时
/// 由控制器按当前布局计算并固定，避免 Windows 共享渲染线程下多实例
/// 相互争抢全分辨率输出。
class MultiviewCellPlayer implements MultiviewCellPlayerHandle {
  MultiviewCellPlayer({required this.renderWidth, required this.renderHeight});

  /// 固定的渲染输出宽度（物理像素），来自布局均分结果。
  final int renderWidth;

  /// 固定的渲染输出高度（物理像素），来自布局均分结果。
  final int renderHeight;

  Player? _player;

  VideoController? _controller;

  /// 会话级音量（0.0-1.0）；静音时保持该值，取消静音后生效。
  double _volume = 1.0;

  /// 静音标志；起播默认静音（音频焦点模型）。
  bool _muted = true;

  @override
  VideoController? get videoController => _controller;

  @override
  bool get isPlaying => _player?.state.playing ?? false;

  @override
  double get volume => _volume;

  @override
  Stream<bool> get playingStream {
    final player = _player;
    if (player == null) return const Stream.empty();
    return player.stream.playing;
  }

  @override
  Future<void> start({required String url, required Map<String, String> headers}) async {
    MediaKit.ensureInitialized();

    final player = Player();
    _player = player;

    if (player.platform is NativePlayer) {
      final native = player.platform as dynamic;
      // 与主播放器共用同一套低延迟直播 mpv 属性。
      await MediaKitAdapter.applyNativeLiveProperties(native);
    }

    // 静音起播：先于 open 设置音量，避免首帧前出现声音毛刺；
    // 获得音频焦点后由 setMuted(false) 恢复到会话音量。
    await player.setVolume(_muted ? 0.0 : _volume * 100);

    // 渲染配置与主播放器默认分支一致；multiview 不使用兼容模式与自定义输出
    // 分支（它们面向单画面调优），但必须固定 width/height。
    // Android/Web 平台忽略 width/height（media_kit 官方语义），无副作用。
    final controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: PlatformUtils.isMacOS ? false : SettingsService.to.player.enableCodec.v,
        hwdec: PlatformUtils.isMacOS ? 'no' : null,
        androidAttachSurfaceAfterVideoParameters: false,
        width: renderWidth,
        height: renderHeight,
      ),
    );
    _controller = controller;

    await player.open(Media(url, httpHeaders: headers), play: true);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _applyVolume();
  }

  @override
  Future<void> resume() async {
    final player = _player;
    if (player == null) {
      // 恢复必须发生在已起播的实例上；未起播说明调用方状态机有缺陷。
      throw StateError('MultiviewCellPlayer: resume before start');
    }
    await player.play();
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _applyVolume();
  }

  /// 按静音标志与会话音量计算实际输出音量并下发；
  /// 未起播时仅更新状态，起播流程会按同一模型设置初始音量。
  Future<void> _applyVolume() async {
    final player = _player;
    if (player == null) return;
    await player.setVolume(_muted ? 0.0 : _volume * 100);
  }

  @override
  Future<void> open({required String url, required Map<String, String> headers}) async {
    final player = _player;
    if (player == null) {
      // 换流必须发生在已起播的实例上；未起播说明调用方状态机有缺陷。
      throw StateError('MultiviewCellPlayer: open before start');
    }
    await player.open(Media(url, httpHeaders: headers), play: true);
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player == null) return;
    await player.pause();
  }

  @override
  Future<void> disposePlayer() async {
    final player = _player;
    _player = null;
    // 渲染控制器引用一并摘除；其原生清理由 player.dispose 的 release 钩子
    // 全权完成（见接口注释的所有权约定），此处不得直接销毁。
    _controller = null;
    if (player == null) return;
    await player.dispose();
  }
}
