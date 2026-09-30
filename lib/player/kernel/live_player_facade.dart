import 'dart:async';

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pure_live/get/get.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/player/kernel/floating_playback.dart';
import 'package:pure_live/player/kernel/kernel_backend_ids.dart';
import 'package:pure_live/player/media_core/player_kernel_service.dart';
import 'package:pure_live/player/models/player_engine.dart';

/// 直播播放门面：页面只跟它说话。
///
/// 架构与 pure_live_TV 同构：打开/换线/重试/看门狗/恢复编排全部是
/// media_core_live `LivePlaybackController` 的；本文件只填 pure_live 业务——
/// 画质表与线路下标的提交回执、owned 私有源 recipe、房间音量、引擎→后端映射。
final class LivePlayerFacade {
  LivePlayerFacade({
    PlayerEngine defaultEngine = PlayerEngine.mediaKit,
    Future<List<PlayerSource>> Function(List<PlayerSource> sources)? interceptSources,
    EngineFallbackSourceResolver? onEngineFallbackSources,
  }) : preferredEngine = defaultEngine {
    _interceptSources = interceptSources;
    _controller = LivePlaybackController(kernel, onEngineFallbackSources: onEngineFallbackSources);
    _bindController();
  }

  /// 源拦截钩子：签名 URL 租约/FLV relay 等宿主业务在打开前包装线路。
  Future<List<PlayerSource>> Function(List<PlayerSource> sources)? _interceptSources;

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
    bool audioOnly = false,
    Future<void> Function()? sourceResolver,
    DateTime? sourceRefreshAt,
    Object? sourceSelection,
  }) async {
    if (_disposed) return;
    if (audioOnly) await setAudioOnlyMode(true);
    final sourceUrl = url.trim();
    if (sourceUrl.isEmpty) throw ArgumentError('Remote playback source is empty');

    final urls = <String>[sourceUrl, ...playUrls.where((value) => value != sourceUrl)];
    _room = room;
    _lastHeaders = Map<String, String>.unmodifiable(headers);
    _lastLines = List<String>.unmodifiable(urls);

    await _controller.play(
      LiveSourceRequest(
        sources: await _intercept([
          for (final url in urls)
            PlayerSource(
              id: SourceId('live-$url'),
              uri: Uri.parse(url),
              type: SourceType.live,
              headers: SourceHeaders(headers),
            ),
        ]),
        title: room?.title,
      ),
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
        sources: await _intercept([
          PlayerSource(
            id: SourceId('owned-${room.identityKey}'),
            uri: Uri(scheme: 'owned', path: room.identityKey),
            type: SourceType.live,
            protocol: SourceProtocol.custom,
            metadata: <String, Object?>{kMediaKitCustomInputKey: recipe},
          ),
        ]),
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

  Future<void> playSource(Object source, {LiveRoom? room, bool audioOnly = false, Object? sourceResolver, Object? sourceSelection}) =>
      playOwned(source, room ?? _room ?? LiveRoom(platform: '', roomId: ''));

  Future<void> switchLine(int index) => _controller.switchLine(index);
  Future<void> retry() => _controller.retry();
  Future<void> togglePlayPause() => _controller.togglePlayPause();
  Future<void> pause() => _controller.pause();
  Future<void> resume() => _controller.resume();
  Future<void> setVolume(double volume) => _controller.setVolume(volume.clamp(0.0, 1.0));
  Future<void> setAudioOnly(bool audioOnly) => _controller.setAudioOnly(audioOnly);
  void setPresentationVisible(bool visible) => _controller.setPresentationVisible(visible);

  Future<void> switchEngine(PlayerEngine engine, {bool isManual = false, bool resumeCurrentSource = true}) async {
    preferredEngine = engine;
    onEngineChanged?.call(engine);
    final current = commit;
    if (current != null && current.urls.isNotEmpty) {
      await _controller.play(
        LiveSourceRequest(
          sources: await _intercept([
            for (final url in current.urls)
              PlayerSource(
                id: SourceId('live-$url'),
                uri: Uri.parse(url),
                type: SourceType.live,
                headers: SourceHeaders(current.headers),
              ),
          ]),
          title: _room?.title,
        ),
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

  Future<List<PlayerSource>> _intercept(List<PlayerSource> sources) async {
    final interceptor = _interceptSources;
    if (interceptor == null) return sources;
    final intercepted = await interceptor(sources);
    return intercepted.isEmpty ? sources : intercepted;
  }

  // ---- PiP / 悬浮 / 几何 / 呈现（兼容面续） ----

  final RxBool isInPip = false.obs;
  final RxBool isPipPreparing = false.obs;
  final RxInt videoPresentationRevision = 0.obs;

  /// 由 GlobalPlayerService 注入的悬浮会话。
  late final FloatingPlayback floating;

  bool get isAppFloatingActive => floating.isAppFloatingActive;
  bool get shouldKeepDanmakuForAppFloating => floating.isAppFloatingActive;
  void prepareAppFloating() => floating.prepare();
  Future<void> showAppFloating({Widget Function(BuildContext)? danmakuBuilder}) =>
      floating.showAppFloating(danmakuBuilder: danmakuBuilder);
  Future<void> closeAppFloating() => floating.closeAppFloating();
  void prepareRoomSessionReentry() => floating.prepare();
  FacadeStreamCommit? consumeRoomSessionReentry() => floating.consumeRoomReentry();
  void cancelRoomSessionReentry() => floating.cancelRoomReentry();
  void setVideoPresentationVisible(bool visible) => setPresentationVisible(visible);

  /// Android 系统 PiP：经 kernel 呈现链申请 pip 模式。
  Future<void> enablePip() async {
    isPipPreparing.value = true;
    try {
      final driver = kernel.presentationDriver;
      if (driver != null) {
        await driver.apply(handle?.id ?? PlayerId('pure-live'), PresentationRequest.pip());
      }
    } finally {
      isPipPreparing.value = false;
    }
  }

  /// PiP 紧凑面：视频 + 暂停 + 关闭。
  Widget buildPiPOverlay() => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      children: [
        GestureDetector(onDoubleTap: () => unawaited(enablePip()), child: getVideoWidget(BoxFit.contain)),
        Center(
          child: IconButton(
            iconSize: 42,
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            icon: Icon(isPlayingNow ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
            onPressed: togglePlayPause,
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            onPressed: () => unawaited(close()),
          ),
        ),
      ],
    ),
  );

  double get currentPresentationAspectRatio {
    final size = handle?.combinedSnapshot.geometry.videoSize;
    if (size == null || size.width <= 0 || size.height <= 0) return 16 / 9;
    return size.width / size.height;
  }

  String get effectiveVideoOrientation =>
      isVerticalVideo.value ? 'portrait' : 'landscape';

  /// 旧渲染入口：fitIndex/fitList 或 BoxFit 都接受；其余旧参数为兼容保留。
  Widget getVideoWidgetCompat(
    Object fit, {
    List<BoxFit>? fitList,
    Widget? controls,
    bool trackPipSource = false,
    bool? audioOnlyOverride,
    Color? surfaceColor,
    double? videoViewportAspectRatio,
    Object? portraitFullscreenDisplayMode,
  }) {
    final resolved = fit is int ? (fitList == null || fitList.isEmpty ? BoxFit.contain : fitList[fit.clamp(0, fitList.length - 1)]) : fit as BoxFit;
    final video = getVideoWidget(resolved);
    if (controls == null) return video;
    return Stack(children: [Positioned.fill(child: video), controls]);
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
