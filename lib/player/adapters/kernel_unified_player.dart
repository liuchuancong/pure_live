import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_core/media_core.dart' as mc;
import 'package:media_core_better_player/media_core_video_player.dart' show kBetterPlayerBackendId;
import 'package:media_core_fvp/media_core_fvp.dart' show kFvpPlayerBackendId;
import 'package:media_core_ijk_player/media_core_ijk_player.dart' show kIjkPlayerBackendId;
import 'package:media_core_media_kit/media_core_media_kit.dart'
    show MediaKitPlayerAdapter, kMediaKitPlayerBackendId;
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:pure_live/player/interface/media_kit_player_accessor.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/player/media_core/player_kernel_service.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_state.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

/// [UnifiedPlayer] 的 media_core 桥：引擎实际是 kernel 的 [mc.PlayerHandle]，
/// 后端由 [backendId] 钉定（mpv/ijk/better_player/fvp），渲染走通用
/// [mc.MediaPlayerView]。会话代际/命令串行化/恢复梯都在 handle 上。
class KernelUnifiedPlayer extends UnifiedPlayer
    implements
        SourceTransitionAwarePlayer,
        VideoFitAwarePlayer,
        PrivateInputAwarePlayer,
        DecoderRecoveryAwarePlayer,
        AudioOutputSuppressionAwarePlayer,
        MediaKitPlayerAccessor {
  KernelUnifiedPlayer({this.backendId = kMediaKitPlayerBackendId});

  /// 本桥钉定的 kernel 后端 id。
  final String backendId;

  mc.PlayerHandle? _handle;
  bool _audioOnly = false;
  bool _disposed = false;
  int _openedSources = 0;
  List<String> _lineCandidates = const <String>[];
  Map<String, String> _headers = const <String, String>{};

  final _stateController = StreamController<PlayerState>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<PlayerException>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _completeController = StreamController<bool>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _heightController = StreamController<int?>.broadcast();
  StreamSubscription<mc.PlaybackState>? _playbackSub;
  StreamSubscription<mc.PlayerAdapterEvent>? _eventSub;

  @override
  PlayerEngine get engine => switch (backendId) {
    kIjkPlayerBackendId => PlayerEngine.fijk,
    kBetterPlayerBackendId => PlayerEngine.exo,
    kFvpPlayerBackendId => PlayerEngine.fvp,
    _ => PlayerEngine.mediaKit,
  };

  mc.PlayerHandle? get handle => _handle;

  @override
  Future<void> init({bool audioOnly = false}) async {
    _audioOnly = audioOnly;
  }

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    if (_disposed) return;
    _audioOnly = audioOnly;
    _lineCandidates = List<String>.unmodifiable(playUrls);
    _headers = Map<String, String>.unmodifiable(headers);
    final source = _buildSource(url, headers);
    final existing = _handle;
    if (existing == null || existing.disposed) {
      await _createHandle(source);
      return;
    }
    existing.setSourceCandidates(_candidateSources(url));
    await existing.open(source, autoPlay: true);
  }

  /// 线路候选（不含当前线路）：RecoveryLadder 的 nextLine 备选源。
  List<mc.PlayerSource> _candidateSources(String currentUrl) {
    return [
      for (final line in _lineCandidates)
        if (line != currentUrl) _buildSource(line, _headers),
    ];
  }

  mc.PlayerSource _buildSource(String url, Map<String, String> headers) {
    final uri = Uri.parse(url);
    final protocol = switch (uri.scheme) {
      'https' => mc.SourceProtocol.https,
      'http' => mc.SourceProtocol.http,
      'file' => mc.SourceProtocol.file,
      _ => mc.SourceProtocol.unknown,
    };
    return mc.PlayerSource(
      id: mc.SourceId('pure-live-${DateTime.now().microsecondsSinceEpoch}-${_openedSources++}'),
      uri: uri,
      type: mc.SourceType.live,
      protocol: protocol,
      headers: mc.SourceHeaders(headers),
    );
  }

  Future<void> _createHandle(mc.PlayerSource source) async {
    final handle = await PlayerKernelService.instance.kernel.create(
      source: source,
      config: mc.PlayerConfig(autoPlay: true, enableVideo: !_audioOnly, enableRecovery: true),
      preferredBackend: backendId,
    );
    handle.setSourceCandidates(_candidateSources(source.uri.toString()));
    _handle = handle;
    _bind(handle);
  }

  void _bind(mc.PlayerHandle handle) {
    unawaited(_playbackSub?.cancel());
    unawaited(_eventSub?.cancel());
    var lastCompleted = false;
    var lastPlaying = false;
    var lastLoading = false;
    _playbackSub = handle.playbackStream.listen((state) {
      _stateController.add(_mapState(state));
      final completed = state.isCompleted;
      if (completed && !lastCompleted) _completeController.add(true);
      if (!completed && lastCompleted) _completeController.add(false);
      lastCompleted = completed;
      final playing = state.isPlaying;
      if (playing != lastPlaying) _playingController.add(playing);
      lastPlaying = playing;
      final loading = state.isBuffering || state.isLoading;
      if (loading != lastLoading) _loadingController.add(loading);
      lastLoading = loading;
    }, onError: (Object error) {
      _errorController.add(
        PlayerException(message: error.toString(), type: PlayerErrorType.unknown, error: error),
      );
    });
    _eventSub = handle.adapterEvents.listen((event) {
      switch (event) {
        case mc.PlayerAdapterVideoSizeChanged(:final width, :final height):
          _widthController.add(width <= 0 ? null : width);
          _heightController.add(height <= 0 ? null : height);
        case mc.PlayerAdapterErrorEvent(:final message, :final error, :final stackTrace):
          // 错误上报进 RecoveryLadder：候选线路/后端由 handle 的候选提供者
          // 决定，梯子决策经 recoveryEvents 观测；应用流只收展示用异常。
          handle.reportFailure(
            mc.RecoveryFailure.fromMessage(message, error: error, stackTrace: stackTrace),
            source: mc.RecoveryFailureSource.adapter,
          );
          _errorController.add(
            PlayerException(
              message: message,
              type: PlayerErrorType.native,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        default:
          break;
      }
    });
  }

  PlayerState _mapState(mc.PlaybackState state) {
    if (state.isPlaying) return PlayerState.playing;
    if (state.isPaused) return PlayerState.paused;
    if (state.isCompleted) return PlayerState.completed;
    if (state.isStopped) return PlayerState.stopped;
    if (state.isBuffering || state.isLoading) return PlayerState.buffering;
    if (state.initialized) return PlayerState.ready;
    return PlayerState.initializing;
  }

  @override
  Future<void> play() async => _handle?.play();

  @override
  Future<void> pause() async => _handle?.pause();

  @override
  Future<void> stop() async => _handle?.pause();

  @override
  Future<void> softStop() async => _handle?.pause();

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_audioOnly == audioOnly) return;
    _audioOnly = audioOnly;
    final handle = _handle;
    if (handle == null || handle.disposed) return;
    final source = handle.source;
    await handle.dispose();
    _handle = null;
    if (source == null) return;
    await _createHandle(source);
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;
    _disposed = true;
    await _playbackSub?.cancel();
    await _eventSub?.cancel();
    _playbackSub = null;
    _eventSub = null;
    await _handle?.dispose();
    _handle = null;
    unawaited(_stateController.close());
    unawaited(_playingController.close());
    unawaited(_errorController.close());
    unawaited(_loadingController.close());
    unawaited(_completeController.close());
    unawaited(_widthController.close());
    unawaited(_heightController.close());
  }

  @override
  Future<void> setVolume(double volume) async => _handle?.setVolume(volume.clamp(0.0, 1.0));

  @override
  Widget getVideoWidget({BoxFit? fit}) {
    final handle = _handle;
    if (handle == null) return const SizedBox.expand();
    return mc.MediaPlayerView(handle: handle, fit: fit ?? BoxFit.contain);
  }

  @override
  void setVideoFit(BoxFit fit) {
    // MediaPlayerView 每次构建都带最新 fit，无需适配器侧状态。
  }

  @override
  void beginSourceTransition() {
    _widthController.add(null);
    _heightController.add(null);
    _completeController.add(false);
    _playingController.add(false);
  }

  // 竖屏内容探针的底层访问入口（仅 mpv 后端有实现；其他后端抛错，
  // 探针调用方已用 `is MediaKitPlayerAccessor` 守卫——桥恒为 accessor，
  // 所以这里显式区分后端）。
  @override
  mk.Player get mediaKitPlayer => _requireMediaKit().player;

  @override
  mkv.VideoController get mediaKitVideoController => _requireMediaKit().videoController ?? (throw StateError('video controller not created yet'));

  MediaKitPlayerAdapter _requireMediaKit() {
    final adapter = _mediaKitAdapter();
    if (adapter == null) {
      throw StateError('media_kit accessor is only available on the mpv backend (current: $backendId)');
    }
    return adapter;
  }

  MediaKitPlayerAdapter? _mediaKitAdapter() {
    final handle = _handle;
    if (handle == null || handle.disposed) return null;
    final adapter = handle.adapter;
    return adapter is MediaKitPlayerAdapter ? adapter : null;
  }

  @override
  void setPrivateInput(bool value, {String? sourceIdentity}) {
    // 回环输入绕过原生代理；kernel adapter 在下一次 open 前应用。
    _mediaKitAdapter()?.setPrivateInput(value);
  }

  @override
  Future<bool> prepareSoftwareDecoderFallback(PlayerException error) async {
    final adapter = _mediaKitAdapter();
    if (adapter == null) return false;
    // 只准备下一次 open 用软解；重开由 manager 的既有同源重试驱动，
    // 走 handle.open 的串行化路径。
    adapter.prepareSoftwareDecoderFallback();
    return true;
  }

  @override
  void setAudioOutputSuppressed(bool suppressed) {
    unawaited(_mediaKitAdapter()?.setAudioOutputSuppressed(suppressed));
  }

  @override
  bool get isInitialized => _handle != null && !_handle!.disposed;

  @override
  bool get isPlayingNow => _handle?.isPlaying ?? false;

  @override
  bool get isReusable => isInitialized;

  @override
  Stream<PlayerState> get onStateChanged => _stateController.stream;

  @override
  Stream<bool> get onPlaying => _playingController.stream;

  @override
  Stream<PlayerException> get onError => _errorController.stream;

  @override
  Stream<bool> get onLoading => _loadingController.stream;

  @override
  Stream<bool> get onComplete => _completeController.stream;

  @override
  Stream<int?> get width => _widthController.stream;

  @override
  Stream<int?> get height => _heightController.stream;
}
