import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_state.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/utils/live_buffer_policy.dart';
import 'package:pure_live/player/shaders/shader_asset_service.dart';
import 'package:pure_live/player/models/player_super_resolution.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/interface/media_kit_player_accessor.dart';

@visibleForTesting
({int width, int height})? resolveMediaKitDisplaySize(VideoParams params) {
  final size = resolveVideoParamsDisplaySize(params);

  return size == null ? null : (width: size.width, height: size.height);
}

class MediaKitAdapter implements UnifiedPlayer, MediaKitPlayerAccessor {
  MediaKitAdapter() {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyAudioOnly);
  }

  late final Player _player;

  late final VideoController _controller;

  bool _initialized = false;

  bool _disposed = false;

  bool _listenerBound = false;

  String? _currentUrl;

  bool _isAudioOnly = false;

  SuperResolutionMode _superResolutionMode = SuperResolutionMode.off;

  late final LatestAsyncValueQueue<bool> _audioModeTransitions;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);

  final _playingSubject = BehaviorSubject<bool>.seeded(false);

  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = PublishSubject<PlayerException>();

  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  final _widthSubject = BehaviorSubject<int?>.seeded(null);

  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  final _videoFrameProgressSubject = PublishSubject<int>();

  final List<StreamSubscription> _subscriptions = [];

  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _videoParamsSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _errorSub;

  // ---------------------------------------------------------------------------
  // Native configuration
  // ---------------------------------------------------------------------------

  static Future<void> applyNativeLiveProperties(NativePlayer native) async {
    await native.setProperty(
      'protocol_whitelist',
      'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto,'
          'rtmp,rtmps,rtsp,srt',
    );

    await native.setProperty('demuxer-lavf-probesize', '2097152');

    await native.setProperty('demuxer-max-bytes', LiveBufferPolicy.forwardBytes.toString());

    await native.setProperty('demuxer-readahead-secs', LiveBufferPolicy.readaheadSeconds.toString());

    await native.setProperty('network-timeout', '15');

    await native.setProperty('hwdec-software-fallback', '1');

    await native.setProperty('volume-max', '100');

    await native.setProperty('af', 'scaletempo2=max-speed=8');

    if (PlatformUtils.isAndroid) {
      await _configureAndroidNative(native);
    } else if (PlatformUtils.isIOS) {
      await _configureIOSNative(native);
    } else if (PlatformUtils.isMacOS) {
      await _configureMacOSNative(native);
    } else if (PlatformUtils.isWindows) {
      await _configureWindowsNative(native);
    } else if (PlatformUtils.isLinux) {
      await _configureLinuxNative(native);
    }
  }

  static Future<void> _configureAndroidNative(NativePlayer native) async {
    final settings = SettingsService.to.player;

    await native.setProperty('ao', settings.androidEnableOpenSLES.v ? 'opensles' : 'audiotrack');

    await native.setProperty('volume-max', '100');

    await native.setProperty('hwdec-software-fallback', '1');

    if (settings.playerCompatMode.v) {
      await native.setProperty('hwdec', 'mediacodec');

      await native.setProperty('vo', 'mediacodec_embed');

      return;
    }

    await native.setProperty('hwdec', settings.videoHardwareDecoder.v);

    final renderer = settings.videoOutputDriver.v;

    await native.setProperty('vo', renderer == 'auto' || renderer.isEmpty ? 'gpu' : renderer);
  }

  static Future<void> _configureIOSNative(NativePlayer native) async {
    await native.setProperty('hwdec', 'auto');

    await native.setProperty('hwdec-software-fallback', '1');
  }

  static Future<void> _configureMacOSNative(NativePlayer native) async {
    await native.setProperty('hwdec', 'no');

    await native.setProperty('vo', 'gpu');
  }

  static Future<void> _configureWindowsNative(NativePlayer native) async {
    final settings = SettingsService.to.player;

    await native.setProperty('vo', 'gpu');

    if (settings.enableRtxVsr.value) {
      await native.setProperty('hwdec', 'd3d11va');

      await native.setProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');

      return;
    }

    await native.setProperty('hwdec', settings.videoHardwareDecoder.v);
  }

  static Future<void> _configureLinuxNative(NativePlayer native) async {
    final settings = SettingsService.to.player;

    await native.setProperty('ao', 'alsa');

    await native.setProperty('vo', 'gpu');

    await native.setProperty('hwdec', settings.videoHardwareDecoder.v);
  }

  // ---------------------------------------------------------------------------
  // Super Resolution
  // ---------------------------------------------------------------------------

  /// 从设置中获取默认超分模式，并处理平台限制。
  SuperResolutionMode _resolveInitialSuperResolutionMode() {
    final settings = SettingsService.to.player;

    if (PlatformUtils.isIOS) {
      return SuperResolutionMode.off;
    }

    if (PlatformUtils.isAndroid && settings.playerCompatMode.v) {
      return SuperResolutionMode.off;
    }

    if (PlatformUtils.isWindows && settings.enableRtxVsr.value) {
      return SuperResolutionMode.off;
    }

    return SuperResolutionMode.fromStorageValue(settings.defaultSuperResolutionMode.v);
  }

  /// 根据当前模式获取 Shader。
  List<String> _getSuperResolutionShaders() {
    return switch (_superResolutionMode) {
      SuperResolutionMode.off => const <String>[],

      SuperResolutionMode.efficiency => PlayerConsts.mpvAnime4KShadersLiteKeys,

      SuperResolutionMode.quality => PlayerConsts.mpvAnime4KShaderKeys,
    };
  }

  /// 应用当前超分 Shader。
  Future<void> _configureSuperResolution() async {
    if (_disposed) {
      return;
    }

    if (_player.platform is! NativePlayer) {
      return;
    }

    final native = _player.platform as NativePlayer;

    await native.waitForPlayerInitialization;
    await native.waitForVideoControllerInitializationIfAttached;

    if (_disposed) {
      return;
    }

    final shaders = _getSuperResolutionShaders();

    await _applyShaderList(native, shaders);
  }

  Future<void> _applyShaderList(NativePlayer native, List<String> shaders) async {
    if (shaders.isEmpty) {
      await native.command(['change-list', 'glsl-shaders', 'clr', '']);

      return;
    }
    final String shaderCommand = FileUtils().buildShadersAbsolutePath(
      ShaderAssetService.instance.shadersDirectoryPath!,
      shaders,
    );

    await native.command(['change-list', 'glsl-shaders', 'set', shaderCommand]);
  }

  /// 动态切换超分模式。
  Future<void> setSuperResolution(SuperResolutionMode mode) async {
    if (_disposed) {
      return;
    }

    if (_player.platform is! NativePlayer) {
      return;
    }

    if (!_isSuperResolutionSupported()) {
      if (_superResolutionMode != SuperResolutionMode.off) {
        final oldMode = _superResolutionMode;

        _superResolutionMode = SuperResolutionMode.off;

        try {
          await _configureSuperResolution();
        } catch (_) {
          _superResolutionMode = oldMode;
        }
      }

      return;
    }

    final oldMode = _superResolutionMode;

    if (oldMode == mode) {
      return;
    }

    try {
      _superResolutionMode = mode;

      await _configureSuperResolution();

      Log.i(
        'MediaKitAdapter: super resolution changed '
        '${oldMode.name} -> ${mode.name}',
      );
    } catch (e, s) {
      _superResolutionMode = oldMode;

      Log.e('MediaKitAdapter: failed to set super resolution', s);

      // 尝试恢复旧 Shader。
      try {
        await _configureSuperResolution();
      } catch (restoreError, restoreStack) {
        Log.e(
          'MediaKitAdapter: failed to restore previous '
          'super resolution shader',
          restoreStack,
        );
      }

      rethrow;
    }
  }

  bool _isSuperResolutionSupported() {
    final settings = SettingsService.to.player;

    if (PlatformUtils.isIOS) {
      return false;
    }

    if (PlatformUtils.isAndroid && settings.playerCompatMode.v) {
      return false;
    }

    if (PlatformUtils.isWindows && settings.enableRtxVsr.value) {
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  @override
  Future<void> init({bool audioOnly = false}) async {
    if (_initialized) {
      return;
    }

    _disposed = false;
    _listenerBound = false;
    _currentUrl = null;
    _isAudioOnly = false;

    _superResolutionMode = _resolveInitialSuperResolutionMode();

    try {
      _stateSubject.add(PlayerState.initializing);

      MediaKit.ensureInitialized();

      final settings = SettingsService.to.player;

      _player = Player(configuration: const PlayerConfiguration(osc: false));

      if (_player.platform is NativePlayer) {
        final native = _player.platform as NativePlayer;

        await applyNativeLiveProperties(native);
      }

      // -----------------------------------------------------------------------
      // VideoController
      // -----------------------------------------------------------------------

      if (settings.playerCompatMode.v) {
        _superResolutionMode = SuperResolutionMode.off;

        _controller = VideoController(
          _player,
          configuration: const VideoControllerConfiguration(
            vo: 'mediacodec_embed',
            hwdec: 'mediacodec',
            enableHardwareAcceleration: true,
            enableAndroidSurfaceProducer: false,
            androidAttachSurfaceAfterVideoParameters: false,
          ),
        );
      } else if (settings.customPlayerOutput.v) {
        String? vo;

        if (PlatformUtils.isAndroid) {
          final renderer = settings.videoOutputDriver.v;

          vo = renderer == 'auto' || renderer.isEmpty ? 'gpu' : renderer;
        } else if (PlatformUtils.isWindows || PlatformUtils.isLinux || PlatformUtils.isMacOS) {
          vo = 'gpu';
        }

        String? hwdec;

        if (PlatformUtils.isMacOS) {
          hwdec = 'no';
        } else if (PlatformUtils.isIOS) {
          hwdec = 'auto';
        } else if (PlatformUtils.isWindows && settings.enableRtxVsr.value) {
          hwdec = 'd3d11va';
        } else {
          hwdec = settings.videoHardwareDecoder.v;
        }

        final enableHardwareAcceleration = PlatformUtils.isMacOS ? false : settings.enableCodec.v;

        _controller = VideoController(
          _player,
          configuration: VideoControllerConfiguration(
            vo: vo,
            hwdec: hwdec,
            enableHardwareAcceleration: enableHardwareAcceleration,
            enableAndroidSurfaceProducer: false,
            androidAttachSurfaceAfterVideoParameters: false,
          ),
        );
      } else {
        String? vo;
        String? hwdec;

        bool enableHardwareAcceleration = settings.enableCodec.v;

        if (PlatformUtils.isAndroid) {
          final renderer = settings.videoOutputDriver.v;

          vo = renderer == 'auto' || renderer.isEmpty ? 'gpu' : renderer;

          hwdec = settings.videoHardwareDecoder.v;
        } else if (PlatformUtils.isIOS) {
          vo = null;
          hwdec = 'auto';
        } else if (PlatformUtils.isMacOS) {
          vo = 'gpu';
          hwdec = 'no';
          enableHardwareAcceleration = false;
        } else if (PlatformUtils.isWindows) {
          vo = 'gpu';

          if (settings.enableRtxVsr.value) {
            hwdec = 'd3d11va';
          } else {
            hwdec = settings.videoHardwareDecoder.v;
          }
        } else if (PlatformUtils.isLinux) {
          vo = 'gpu';
          hwdec = settings.videoHardwareDecoder.v;
        }

        _controller = VideoController(
          _player,
          configuration: VideoControllerConfiguration(
            vo: vo,
            hwdec: hwdec,
            enableHardwareAcceleration: enableHardwareAcceleration,
            enableAndroidSurfaceProducer: false,
            androidAttachSurfaceAfterVideoParameters: false,
          ),
        );
      }

      await _bindListeners();

      if (_superResolutionMode != SuperResolutionMode.off) {
        await _configureSuperResolution();
      }

      await _player.setPlaylistMode(PlaylistMode.none);

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

  // ---------------------------------------------------------------------------
  // Data Source
  // ---------------------------------------------------------------------------

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    if (_disposed) {
      return;
    }

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

      if (_player.platform is NativePlayer) {
        final native = _player.platform as NativePlayer;

        final proxy = SettingsService.to.proxy;

        if (proxy.enableProxy.v && proxy.proxyHost.v.isNotEmpty) {
          final proxyUrl =
              'http://${proxy.proxyHost.v}:'
              '${proxy.proxyPort.v}';

          await native.setProperty('http-proxy', proxyUrl);
        }

        if (PlatformUtils.isWindows && SettingsService.to.player.enableRtxVsr.value) {
          await native.setProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');
        }

        await native.setProperty('vid', audioOnly ? 'no' : 'auto');
      }

      await _player.setAudioTrack(AudioTrack.auto());

      await _player.open(Media(url, httpHeaders: headers), play: true);

      if (PlatformUtils.isAndroid && !audioOnly) {
        _isAudioOnly = false;
      } else {
        await _applyAudioOnly(audioOnly, force: true);
      }

      // 继续使用当前 Adapter 的超分状态，
      // 不重新从 SettingsService 覆盖。
      if (_superResolutionMode != SuperResolutionMode.off) {
        await _configureSuperResolution();
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

  // ---------------------------------------------------------------------------
  // Listeners
  // ---------------------------------------------------------------------------

  Future<void> _bindListeners() async {
    if (_listenerBound) {
      return;
    }

    _listenerBound = true;

    await _cancelAllSubscriptions();

    _playingSub = _player.stream.playing.listen(
      (playing) {
        if (_disposed) {
          return;
        }

        _playingSubject.add(playing);

        if (!_loadingSubject.value) {
          _stateSubject.add(playing ? PlayerState.playing : PlayerState.paused);
        }
      },
      onError: (e, s) {
        Log.e(e, s);

        _emitError(e, s, PlayerErrorType.native);
      },
    );

    _bufferingSub = _player.stream.buffering.listen(
      (loading) {
        if (_disposed) {
          return;
        }

        _loadingSubject.add(loading);

        if (loading) {
          _stateSubject.add(PlayerState.buffering);
        } else {
          _stateSubject.add(_playingSubject.value ? PlayerState.playing : PlayerState.paused);
        }
      },
      onError: (e, s) {
        Log.e(e, s);

        _emitError(e, s, PlayerErrorType.native);
      },
    );

    _videoParamsSub = _player.stream.videoParams.listen(
      (params) {
        if (_disposed) {
          return;
        }

        final size = resolveMediaKitDisplaySize(params);

        _widthSubject.add(size?.width);
        _heightSubject.add(size?.height);
      },
      onError: (e, s) {
        Log.e(e, s);

        _emitError(e, s, PlayerErrorType.native);
      },
    );

    _completeSub = _player.stream.completed.listen(
      (completed) {
        if (_disposed || !completed) {
          return;
        }

        _completeSubject.add(true);

        _stateSubject.add(PlayerState.completed);
      },
      onError: (e, s) {
        Log.e(e, s);

        _emitError(e, s, PlayerErrorType.native);
      },
    );

    _errorSub = _player.stream.error.distinct().listen(
      (error) {
        if (_disposed) {
          return;
        }

        final type = _mapErrorType(error.toString());

        _safeAddError(PlayerException(message: error.toString(), type: type));

        _stateSubject.add(PlayerState.error);
      },
      onError: (e, s) {
        Log.e(e, s);

        _emitError(e, s, PlayerErrorType.native);
      },
    );

    _subscriptions.addAll([_playingSub!, _bufferingSub!, _videoParamsSub!, _completeSub!, _errorSub!]);
  }

  Future<void> _cancelAllSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }

    _subscriptions.clear();

    _playingSub = null;
    _bufferingSub = null;
    _videoParamsSub = null;
    _completeSub = null;
    _errorSub = null;
  }

  // ---------------------------------------------------------------------------
  // Error
  // ---------------------------------------------------------------------------

  void _emitError(Object error, StackTrace stackTrace, PlayerErrorType type) {
    if (_disposed) {
      return;
    }

    _safeAddError(PlayerException(message: error.toString(), type: type, error: error, stackTrace: stackTrace));

    _stateSubject.add(PlayerState.error);
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed || _errorSubject.isClosed) {
      return;
    }

    _errorSubject.add(exception);
  }

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

    Log.d(error);

    return PlayerErrorType.native;
  }

  // ---------------------------------------------------------------------------
  // Video
  // ---------------------------------------------------------------------------

  @override
  Widget getVideoWidget(BoxFit fit) {
    return StreamBuilder<List<int?>>(
      stream: CombineLatestStream.list<int?>([_widthSubject, _heightSubject]),
      builder: (context, snapshot) {
        final width = snapshot.data?[0];
        final height = snapshot.data?[1];

        double ratio = 16 / 9;

        if (width != null && height != null && width > 0 && height > 0) {
          ratio = width / height;
        }

        return Video(
          controller: _controller,
          controls: NoVideoControls,
          aspectRatio: ratio,
          fit: fit,
          pauseUponEnteringBackgroundMode: false,
          resumeUponEnteringForegroundMode: false,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

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

    _stateSubject.add(PlayerState.stopped);
  }

  @override
  Future<void> softStop() async {
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

  // ---------------------------------------------------------------------------
  // Audio Only
  // ---------------------------------------------------------------------------

  @override
  Future<void> setAudioOnly(bool audioOnly) {
    if (!_audioModeTransitions.isRunning && _isAudioOnly == audioOnly) {
      return Future<void>.value();
    }

    return _audioModeTransitions.submit(audioOnly);
  }

  Future<void> _applyAudioOnly(bool audioOnly, {bool force = false}) async {
    if (_disposed) {
      return;
    }

    if (!force && _isAudioOnly == audioOnly) {
      return;
    }

    try {
      if (PlatformUtils.isAndroid) {
        if (audioOnly) {
          await _controller.setVideoOutputEnabled(false);
        } else {
          await _restoreAndroidVideoOutput();
        }
      } else {
        await _player.setVideoTrack(audioOnly ? VideoTrack.no() : VideoTrack.auto());
      }

      _isAudioOnly = audioOnly;
    } catch (error, stackTrace) {
      throw PlayerException(
        message: 'MediaKit audio mode switch failed',
        type: PlayerErrorType.lifecycle,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _restoreAndroidVideoOutput() async {
    final frameReady = Completer<void>();

    var armed = false;

    final subscription = _player.stream.videoParams.listen((params) {
      final width = params.dw ?? params.w ?? 0;

      final height = params.dh ?? params.h ?? 0;

      if (armed && width > 0 && height > 0 && !frameReady.isCompleted) {
        frameReady.complete();
      }
    });

    try {
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
        await Future<void>.delayed(const Duration(milliseconds: 34));
      }
    } finally {
      await subscription.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Volume / Speed / Properties
  // ---------------------------------------------------------------------------

  @override
  Future<void> setVolume(double volume) async {
    final vol = (volume * 100).clamp(0.0, 100.0);

    await _player.setVolume(vol);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setRate(speed);
  }

  Future<void> setProperty(String property, String value) async {
    if (_disposed) {
      return;
    }

    if (_player.platform is! NativePlayer) {
      return;
    }

    final native = _player.platform as NativePlayer;

    await native.setProperty(property, value);
  }

  // ---------------------------------------------------------------------------
  // Prefetch
  // ---------------------------------------------------------------------------

  Future<void> setPrefetchSuspended(bool suspended) async {
    if (!PlatformUtils.isAndroid || _disposed) {
      return;
    }

    if (_player.platform is! NativePlayer) {
      return;
    }

    final native = _player.platform as NativePlayer;

    await native.setProperty('cache-secs', suspended ? '0' : '36000');

    await native.setProperty('demuxer-readahead-secs', suspended ? '0' : LiveBufferPolicy.readaheadSeconds.toString());
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  Future<void> hardDispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _initialized = false;
    _listenerBound = false;

    await _cancelAllSubscriptions();

    try {
      await _player.stop();
    } catch (_) {}

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
      _videoFrameProgressSubject.close(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _playingSubject.value;

  @override
  bool get isReusable => PlatformUtils.isWindows;

  /// 当前实际生效的超分模式。
  SuperResolutionMode get superResolutionMode => _superResolutionMode;

  @override
  Stream<PlayerState> get onStateChanged => _stateSubject.stream;

  @override
  Stream<bool> get onPlaying => _playingSubject.stream.distinct();

  @override
  Stream<PlayerException> get onError => _errorSubject.stream;

  @override
  Stream<bool> get onLoading => _loadingSubject.stream.distinct();

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
