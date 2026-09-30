import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pure_live/get/get.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/kernel/kernel_backend_ids.dart';
import 'package:pure_live/player/media_core/player_kernel_service.dart';
import 'package:pure_live/player/models/player_engine.dart';

/// 直播播放门面：页面只跟它说话。
///
/// 架构与 pure_live_TV 同构：打开/换线/重试/看门狗/恢复编排全部是
/// media_core_live `LivePlaybackController` 的；本文件只填 pure_live 业务——
/// 画质表与线路下标的提交回执、owned 私有源 recipe、房间音量、引擎→后端映射。
final class LivePlayerFacade {
  LivePlayerFacade({PlayerEngine defaultEngine = PlayerEngine.mediaKit})
    : preferredEngine = defaultEngine {
    _controller = LivePlaybackController(kernel);
    _bindController();
  }

  static PlayerKernel get kernel => PlayerKernelService.instance.kernel;

  late final LivePlaybackController _controller;

  /// 用户首选引擎；恢复梯换后端时经 [onEngineChanged] 通知页面。
  PlayerEngine preferredEngine;
  void Function(PlayerEngine engine)? onEngineChanged;

  final _stateSubject = StreamController<PlayerState>.broadcast();
  final _playingSubject = StreamController<bool>.broadcast();
  final _errorSubject = StreamController<PlayerFailure>.broadcast();
  final _commitSubject = StreamController<FacadeStreamCommit?>.broadcast();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<PlayerFailure>? _errorSub;
  bool _disposed = false;

  /// 最近一次成功提交的源（权威画质/线路状态）。
  FacadeStreamCommit? commit;
  Map<String, String> _lastHeaders = const {};
  List<String> _lastLines = const [];
  LiveRoom? _room;

  LiveRoom? get room => _room;
  PlayerHandle? get handle => _controller.handle;
  bool get hasPlaybackSource => commit != null;
  bool get isPlayingNow => _playingSubject.hasListener && _lastPlaying;
  bool _lastPlaying = false;
  int get currentLineIndex => commit?.currentLineIndex ?? 0;
  int get lineCount => _lastLines.length;
  List<String> get playUrls => _lastLines;
  List<LivePlayQuality> get qualites => commit?.qualities ?? const [];
  int get currentQuality => commit?.currentQuality ?? 0;
  Map<String, String> get sourceQueryPolicies => const {};

  Stream<PlayerState> get onStateChanged => _stateSubject.stream;
  Stream<bool> get onPlaying => _playingSubject.stream;
  Stream<PlayerFailure> get onError => _errorSubject.stream;
  Stream<FacadeStreamCommit?> get onCommitChanged => _commitSubject.stream;

  void _bindController() {
    _stateSub = _controller.onStateChanged.listen((state) {
      _stateSubject.add(state);
      _onStateChanged(state);
      final playing = state.playback == PlayerPlaybackState.playing;
      if (playing != _lastPlaying) {
        _lastPlaying = playing;
        _playingSubject.add(playing);
      }
    });
    _errorSub = _controller.onError.listen(_errorSubject.add);
  }

  /// 打开一个房间源：[url] 当前线路, [playUrls] 全部线路（恢复梯的换线序）,
  /// [qualities]/[currentQuality] 画质表（提交回执供菜单渲染）。
  Future<void> play(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    List<LivePlayQuality> qualities = const [],
    int currentQuality = 0,
  }) async {
    if (_disposed) return;
    final sourceUrl = url.trim();
    if (sourceUrl.isEmpty) throw ArgumentError('Remote playback source is empty');

    final urls = <String>[sourceUrl, ...playUrls.where((value) => value != sourceUrl)];
    _room = room;
    _lastHeaders = Map<String, String>.unmodifiable(headers);
    _lastLines = List<String>.unmodifiable(urls);

    await _controller.play(
      LiveSourceRequest.fromUrls(urls, headers: headers, title: room?.title),
      preferredBackend: backendIdOfEngine(preferredEngine),
    );
    _publishCommit(sourceUrl, qualities, currentQuality);
    if (room != null) await setVolume(room.getSavedVolume().clamp(0.0, 1.0));
  }

  /// owned 私有协议源（bigo/fc2/niconico）：recipe 走 custom-input 通道。
  Future<void> playOwned(
    Object recipe,
    LiveRoom room, {
    List<LivePlayQuality> qualities = const [],
    int currentQuality = 0,
  }) async {
    if (_disposed) return;
    _room = room;
    _lastHeaders = const {};
    _lastLines = const [];
    await _controller.play(
      LiveSourceRequest(
        sources: [
          PlayerSource(
            id: SourceId('owned-${room.identityKey}'),
            uri: Uri(scheme: 'owned', path: room.identityKey),
            type: SourceType.live,
            protocol: SourceProtocol.custom,
            metadata: <String, Object?>{kMediaKitCustomInputKey: recipe},
          ),
        ],
      ),
      preferredBackend: backendIdOfEngine(preferredEngine),
    );
    _publishCommit('owned:${room.identityKey}', qualities, currentQuality);
    await setVolume(room.getSavedVolume().clamp(0.0, 1.0));
  }

  void _publishCommit(String url, List<LivePlayQuality> qualities, int currentQuality) {
    final lineIndex = _lastLines.isEmpty ? 0 : _lastLines.indexOf(url).clamp(0, _lastLines.length - 1);
    commit = FacadeStreamCommit(
      room: _room,
      urls: _lastLines,
      currentUrl: url,
      currentLineIndex: lineIndex,
      headers: _lastHeaders,
      qualities: List<LivePlayQuality>.unmodifiable(qualities),
      currentQuality: currentQuality,
    );
    _commitSubject.add(commit);
  }

  Future<void> switchLine(int index) => _controller.switchLine(index);
  Future<void> retry() => _controller.retry();
  Future<void> togglePlayPause() => _controller.togglePlayPause();
  Future<void> pause() => _controller.pause();
  Future<void> resume() => _controller.resume();
  Future<void> setVolume(double volume) => _controller.setVolume(volume.clamp(0.0, 1.0));
  Future<void> setAudioOnly(bool audioOnly) => _controller.setAudioOnly(audioOnly);
  void setPresentationVisible(bool visible) => _controller.setPresentationVisible(visible);

  Future<void> switchEngine(PlayerEngine engine) async {
    preferredEngine = engine;
    onEngineChanged?.call(engine);
    final current = commit;
    if (current != null && current.urls.isNotEmpty) {
      await _controller.play(
        LiveSourceRequest.fromUrls(current.urls, headers: current.headers, title: _room?.title),
        preferredBackend: backendIdOfEngine(engine),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 兼容面：与旧 PlayerManager 同名的成员，消费者按原名编译，切换即翻牌。
  // ---------------------------------------------------------------------------

  final RxBool hasError = false.obs;
  final RxBool _audioOnlyMode = false.obs;
  final RxBool isVerticalVideo = false.obs;
  final _loadingSubject = StreamController<bool>.broadcast();
  bool _lastLoading = false;

  bool get isAudioOnlyMode => _audioOnlyMode.value;
  bool get desiredAudioOnlyMode => _audioOnlyMode.value;
  Stream<bool> get onLoading => _loadingSubject.stream;
  Stream<FacadeStreamCommit?> get onSourceCommitted => _commitSubject.stream;
  FacadeStreamCommit? get currentSourceCommit => commit;
  bool isSourceCommitCurrent(FacadeStreamCommit value) => identical(value, commit);

  Future<void> setAudioOnlyMode(bool audioOnly) async {
    _audioOnlyMode.value = audioOnly;
    await setAudioOnly(audioOnly);
  }

  /// 渲染出口：kernel 的通用视频视图（fit 由调用方给）。
  Widget getVideoWidget(BoxFit fit) {
    final handle = _controller.handle;
    if (handle == null) return const SizedBox.expand();
    return MediaPlayerView(handle: handle, fit: fit);
  }

  void changeVideoFit(BoxFit fit) {
    final adapter = _controller.handle?.adapter;
    if (adapter is MediaKitPlayerAdapter) {
      adapter.videoConfig = adapter.videoConfig.copyWith(fit: fit);
    }
  }

  dynamic get currentPlayer => _controller.handle;
  LiveRoom? get currentFloatRoom => _room;
  bool hasActivePlaybackSession(LiveRoom room) => _room == room && isPlayingNow;
  bool get isCompactModeActive => false;
  void refreshPortraitPresentationPolicy() {}
  void attachVideoController(dynamic controller) {}
  void detachVideoController(dynamic controller) {}
  bool ownsVideoController(dynamic controller) => false;

  void _onStateChanged(PlayerState state) {
    final loading = state.playback == PlayerPlaybackState.buffering;
    if (loading != _lastLoading) {
      _lastLoading = loading;
      _loadingSubject.add(loading);
    }
    final handle = _controller.handle;
    final size = handle?.combinedSnapshot.geometry.videoSize;
    final next = size != null && size.height > size.width;
    if (next != isVerticalVideo.value) isVerticalVideo.value = next;
  }

  Future<void> close() => _controller.close();
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateSub?.cancel();
    await _playingSub?.cancel();
    await _errorSub?.cancel();
    await _controller.dispose();
    await _stateSubject.close();
    await _playingSubject.close();
    await _errorSubject.close();
    await _commitSubject.close();
    await _loadingSubject.close();
  }
}

/// 源提交回执：画质表 + 线路的权威快照。
@immutable
class FacadeStreamCommit {
  const FacadeStreamCommit({
    required this.room,
    required this.urls,
    required this.currentUrl,
    required this.currentLineIndex,
    required this.headers,
    required this.qualities,
    required this.currentQuality,
  });

  final LiveRoom? room;
  final List<String> urls;
  final String currentUrl;
  final int currentLineIndex;
  final Map<String, String> headers;
  final List<LivePlayQuality> qualities;
  final int currentQuality;
}
