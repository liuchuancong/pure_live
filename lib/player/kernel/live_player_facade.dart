import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/compact_danmaku_overlay.dart';
import 'package:pure_live/player/kernel/floating_playback.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/player/kernel/kernel_backend_ids.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/media_core/player_kernel_service.dart';
import 'package:pure_live/player/utils/fullscreen.dart' show fullscreenDriver;
import 'package:pure_live/player/utils/windows_pip_driver.dart';

///

final class LivePlayerFacade {
  LivePlayerFacade({
    PlayerEngine defaultEngine = PlayerEngine.mediaKit,
    Future<List<PlayerSource>> Function(List<PlayerSource> sources)? interceptSources,
    EngineFallbackSourceResolver? onEngineFallbackSources,
  }) : preferredEngine = defaultEngine {
    _interceptSources = interceptSources;
    _controller = LivePlaybackController(kernel, onEngineFallbackSources: onEngineFallbackSources);
    _bindController();
    // The fullscreen driver is the single source of truth for the fullscreen
    // presentation; the Rx mirror only makes it observable to GetX widgets.
    fullscreenDriver.onFullscreenChanged.listen((_) => _syncSystemFullscreenFromDriver());
    _syncSystemFullscreenFromDriver();
  }

  void _syncSystemFullscreenFromDriver() {
    isSystemFullscreen.value = fullscreenDriver.isSystemFullscreen;
  }

  Future<List<PlayerSource>> Function(List<PlayerSource> sources)? _interceptSources;

  static PlayerKernel get kernel => PlayerKernelService.instance.kernel;

  late final LivePlaybackController _controller;

  PlayerEngine preferredEngine;
  void Function(PlayerEngine engine)? onEngineChanged;

  final _stateSubject = StreamController<PlayerCoreState>.broadcast();
  final _playingSubject = StreamController<bool>.broadcast();
  final _errorSubject = StreamController<PlayerException>.broadcast();
  final _commitSubject = StreamController<FacadeStreamCommit?>.broadcast();

  StreamSubscription<PlayerCoreState>? _stateSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<PlayerFailure>? _errorSub;
  bool _disposed = false;

  FacadeStreamCommit? commit;
  Map<String, String> _lastHeaders = const {};
  List<String> _lastLines = const [];
  LiveRoom? _room;

  LiveRoom? get room => _room;
  PlayerHandle? get handle => _controller.handle;

  /// Kernel-side handle lifecycle: emitted when an engine is attached and
  /// when the current one is released. Video surfaces follow this to mount
  /// as soon as the engine exists instead of waiting for an unrelated
  /// rebuild.
  Stream<PlayerHandle?> get onHandleChanged => _controller.onHandleChanged;
  bool get hasPlaybackSource => commit != null;
  bool get isPlayingNow => _playingSubject.hasListener && _lastPlaying;
  bool _lastPlaying = false;
  int get currentLineIndex => commit?.currentLineIndex ?? 0;
  int get lineCount => _lastLines.length;
  List<String> get playUrls => _lastLines;
  List<LivePlayQuality> get qualites => commit?.qualities ?? const [];
  int get currentQuality => commit?.currentQuality ?? 0;
  Map<String, String> get sourceQueryPolicies => const {};

  Stream<PlayerCoreState> get onStateChanged => _stateSubject.stream;
  Stream<bool> get onPlaying => _playingSubject.stream;
  Stream<PlayerException> get onError => _errorSubject.stream;
  Stream<PlayerFailure> get onKernelError => _controller.onError;
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
    _errorSub = _controller.onError.listen((failure) {
      _errorSubject.add(
        PlayerException(
          code: failure.code,
          message: failure.message,
          cause: failure.cause,
          stackTrace: failure.stackTrace,
        ),
      );
    });
  }

  Future<void> play(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    List<LivePlayQuality> qualities = const [],
    int currentQuality = 0,
    bool audioOnly = false,
    PlaybackSourceResolver? sourceResolver,
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
    // The commit carries the platform's line order — the list the line
    // selector, the label and the next-line cycling are all written against.
    // `_lastLines` above is the kernel's fallback preference (selected first)
    // and must not leak into it, or every commit would report line 1.
    _publishCommit(sourceUrl, playUrls, qualities, currentQuality);
    if (room != null) await setVolume(room.getSavedVolume().clamp(0.0, 1.0));
  }

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
    _publishCommit('owned:${room.identityKey}', const [], qualities, currentQuality);
    await setVolume(room.getSavedVolume().clamp(0.0, 1.0));
  }

  void _publishCommit(String url, List<String> uiLines, List<LivePlayQuality> qualities, int currentQuality) {
    // `uiLines` is the platform-ordered line list; the index is the line the
    // selector highlighted. Deriving it from `_lastLines` (kernel fallback
    // order, selected line first) would report line 1 for every commit.
    final lineIndex = uiLines.isEmpty ? 0 : uiLines.indexOf(url).clamp(0, uiLines.length - 1);
    commit = FacadeStreamCommit(
      room: _room ?? LiveRoom(platform: '', roomId: ''),
      urls: List<String>.unmodifiable(uiLines),
      currentUrl: url,
      currentLineIndex: lineIndex,
      headers: _lastHeaders,
      qualities: List<LivePlayQuality>.unmodifiable(qualities),
      currentQuality: currentQuality,
    );
    _commitSubject.add(commit);
  }

  Future<void> playSource(
    Object source, {
    LiveRoom? room,
    bool audioOnly = false,
    Object? sourceResolver,
    Object? sourceSelection,
    DateTime? sourceRefreshAt,
  }) => playOwned(source, room ?? _room ?? LiveRoom(platform: '', roomId: ''));

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
      // commit.urls is the platform-ordered line list; the playing line stays
      // the kernel's first candidate across the engine rebuild.
      final lines = current.currentUrl.isEmpty
          ? current.urls
          : <String>[current.currentUrl, ...current.urls.where((url) => url != current.currentUrl)];
      await _controller.play(
        LiveSourceRequest(
          sources: await _intercept([
            for (final url in lines)
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

  // ---------------------------------------------------------------------------

  final RxBool hasError = false.obs;
  final RxBool _audioOnlyMode = false.obs;
  final RxBool isVerticalVideo = false.obs;
  final _loadingSubject = StreamController<bool>.broadcast();
  bool _lastLoading = false;

  bool get isAudioOnlyMode => _audioOnlyMode.value;
  bool get desiredAudioOnlyMode => _audioOnlyMode.value;
  Stream<bool> get onLoading => _loadingSubject.stream;
  Stream<FacadeStreamCommit> get onSourceCommitted =>
      _commitSubject.stream.where((commit) => commit != null).cast<FacadeStreamCommit>();
  FacadeStreamCommit? get currentSourceCommit => commit;
  bool isSourceCommitCurrent(FacadeStreamCommit value) => identical(value, commit);

  Future<void> setAudioOnlyMode(bool audioOnly) async {
    _audioOnlyMode.value = audioOnly;
    await setAudioOnly(audioOnly);
  }

  Widget getVideoWidget(BoxFit fit) {
    // The room UI mounts before the kernel finishes creating its engine, so
    // the first call usually sees no handle yet. The widget has to follow the
    // kernel's handle stream: a widget built once at mount would stay black
    // forever — nothing else re-reads the attached handle — until a full
    // subtree remount (fullscreen toggle, PiP) forced a rebuild.
    return StreamBuilder<PlayerHandle?>(
      stream: _controller.onHandleChanged.distinct(),
      initialData: _controller.handle,
      builder: (context, snapshot) {
        // Read the getter, not the snapshot: a released engine replays its
        // old handle on the stream, and the getter is the only source of truth.
        final handle = _controller.handle;
        if (handle == null) return const SizedBox.expand();
        return MediaPlayerView(handle: handle, fit: fit);
      },
    );
  }

  void changeVideoFit(Object fitOrIndex, {List<BoxFit>? fitList}) {
    final fit = fitOrIndex is int
        ? (fitList == null || fitList.isEmpty ? BoxFit.contain : fitList[fitOrIndex.clamp(0, fitList.length - 1)])
        : fitOrIndex as BoxFit;
    (_controller.handle?.adapter as PlayerVideo?)?.setVideoFit(fit);
  }

  dynamic get currentPlayer => _controller.handle;

  /// The live room's [VideoController], when one is attached. Used by the
  /// floating-window and picture-in-picture overlays to mount the compact
  /// danmaku surface.
  dynamic get activeVideoController => _activeVideoController;
  LiveRoom? get currentFloatRoom => _room;
  bool hasActivePlaybackSession(LiveRoom room) => _room == room && isPlayingNow;

  /// True while the video surface is presented compactly — the system/desktop
  /// picture-in-picture or the in-app small window. The danmaku layer reads
  /// this per message to decide whether the compact barrage surface is fed;
  /// a hardcoded false starves both overlays of danmaku entirely.
  bool get isCompactModeActive => isInPip.value || floating.isAppFloatingActive;
  void refreshPortraitPresentationPolicy() {}

  /// The video controller that currently owns playback (volume, status
  /// arbitration). Attached when a room's controller is constructed and
  /// detached on dispose; `ownsVideoController` gates the controller's
  /// init path — a false answer makes it return before opening the media.
  dynamic _activeVideoController;

  void attachVideoController(dynamic controller) {
    _activeVideoController = controller;
  }

  void detachVideoController(dynamic controller) {
    if (identical(_activeVideoController, controller)) {
      _activeVideoController = null;
    }
  }

  bool ownsVideoController(dynamic controller) => identical(_activeVideoController, controller);

  void _onStateChanged(PlayerCoreState state) {
    final loading = state.playback == PlayerPlaybackState.buffering;
    if (loading != _lastLoading) {
      _lastLoading = loading;
      _loadingSubject.add(loading);
    }
    final handle = _controller.handle;
    final size = handle?.combinedSnapshot.geometry.videoSize;
    final next = size != null && size.height > size.width;
    if (next != isVerticalVideo.value) isVerticalVideo.value = next;
    videoGeometryState.value = _computeVideoGeometry();
  }

  Future<List<PlayerSource>> _intercept(List<PlayerSource> sources) async {
    final interceptor = _interceptSources;
    if (interceptor == null) return sources;
    final intercepted = await interceptor(sources);
    return intercepted.isEmpty ? sources : intercepted;
  }

  final RxBool isInPip = false.obs;
  final RxBool isPipPreparing = false.obs;
  final RxInt videoPresentationRevision = 0.obs;
  StreamSubscription<bool>? _pipStateSub;

  /// System fullscreen — immersive + orientation lock on mobile, window
  /// fullscreen on desktop. Mirrored from the fullscreen driver, which every
  /// presentation transition routes through; the mirror replaces the deleted
  /// GlobalPlayerState hand-synced flags. Manual writes stay meaningful as
  /// timing aids (the title-bar shell must hide before the native
  /// transition), and the next driver event re-states the truth.
  final RxBool isSystemFullscreen = false.obs;

  /// Widescreen room layout. Pure UI state — the presentation drivers have no
  /// notion of it, so unlike [isSystemFullscreen] this is never mirrored.
  final RxBool isWindowFullscreen = false.obs;

  bool get fullscreenUI => isSystemFullscreen.value || isWindowFullscreen.value;

  late final FloatingPlayback floating;

  bool get isAppFloatingActive => floating.isAppFloatingActive;
  bool get shouldKeepDanmakuForAppFloating => floating.isAppFloatingActive;
  void prepareAppFloating({Future<void> Function()? onClose, FacadeStreamCommit? session}) => floating.prepare();
  Future<void> showAppFloating({Widget Function(BuildContext)? danmakuBuilder}) =>
      floating.showAppFloating(danmakuBuilder: danmakuBuilder);
  Future<void> closeAppFloating() => floating.closeAppFloating();
  void prepareRoomSessionReentry([LiveRoom? room]) => floating.prepare();
  FacadeStreamCommit? consumeRoomSessionReentry([LiveRoom? room]) {
    final seed = floating.consumeRoomReentry();
    if (seed == null || room == null) return seed;
    return seed.room.roomId == room.roomId ? seed : null;
  }

  void cancelRoomSessionReentry() => floating.cancelRoomReentry();
  void setVideoPresentationVisible(bool visible) => setPresentationVisible(visible);

  Future<void> enablePip() async {
    _pipStateSub ??= windowsPipDriver.onPipChanged.listen((pip) {
      // The pip driver is the authority on whether the presentation is
      // active; without this bridge the room UI never learns the window
      // changed and keeps rendering the full room inside the shrunk frame.
      isInPip.value = pip;
    });
    isPipPreparing.value = true;
    try {
      // The kernel chain forwards requests without lifecycle calls. The
      // mobile path only installs its system-pip implementation and starts
      // observing the platform status stream during initialize(); without it
      // every pip request throws "no system pip implementation" and the
      // Android back gesture silently falls back to leaving the room.
      await windowsPipDriver.initialize();
      // Both platforms size the small window from the video's shape. Mobile
      // refuses to enter PiP at all without a positive size.
      final ratio = currentPresentationAspectRatio;
      windowsPipDriver.onVideoSize((ratio * 1000).round(), 1000);
      final driver = kernel.presentationDriver;
      if (driver != null) {
        await driver.apply(handle?.id ?? PlayerId('pure-live'), PresentationRequest.pip());
      }
    } finally {
      isPipPreparing.value = false;
    }
  }

  /// Leaves picture-in-picture and restores the window.
  Future<void> exitPip() async {
    final driver = kernel.presentationDriver;
    if (driver != null) {
      await driver.apply(handle?.id ?? PlayerId('pure-live'), PresentationRequest.normal());
    }
  }

  Widget buildPiPOverlay() => Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      // expand keeps MediaPlayerView off infinite constraints if this
      // Scaffold's body is ever composed inside a loose/unbounded ancestor.
      fit: StackFit.expand,
      children: [
        GestureDetector(
          // The video surface itself stays gesture-first: single tap toggles
          // playback, double tap leaves PiP, and a drag hands the pointer to
          // the native caption-drag loop — the compact window has no title
          // bar, so a surface-initiated drag is the only way to move it.
          onDoubleTap: () => unawaited(exitPip()),
          onTap: togglePlayPause,
          onPanStart: (_) => unawaited(windowsPipWindow.startDragging()),
          child: getVideoWidget(BoxFit.contain),
        ),
        if (_activeVideoController != null)
          Positioned.fill(child: CompactDanmakuOverlay(controller: _activeVideoController)),
        Positioned(
          left: 8,
          right: 8,
          top: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StreamBuilder<bool>(
                stream: onPlaying,
                initialData: isPlayingNow,
                builder: (context, snapshot) {
                  final isPlay = snapshot.data ?? true;
                  return _pipControlButton(
                    icon: isPlay ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    semanticLabel: isPlay ? '暂停' : '播放',
                    onTap: togglePlayPause,
                  );
                },
              ),
              const SizedBox(width: 6),
              _pipControlButton(icon: Icons.open_in_full, semanticLabel: '回到直播间', onTap: exitPip),
              const SizedBox(width: 6),
              _pipControlButton(
                icon: Icons.close,
                semanticLabel: '关闭',
                onTap: () async {
                  // Leaving the presentation first: closing playback alone
                  // would strand the window in its shrunk frameless state.
                  await exitPip();
                  await close();
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _pipControlButton({
    required IconData icon,
    required String semanticLabel,
    required Future<void> Function() onTap,
  }) {
    return IconButton(
      iconSize: 22,
      tooltip: semanticLabel,
      style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
      icon: Icon(icon),
      onPressed: () => unawaited(onTap()),
    );
  }

  double get currentPresentationAspectRatio {
    final size = handle?.combinedSnapshot.geometry.videoSize;
    if (size == null || size.width <= 0 || size.height <= 0) return 16 / 9;
    return size.width / size.height;
  }

  VideoSourceOrientation get effectiveVideoOrientation =>
      isVerticalVideo.value ? VideoSourceOrientation.portrait : VideoSourceOrientation.landscape;

  final Rx<VideoGeometrySnapshot> videoGeometryState = Rx<VideoGeometrySnapshot>(const VideoGeometrySnapshot.unknown());

  VideoGeometrySnapshot get videoGeometry => videoGeometryState.value;

  VideoGeometrySnapshot _computeVideoGeometry() {
    final size = handle?.combinedSnapshot.geometry.videoSize;
    if (size == null || size.width <= 0 || size.height <= 0) {
      return const VideoGeometrySnapshot.unknown();
    }
    final width = size.width.toInt();
    final height = size.height.toInt();
    final vertical = height > width;
    final orientation = vertical ? VideoOrientationKind.portrait : VideoOrientationKind.landscape;
    return VideoGeometrySnapshot(
      width: width,
      height: height,
      aspectRatio: width / height,
      orientation: orientation,
      candidateOrientation: orientation,
      stableSampleCount: 1,
      confidence: 1,
      observedAt: DateTime.now(),
    );
  }

  Duration get audioModeSwitchTimeout => const Duration(seconds: 5);

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
    final resolved = fit is int
        ? (fitList == null || fitList.isEmpty ? BoxFit.contain : fitList[fit.clamp(0, fitList.length - 1)])
        : fit as BoxFit;
    final video = getVideoWidget(resolved);
    if (controls == null) return video;
    // expand is load-bearing: a default (loose) Stack sizes itself to the
    // non-positioned child, and in an unbounded ancestor that hands the video
    // infinite constraints — MediaPlayerView's AspectRatio then throws
    // "BoxConstraints forces an infinite width and height" every frame and
    // the room shows nothing.
    return Stack(fit: StackFit.expand, children: [video, controls]);
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

@immutable
class FacadeStreamCommit {
  const FacadeStreamCommit({
    this.revision = 0,
    required this.room,
    List<String>? urls,
    String? currentUrl,
    this.currentLineIndex = 0,
    this.headers = const {},
    this.qualities = const [],
    this.currentQuality = 0,
    Object? source,
    Object? ownedSource,
    this.isAudioOnly = false,
    this.isLiving = true,
    this.dataSource = '',
    List<String>? playUrls,
    this.sourceQueryPolicies = const {},
    this.hasUseDefaultResolution = true,
  }) : urls = urls ?? playUrls ?? const [],
       currentUrl = currentUrl ?? dataSource,
       ownedSource = source ?? ownedSource;

  final int revision;
  final LiveRoom room;
  final List<String> urls;
  final String currentUrl;
  final int currentLineIndex;
  final Map<String, String> headers;
  final List<LivePlayQuality> qualities;
  final int currentQuality;
  final Object? ownedSource;
  List<String> get linesOrUrls => urls;
  final bool isAudioOnly;
  final bool isLiving;
  final String dataSource;
  final Map<String, Object?> sourceQueryPolicies;
  final bool hasUseDefaultResolution;

  FacadeStreamCommit copyWith({
    String? dataSource,
    List<String>? playUrls,
    Object? source,
    Object? ownedSource,
    Map<String, Object?>? sourceQueryPolicies,
    Map<String, String>? headers,
    bool? isAudioOnly,
  }) => FacadeStreamCommit(
    revision: revision,
    room: room,
    urls: playUrls ?? urls,
    currentUrl: dataSource ?? currentUrl,
    currentLineIndex: currentLineIndex,
    headers: headers ?? this.headers,
    qualities: qualities,
    currentQuality: currentQuality,
    ownedSource: source ?? ownedSource ?? this.ownedSource,
    isAudioOnly: isAudioOnly ?? this.isAudioOnly,
    isLiving: isLiving,
    dataSource: dataSource ?? this.dataSource,
    sourceQueryPolicies: sourceQueryPolicies ?? this.sourceQueryPolicies,
    hasUseDefaultResolution: hasUseDefaultResolution,
  );
}

typedef RoomSessionSnapshot = FacadeStreamCommit;
typedef PlaybackSourceCommitSnapshot = FacadeStreamCommit;
typedef PlaybackSourceResolver = Future<PlaybackSourceRefreshResult> Function(PlaybackSourceRefreshRequest request);

extension FacadeStreamCommitLegacy on FacadeStreamCommit {
  List<String> get playUrls => urls;
  Object? get source => null;
  String get currentUrl_ => currentUrl;
  Map<String, Object?> get queryPolicies => sourceQueryPolicies;
  PlaybackSourceQualitySelection? get selection =>
      qualities.isEmpty ? null : PlaybackSourceQualitySelection(qualities: qualities, currentQuality: currentQuality);
}

@immutable
class PlaybackSourceRefreshRequest {
  const PlaybackSourceRefreshRequest({
    required this.currentLineIndex,
    required this.advanceLine,
    required this.currentUrl,
    this.currentSource,
    this.currentQuality,
  });
  final int currentLineIndex;
  final bool advanceLine;
  final String? currentUrl;
  final Object? currentSource;
  final LivePlayQuality? currentQuality;
}

@immutable
class PlaybackSourceRefreshResult {
  const PlaybackSourceRefreshResult({
    required this.urls,
    required this.preferredLineIndex,
    this.refreshAt,
    this.invalidAt,
    this.selection,
  }) : ownedSource = null;

  const PlaybackSourceRefreshResult.owned({required Object? source, this.refreshAt, this.invalidAt, this.selection})
    : ownedSource = source,
      urls = const [],
      preferredLineIndex = 0;

  final Object? ownedSource;
  List<String> get linesOrUrls => urls;
  bool get hasSources => ownedSource != null || urls.isNotEmpty;
  final List<String> urls;
  final int preferredLineIndex;
  final DateTime? refreshAt;
  final DateTime? invalidAt;
  final PlaybackSourceQualitySelection? selection;
}

@immutable
class PlaybackSourceQualitySelection {
  const PlaybackSourceQualitySelection({
    required this.qualities,
    required this.currentQuality,
    this.sourceQueryPolicies = const {},
  });
  final List<LivePlayQuality> qualities;
  final int currentQuality;
  final Map<String, Object?> sourceQueryPolicies;
}
