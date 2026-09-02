import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_state.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/player/utils/playback_cache_policy.dart';
import 'package:pure_live/player/shaders/shader_asset_service.dart';
import 'package:pure_live/player/models/player_super_resolution.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/interface/media_kit_player_accessor.dart';

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

  late final PlaybackCachePolicy _cachePolicy;

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
  StreamSubscription? _completeSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _videoParamsSub;

  static Future<void> applyNativeLiveProperties(NativePlayer native) async {
    await native.setProperty('force-seekable', 'yes');

    await native.setProperty(
      'protocol_whitelist',
      'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto,rtmp,rtmps,rtsp,srt',
    );
    await native.setProperty("demuxer-cache-dir", await FileUtils().getTempPath());

    await native.setProperty('demuxer-lavf-probesize', '2097152');

    // Live FLV/HLS streams need a short probe rather than a long-file
    // analysis pass.  This reduces the black-screen interval before the
    // first decoded frame while retaining enough data for codec detection.
    await native.setProperty('demuxer-lavf-analyzeduration', '2');

    await native.setProperty('network-timeout', '15');

    await native.setProperty('hwdec-software-fallback', '1');

    await native.setProperty('volume-max', '100');
  }

  static Future<void> _configureAndroidCustomOutput(NativePlayer native) async {
    final settings = SettingsService.to.player;

    if (!settings.customPlayerOutput.v) {
      return;
    }

    if (PlatformUtils.isAndroid && settings.playerCompatMode.v) {
      return;
    }

    await native.setProperty(
      'ao',
      settings.androidEnableOpenSLES.v
          ? 'opensles'
          : settings.audioOutputDriver.v == 'auto'
          ? 'audiotrack'
          : settings.audioOutputDriver.v,
    );

    await native.setProperty('volume-max', '100');

    await native.setProperty('hwdec-software-fallback', '1');
  }

  static Future<void> _configureWindowsCustomOutput(NativePlayer native) async {
    final settings = SettingsService.to.player;

    if (!settings.customPlayerOutput.v) {
      return;
    }

    if (settings.enableRtxVsr.v) {
      await native.setProperty('vf', 'd3d11vpp=scale=2:scaling-mode=nvidia');
    }

    await native.setProperty('ao', settings.audioOutputDriver.v);
  }

  static Future<void> _configureMacOSCustomOutput(NativePlayer native) async {
    final settings = SettingsService.to.player;

    if (!settings.customPlayerOutput.v) {
      return;
    }
    await native.setProperty('ao', settings.audioOutputDriver.v);
  }

  static Future<void> _configureLinuxCustomOutput(NativePlayer native) async {
    final settings = SettingsService.to.player;

    if (!settings.customPlayerOutput.v) {
      return;
    }

    await native.setProperty('ao', settings.audioOutputDriver.v);
  }

  SuperResolutionMode _resolveInitialSuperResolutionMode() {
    final settings = SettingsService.to.player;

    if (!settings.customPlayerOutput.v) {
      return SuperResolutionMode.off;
    }

    if (PlatformUtils.isAndroid && settings.playerCompatMode.v) {
      return SuperResolutionMode.off;
    }

    if (PlatformUtils.isIOS) {
      return SuperResolutionMode.off;
    }

    if (PlatformUtils.isWindows && settings.enableRtxVsr.v) {
      return SuperResolutionMode.off;
    }

    return SuperResolutionMode.fromStorageValue(settings.defaultSuperResolutionMode.v);
  }

  List<String> _getSuperResolutionShaders() {
    return switch (_superResolutionMode) {
      SuperResolutionMode.off => const <String>[],
      SuperResolutionMode.efficiency => PlayerConsts.mpvAnime4KShadersLiteKeys,
      SuperResolutionMode.quality => PlayerConsts.mpvAnime4KShaderKeys,
    };
  }

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

    final shaderCommand = FileUtils().buildShadersAbsolutePath(
      ShaderAssetService.instance.shadersDirectoryPath!,
      shaders,
    );

    await native.command(['change-list', 'glsl-shaders', 'set', shaderCommand]);
  }

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

    if (!settings.customPlayerOutput.v) {
      return false;
    }

    if (PlatformUtils.isAndroid && settings.playerCompatMode.v) {
      return false;
    }

    if (PlatformUtils.isIOS) {
      return false;
    }

    if (PlatformUtils.isWindows && settings.enableRtxVsr.v) {
      return false;
    }

    return true;
  }

  Future<VideoControllerConfiguration> _buildVideoControllerConfiguration() async {
    final settings = SettingsService.to.player;
    final customOutput = settings.customPlayerOutput.v;
    if (!customOutput) {
      _superResolutionMode = SuperResolutionMode.off;

      return VideoControllerConfiguration(enableHardwareAcceleration: settings.enableCodec.v);
    }
    if (PlatformUtils.isAndroid && settings.playerCompatMode.v) {
      _superResolutionMode = SuperResolutionMode.off;

      return const VideoControllerConfiguration(
        vo: 'mediacodec_embed',
        hwdec: 'mediacodec',
        enableHardwareAcceleration: true,
        enableAndroidSurfaceProducer: false,
        androidAttachSurfaceAfterVideoParameters: false,
      );
    }

    String? vo;
    String? hwdec;
    if (PlatformUtils.isAndroid) {
      final renderer = settings.videoOutputDriver.v.isEmpty || settings.videoOutputDriver.v == 'auto'
          ? 'gpu'
          : settings.videoOutputDriver.v;

      if (renderer.isEmpty || renderer == 'auto') {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        vo = androidInfo.version.sdkInt >= 34 ? 'gpu-next' : 'gpu';
      } else {
        vo = renderer;
      }

      hwdec = settings.videoHardwareDecoder.v;
    } else if (PlatformUtils.isWindows) {
      final driver = settings.videoOutputDriver.v;

      if (driver.isNotEmpty && driver != 'auto') {
        vo = driver;
      }

      hwdec = settings.enableRtxVsr.v ? 'd3d11va' : settings.videoHardwareDecoder.v;
    } else if (PlatformUtils.isLinux) {
      final driver = settings.videoOutputDriver.v;
      if (driver.isNotEmpty && driver != 'auto') {
        vo = driver;
      }
      hwdec = settings.videoHardwareDecoder.v;
    } else if (PlatformUtils.isMacOS) {
      final driver = settings.videoOutputDriver.v;

      if (driver.isNotEmpty && driver != 'auto') {
        vo = driver;
      }

      hwdec = settings.videoHardwareDecoder.v;
    } else if (PlatformUtils.isIOS) {
      final driver = settings.videoOutputDriver.v;
      if (driver.isNotEmpty && driver != 'auto') {
        vo = driver;
      }
      hwdec = settings.videoHardwareDecoder.v;
    }

    final enableHardwareAcceleration = settings.enableCodec.v;
    Log.i(
      'MediaKit VideoOutput: '
      'videoOutputDriver=${settings.videoOutputDriver.v}, '
      'vo=$vo, '
      'enableRtxVsr=${settings.enableRtxVsr.v}, '
      'videoHardwareDecoder=${settings.videoHardwareDecoder.v}',
    );
    return VideoControllerConfiguration(vo: vo, hwdec: hwdec, enableHardwareAcceleration: enableHardwareAcceleration);
  }

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
      _cachePolicy = PlaybackCachePolicy(isLocalPlayback: () => false, currentPlayer: () => _player);
      final settings = SettingsService.to.player;

      _player = Player(configuration: const PlayerConfiguration(osc: false));

      if (_player.platform is NativePlayer) {
        final native = _player.platform as NativePlayer;

        await applyNativeLiveProperties(native);
        _cachePolicy.startWatching();
        await _cachePolicy.apply();
        if (settings.customPlayerOutput.v) {
          if (PlatformUtils.isAndroid) {
            if (!settings.playerCompatMode.v) {
              await _configureAndroidCustomOutput(native);
            }
          } else if (PlatformUtils.isWindows) {
            await _configureWindowsCustomOutput(native);
          } else if (PlatformUtils.isMacOS) {
            await _configureMacOSCustomOutput(native);
          } else if (PlatformUtils.isLinux) {
            await _configureLinuxCustomOutput(native);
          }
        }
      }

      _controller = VideoController(_player, configuration: await _buildVideoControllerConfiguration());

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
          final proxyUrl = 'http://${proxy.proxyHost.v}:${proxy.proxyPort.v}';

          await native.setProperty('http-proxy', proxyUrl);
        }

        await native.setProperty('vid', audioOnly ? 'no' : 'auto');
      }

      await _player.setAudioTrack(AudioTrack.auto());

      final urls = <String>[url, ...playUrls.where((item) => item.isNotEmpty && item != url)];

      final playlist = Playlist(urls.map((item) => Media(item, httpHeaders: headers)).toList());

      await _player.open(playlist, play: true);

      if (PlatformUtils.isAndroid && !audioOnly) {
        _isAudioOnly = false;
      } else {
        await _applyAudioOnly(audioOnly, force: true);
      }
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

    _videoParamsSub = _player.stream.videoParams.listen((params) {
      if (_disposed) return;
      final width = params.dw ?? params.w;
      final height = params.dh ?? params.h;

      if (width != null && width > 0) {
        _widthSubject.add(width);
      }

      if (height != null && height > 0) {
        _heightSubject.add(height);
      }
    });

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

    _subscriptions.addAll([_playingSub!, _bufferingSub!, _completeSub!, _errorSub!, _videoParamsSub!]);
  }

  Future<void> _cancelAllSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }

    _subscriptions.clear();

    _playingSub = null;
    _bufferingSub = null;
    _completeSub = null;
    _errorSub = null;
    _videoParamsSub = null;
  }

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
          await _player.setVideoTrack(VideoTrack.no());
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

      await _player.setVideoTrack(VideoTrack.auto());

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

  Future<void> setPrefetchSuspended(bool suspended) async {
    if (_disposed) {
      return;
    }

    _cachePolicy.setPrefetchSuspended(suspended);
  }

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

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _playingSubject.value;

  @override
  bool get isReusable => PlatformUtils.isWindows;

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
