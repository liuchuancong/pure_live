import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/player_state.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';

import 'package:pure_live/common/index.dart';

import '../interface/unified_player_interface.dart';

import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/utils/live_buffer_policy.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/player/utils/video_output_size_policy.dart';
import 'package:pure_live/player/interface/media_kit_player_accessor.dart';

class MediaKitAdapter implements UnifiedPlayer, MediaKitPlayerAccessor, VideoFitAwarePlayer {
  MediaKitAdapter() {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyAudioOnly);
  }

  /// Applies the shared low-latency live-stream mpv property set to a native
  /// (libmpv) player platform.
  ///
  /// 单一事实来源：主播放器（[MediaKitAdapter.init]）与 multiview 每格播放器
  /// 都必须使用同一套属性（seek 白名单、探测时长、LiveBufferPolicy 缓冲上限、
  /// 网络超时、音频驱动、代理、macOS 硬解关闭），避免两处配置漂移。
  static Future<void> applyNativeLiveProperties(dynamic native) async {
    await native.setProperty('force-seekable', 'yes');

    await native.setProperty('protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto');

    await native.setProperty('demuxer-lavf-probesize', '2097152');

    // Live FLV/HLS streams need a short probe rather than a long-file
    // analysis pass.  This reduces the black-screen interval before the
    // first decoded frame while retaining enough data for codec detection.
    await native.setProperty('demuxer-lavf-analyzeduration', '2');

    // mpv's generic defaults keep a large seek-oriented forward/backward
    // cache. Live rooms are not meaningfully seekable, so retaining that
    // much compressed data only makes long Windows/Android sessions appear
    // to grow indefinitely. Keep this shared with the tested policy rather
    // than scattering raw byte strings through the adapter.
    await native.setProperty('demuxer-max-bytes', LiveBufferPolicy.forwardBytes.toString());

    await native.setProperty('demuxer-max-back-bytes', LiveBufferPolicy.backBytes.toString());

    await native.setProperty('demuxer-readahead-secs', LiveBufferPolicy.readaheadSeconds.toString());

    await native.setProperty('network-timeout', '15');

    if (SettingsService.to.player.customPlayerOutput.v) {
      await native.setProperty('ao', SettingsService.to.player.audioOutputDriver.v);
    } else if (PlatformUtils.isLinux) {
      await native.setProperty('ao', 'alsa');
    }

    if (SettingsService.to.proxy.enableProxy.v && SettingsService.to.proxy.proxyHost.v.isNotEmpty) {
      final proxyUrl = "http://${SettingsService.to.proxy.proxyHost.v}:${SettingsService.to.proxy.proxyPort.v}";

      await native.setProperty('http-proxy', proxyUrl);
    }

    if (PlatformUtils.isMacOS) {
      await native.setProperty('hwdec', 'no');
    }

    if (PlatformUtils.isWindows && SettingsService.to.player.enableRtxVsr.value) {
      await native.setProperty('hwdec', 'd3d11va');
      await native.setProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');
    }
  }

  late final Player _player;

  late final VideoController _controller;

  bool _initialized = false;

  bool _disposed = false;

  bool _listenerBound = false;

  String? _currentUrl;

  bool _isAudioOnly = false;

  BoxFit _videoFit = BoxFit.contain;

  late final LatestAsyncValueQueue<bool> _audioModeTransitions;

  // =========================
  // subjects
  // =========================

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);

  final _playingSubject = BehaviorSubject<bool>.seeded(false);

  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = PublishSubject<PlayerException>();

  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  final _widthSubject = BehaviorSubject<int?>.seeded(null);

  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  // =========================
  // subscriptions
  // =========================

  final List<StreamSubscription> _subscriptions = [];

  StreamSubscription? _playingSub;

  StreamSubscription? _bufferingSub;

  StreamSubscription? _widthSub;

  StreamSubscription? _heightSub;

  StreamSubscription? _completeSub;

  StreamSubscription? _errorSub;

  // =========================
  // init
  // =========================

  @override
  Future<void> init({bool audioOnly = false}) async {
    if (_initialized) return;
    // Always create a normal video output. Audio-only is a reversible track
    // selection on the same player; constructing a `vo=null` controller made
    // returning to video depend on destroying and recreating the native player.
    _disposed = false;

    // This is application presentation state. On Android the attached
    // media_kit VideoController is the sole owner of mpv's `vid` property.
    _isAudioOnly = false;

    _listenerBound = false;

    _currentUrl = null;

    try {
      _stateSubject.add(PlayerState.initializing);

      MediaKit.ensureInitialized();
      _player = Player();

      if (_player.platform is NativePlayer) {
        final native = _player.platform as dynamic;
        // Live adapters use one explicit seekability override. The upstream
        // Android workaround duplicated this native property write.
        await applyNativeLiveProperties(native);
      }

      // =========================
      // controller
      // =========================
      _controller = SettingsService.to.player.playerCompatMode.v
          ? VideoController(
              _player,
              configuration: const VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec'),
            )
          : SettingsService.to.player.customPlayerOutput.v
          ? VideoController(
              _player,
              configuration: VideoControllerConfiguration(
                vo: SettingsService.to.player.videoOutputDriver.v,
                hwdec: PlatformUtils.isMacOS ? 'no' : SettingsService.to.player.videoHardwareDecoder.v,
                enableHardwareAcceleration: !PlatformUtils.isMacOS,
              ),
            )
          : VideoController(
              _player,
              configuration: VideoControllerConfiguration(
                enableHardwareAcceleration: PlatformUtils.isMacOS ? false : SettingsService.to.player.enableCodec.v,
                hwdec: PlatformUtils.isMacOS ? 'no' : null,
                androidAttachSurfaceAfterVideoParameters: false,
              ),
            );

      await _bindListeners();

      _initialized = true;

      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'MediaKit init failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );

      _safeAddError(exception);

      throw exception;
    }
  }

  // =========================
  // datasource
  // =========================

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    if (_disposed) return;

    if (_currentUrl == url && isPlayingNow) {
      return;
    }
    _currentUrl = url;

    try {
      _loadingSubject.add(true);

      _stateSubject.add(PlayerState.preparing);

      _completeSubject.add(false);

      _widthSubject.add(null);

      _heightSubject.add(null);

      await _player.open(Media(url, httpHeaders: headers), play: true);

      // mpv opens a normal Android source with `vid=auto`, and the Surface
      // controller already owns that same initial state. Reissuing an async
      // `vid=auto` command here can stay pending after the first frame is
      // visible; the room controller's initialization Future then never
      // completes and the first headphone tap waits on a stream that is already
      // playing. Audio-only still needs an explicit post-open selection.
      if (PlatformUtils.isAndroid && !audioOnly) {
        _isAudioOnly = false;
      } else {
        await _applyAudioOnly(audioOnly, force: true);
      }

      _stateSubject.add(PlayerState.ready);

      if (PlatformUtils.isMobile) {
        await setVolume(1.0);
      } else {
        final targetVolume = room?.getSavedVolume() ?? 1.0;
        await setVolume(targetVolume);
      }
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Media open failed',
        type: PlayerErrorType.source,
        error: e,
        stackTrace: s,
      );

      _safeAddError(exception);

      _stateSubject.add(PlayerState.error);

      throw exception;
    } finally {
      if (!_disposed) {
        _loadingSubject.add(false);
      }
    }
  }

  // =========================
  // listeners
  // =========================

  Future<void> _bindListeners() async {
    if (_listenerBound) return;

    _listenerBound = true;

    await _cancelAllSubscriptions();

    // =========================
    // playing
    // =========================

    _playingSub = _player.stream.playing.listen(
      (playing) {
        if (_disposed) return;

        _playingSubject.add(playing);

        if (!_loadingSubject.value) {
          _stateSubject.add(playing ? PlayerState.playing : PlayerState.paused);
        }
      },
      onError: (e, s) {
        _emitError(e, s, PlayerErrorType.native);
      },
    );

    // =========================
    // buffering
    // =========================

    _bufferingSub = _player.stream.buffering.listen(
      (loading) {
        if (_disposed) return;

        _loadingSubject.add(loading);

        if (loading) {
          _stateSubject.add(PlayerState.buffering);
        } else {
          _stateSubject.add(_playingSubject.value ? PlayerState.playing : PlayerState.paused);
        }
      },
      onError: (e, s) {
        _emitError(e, s, PlayerErrorType.native);
      },
    );

    // =========================
    // width
    // =========================

    _widthSub = _player.stream.width.listen((val) {
      if (_disposed) return;

      _widthSubject.add(val);
    });

    // =========================
    // height
    // =========================

    _heightSub = _player.stream.height.listen((val) {
      if (_disposed) return;

      _heightSubject.add(val);
    });

    // =========================
    // completed
    // =========================

    _completeSub = _player.stream.completed.listen(
      (completed) {
        if (_disposed) return;

        if (!completed) return;

        _completeSubject.add(true);

        _stateSubject.add(PlayerState.completed);
      },
      onError: (e, s) {
        _emitError(e, s, PlayerErrorType.native);
      },
    );

    // =========================
    // error
    // =========================

    _errorSub = _player.stream.error.distinct().listen((error) {
      if (_disposed) return;

      final type = _mapErrorType(error.toString());

      _safeAddError(PlayerException(message: error.toString(), type: type));

      _stateSubject.add(PlayerState.error);
    });

    // =========================
    // collect
    // =========================

    _subscriptions.addAll([_playingSub!, _bufferingSub!, _widthSub!, _heightSub!, _completeSub!, _errorSub!]);
  }

  // =========================
  // cancel subscriptions
  // =========================

  Future<void> _cancelAllSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }

    _subscriptions.clear();

    _playingSub = null;
    _bufferingSub = null;
    _widthSub = null;
    _heightSub = null;
    _completeSub = null;
    _errorSub = null;
  }

  // =========================
  // emit error
  // =========================

  void _emitError(Object error, StackTrace stackTrace, PlayerErrorType type) {
    if (_disposed) return;

    _safeAddError(PlayerException(message: error.toString(), type: type, error: error, stackTrace: stackTrace));

    _stateSubject.add(PlayerState.error);
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed) return;

    if (_errorSubject.isClosed) return;

    _errorSubject.add(exception);
  }

  // =========================
  // error type
  // =========================

  PlayerErrorType _mapErrorType(String error) {
    final lower = error.toLowerCase();

    if (lower.contains('network') || lower.contains('timeout') || lower.contains('io')) {
      return PlayerErrorType.network;
    }

    if (lower.contains('codec') || lower.contains('mediacodec') || lower.contains('decode')) {
      return PlayerErrorType.codec;
    }

    if (lower.contains('404') || lower.contains('source') || lower.contains('open')) {
      return PlayerErrorType.source;
    }

    if (lower.contains('surface') || lower.contains('texture')) {
      return PlayerErrorType.texture;
    }

    return PlayerErrorType.native;
  }

  // =========================
  // widget
  // =========================

  @override
  Widget getVideoWidget() {
    final video = Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: _videoFit,
      // LivePlay's WidgetsBindingObserver is the single lifecycle authority.
      // Letting Video apply a second, settings-only policy paused audio-only
      // rooms on Home/lock even though the background policy kept them alive.
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    );
    if (!PlatformUtils.isWindows) return video;
    return _WindowsViewportSizedVideo(
      controller: _controller,
      sourceWidth: _widthSubject,
      sourceHeight: _heightSubject,
      child: video,
    );
  }

  @override
  void setVideoFit(BoxFit fit) {
    _videoFit = fit;
  }

  // =========================
  // play
  // =========================

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.pause();

    await _player.seek(Duration.zero);

    _stateSubject.add(PlayerState.stopped);
  }

  @override
  Future<void> softStop() async {
    // Pausing a live source keeps its demuxer, decoder, audio track and network
    // buffers alive. That left the home/settings UI competing with an invisible
    // room for CPU and hundreds of MiB after navigation. Unload the current
    // media while retaining the native Player object for a fast next open.
    await _player.setVolume(0.0);
    await _player.stop();
    _currentUrl = null;
    _isAudioOnly = false;
    _playingSubject.add(false);
    _loadingSubject.add(false);
    _widthSubject.add(null);
    _heightSubject.add(null);
    _stateSubject.add(PlayerState.stopped);
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) {
    if (!_audioModeTransitions.isRunning && _isAudioOnly == audioOnly) {
      return Future<void>.value();
    }
    return _audioModeTransitions.submit(audioOnly);
  }

  Future<void> _applyAudioOnly(bool audioOnly, {bool force = false}) async {
    if (_disposed) return;
    if (!force && _isAudioOnly == audioOnly) return;

    try {
      if (PlatformUtils.isAndroid) {
        // Android's patched video controller serializes `vid` with WID/Surface
        // updates. Disabling decode here saves battery during long ASMR sessions
        // while retaining the same player, demuxer and network connection.
        if (audioOnly) {
          await _controller.setVideoOutputEnabled(false);
        } else {
          await _restoreAndroidVideoOutput();
        }
      } else {
        // Desktop video outputs do not rewrite `vid` while their surface is
        // resized, so changing the decoded track is safe and saves resources.
        final track = audioOnly ? VideoTrack.no() : VideoTrack.auto();
        await _player.setVideoTrack(track);
      }

      _isAudioOnly = audioOnly;
      if (_disposed) return;
    } catch (error, stackTrace) {
      throw PlayerException(
        message: 'MediaKit audio mode switch failed',
        type: PlayerErrorType.lifecycle,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Enables Android video and waits for mpv to publish fresh decoded-video
  /// parameters before the room removes its audio presentation. This is an
  /// adaptive keyframe fence rather than an arbitrary fixed delay: fast streams
  /// reveal immediately, while a slow GOP remains covered by the room artwork
  /// instead of showing a black texture.
  Future<void> _restoreAndroidVideoOutput() async {
    final frameReady = Completer<void>();
    var armed = false;
    final stopwatch = Stopwatch()..start();
    final subscription = _player.stream.videoParams.listen((params) {
      final width = params.dw ?? params.w ?? 0;
      final height = params.dh ?? params.h ?? 0;
      if (armed && width > 0 && height > 0 && !frameReady.isCompleted) {
        frameReady.complete();
      }
    });

    try {
      // The stream is broadcast, but arm after attaching the listener so a
      // stale cached state can never be mistaken for the next decoded frame.
      armed = true;
      await _controller.setVideoOutputEnabled(true);

      var observedFreshFrame = true;
      await frameReady.future.timeout(
        const Duration(milliseconds: 2800),
        onTimeout: () {
          observedFreshFrame = false;
        },
      );
      if (observedFreshFrame) {
        // video-params precedes texture composition by a very small interval.
        // Two display frames keep the cover in place until the GPU texture has
        // had a chance to present without adding a user-visible fixed pause.
        await Future<void>.delayed(const Duration(milliseconds: 34));
      } else {
        debugPrint(
          'MediaKitAdapter: video restore readiness timed out after '
          '${stopwatch.elapsedMilliseconds} ms; revealing the live texture',
        );
      }
    } finally {
      stopwatch.stop();
      await subscription.cancel();
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    final vol = (volume * 100).clamp(0.0, 100.0);

    await _player.setVolume(vol);
  }

  // =========================
  // dispose
  // =========================

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;

    _disposed = true;

    _initialized = false;

    _listenerBound = false;

    await _cancelAllSubscriptions();

    try {
      await _player.stop();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await _player.dispose();
    } catch (_) {}

    await Future.wait([
      _stateSubject.close(),
      _playingSubject.close(),
      _loadingSubject.close(),
      _errorSubject.close(),
      _completeSubject.close(),
      _widthSubject.close(),
      _heightSubject.close(),
    ]);
  }

  // =========================
  // getter
  // =========================

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _playingSubject.value;

  @override
  bool get isReusable => false;

  @override
  Stream<PlayerState> get onStateChanged => _stateSubject.stream;

  @override
  Stream<bool> get onPlaying => _playingSubject.stream;

  @override
  Stream<PlayerException> get onError => _errorSubject.stream;

  @override
  Stream<bool> get onLoading => _loadingSubject.stream;

  @override
  Stream<bool> get onComplete => _completeSubject.stream;

  @override
  Stream<int?> get width => _widthSubject.stream;

  @override
  Stream<int?> get height => _heightSubject.stream;

  @override
  PlayerEngine get engine => PlayerEngine.mediaKit;

  @override
  Player get mediaKitPlayer => _player;

  @override
  VideoController get mediaKitVideoController => _controller;
}

/// Keeps the Windows BGRA texture close to the visible physical viewport.
/// Resizing is debounced so dragging a window does not recreate the texture on
/// every pointer event.
class _WindowsViewportSizedVideo extends StatefulWidget {
  const _WindowsViewportSizedVideo({
    required this.controller,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.child,
  });

  final VideoController controller;
  final Stream<int?> sourceWidth;
  final Stream<int?> sourceHeight;
  final Widget child;

  @override
  State<_WindowsViewportSizedVideo> createState() => _WindowsViewportSizedVideoState();
}

class _WindowsViewportSizedVideoState extends State<_WindowsViewportSizedVideo> {
  static const _resizeDebounce = Duration(milliseconds: 180);

  StreamSubscription<int?>? _widthSubscription;
  StreamSubscription<int?>? _heightSubscription;
  Timer? _resizeTimer;
  int? _sourceWidth;
  int? _sourceHeight;
  Size? _logicalViewport;
  double _devicePixelRatio = 1;
  Size? _requestedSize;

  @override
  void initState() {
    super.initState();
    _bindSourceDimensions();
  }

  @override
  void didUpdateWidget(covariant _WindowsViewportSizedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sourceWidth, widget.sourceWidth) ||
        !identical(oldWidget.sourceHeight, widget.sourceHeight)) {
      unawaited(_cancelSourceSubscriptions());
      _bindSourceDimensions();
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      _requestedSize = null;
      _scheduleResize();
    }
  }

  void _bindSourceDimensions() {
    _widthSubscription = widget.sourceWidth.distinct().listen((value) {
      _sourceWidth = value;
      _scheduleResize();
    });
    _heightSubscription = widget.sourceHeight.distinct().listen((value) {
      _sourceHeight = value;
      _scheduleResize();
    });
  }

  Future<void> _cancelSourceSubscriptions() async {
    // Capture before awaiting. didUpdateWidget immediately binds the new
    // streams; reading the fields again after the first await could cancel the
    // replacement height subscription and drop the replacement width handle.
    final widthSubscription = _widthSubscription;
    final heightSubscription = _heightSubscription;
    _widthSubscription = null;
    _heightSubscription = null;
    await Future.wait<void>([
      if (widthSubscription != null) widthSubscription.cancel(),
      if (heightSubscription != null) heightSubscription.cancel(),
    ]);
  }

  void _scheduleResize() {
    final viewport = _logicalViewport;
    if (viewport == null) return;
    final target = calculateVideoOutputSize(
      logicalViewport: viewport,
      devicePixelRatio: _devicePixelRatio,
      sourceWidth: _sourceWidth,
      sourceHeight: _sourceHeight,
    );
    if (target.isEmpty || target == _requestedSize) return;

    _resizeTimer?.cancel();
    _resizeTimer = Timer(_resizeDebounce, () async {
      if (!mounted) return;
      _requestedSize = target;
      try {
        await widget.controller.setSize(width: target.width.toInt(), height: target.height.toInt());
      } catch (_) {
        // The controller can be disposed while a room/window transition is
        // completing. The next mounted video session will publish its size.
      }
    });
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    unawaited(_cancelSourceSubscriptions());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        if (_logicalViewport != viewport || _devicePixelRatio != pixelRatio) {
          _logicalViewport = viewport;
          _devicePixelRatio = pixelRatio;
          _scheduleResize();
        }
        return widget.child;
      },
    );
  }
}
