import 'dart:async';

import 'package:media_core/media_core.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/player/media_core/player_kernel_service.dart';

/// 一个直播会话的完整播放面：创建→打开→呈现→释放，全部经由 media_core。
///
/// 每个 [LivePlaybackSession] 拥有一个 kernel [PlayerHandle]；换源/换线/
/// 恢复由 handle 内置的命令串行化、会话代际与 RecoveryLadder 决策，
/// 签名 URL 续期等业务通过 source 元数据/候选注入。
class LivePlaybackSession {
  LivePlaybackSession({this.backendId = kMediaKitPlayerBackendId});

  final String backendId;

  PlayerHandle? _handle;
  bool _disposed = false;

  PlayerHandle? get handle => _handle;
  bool get isDisposed => _disposed;
  bool get isPlaying => _handle?.isPlaying ?? false;
  PlayerId? get playerId => _handle?.id;

  Future<PlayerHandle> _ensureHandle({PlayerSource? initialSource}) async {
    final existing = _handle;
    if (existing != null && !existing.disposed) return existing;
    final handle = initialSource == null
        ? await PlayerKernelService.instance.kernel.create(preferredBackend: backendId)
        : await PlayerKernelService.instance.kernel.create(
            source: initialSource,
            config: const PlayerConfig(autoPlay: true, enableRecovery: true),
            preferredBackend: backendId,
          );
    _handle = handle;
    return handle;
  }

  /// 打开一个源；[alternates] 是其余线路，换线时由梯子依次尝试。
  Future<void> open(PlayerSource source, {List<PlayerSource> alternates = const []}) async {
    if (_disposed) throw StateError('session disposed');
    final handle = await _ensureHandle(initialSource: source);
    handle.setSourceCandidates(alternates);
    await handle.open(source, autoPlay: true);
  }

  Future<void> play() => _handle?.play() ?? Future.value();
  Future<void> pause() => _handle?.pause() ?? Future.value();
  Future<void> setVolume(double volume) => _handle?.setVolume(volume.clamp(0.0, 1.0)) ?? Future.value();

  Stream<PlaybackState> get playback =>
      _handle?.playbackStream ?? const Stream.empty();

  /// 换源（同解码器热切换）；恢复与失败重试仍归梯子。
  Future<void> reopen(PlayerSource source) async {
    final handle = _handle;
    if (handle == null || handle.disposed) {
      await open(source);
      return;
    }
    await handle.open(source, autoPlay: true);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _handle?.dispose();
    _handle = null;
  }
}
