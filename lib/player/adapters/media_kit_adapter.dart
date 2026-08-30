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
import 'package:pure_live/player/core/player_error_classifier.dart';
import 'package:pure_live/player/core/source_event_fence.dart';

@visibleForTesting
({int width, int height})? resolveMediaKitDisplaySize(VideoParams params) {
  final size = resolveVideoParamsDisplaySize(params);
  return size == null ? null : (width: size.width, height: size.height);
}

@visibleForTesting
bool shouldPublishMediaKitPlaying(bool nativePlaying) => nativePlaying;

class MediaKitAdapter
    implements
        UnifiedPlayer,
        MediaKitPlayerAccessor,
        VideoFitAwarePlayer,
        SourceTransitionAwarePlayer,
        DecoderRecoveryAwarePlayer,
        VideoFrameProgressAwarePlayer {
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

    await native.setProperty(
      'protocol_whitelist',
      'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto,rtmp,rtmps,rtsp,srt',
    );

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

    // Ask mpv to abandon a broken hardware decoder after the first consecutive
    // frame failure. This preserves the low-power fast path on compatible
    // devices while making unsupported profiles fall back to software instead
    // of leaving a black Surface behind. mpv's larger default can skip several
    // live packets before the fallback is attempted.
    await native.setProperty('hwdec-software-fallback', '1');

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

  bool _nativePathObserved = false;

  bool _nativeFramePropertiesObserved = false;

  bool _usesNativeFrameProbe = false;

  String? _currentUrl;

  bool _isAudioOnly = false;

  final SourceEventFence _sourceFence = SourceEventFence();

  bool _sourceTransitionPrepared = false;

  bool _sourceHasVideoFrame = false;

  bool _sourceHasAudioFrame = false;

  String _preferredHardwareDecoder = 'no';

  String? _softwareDecoderFallbackUrl;

  int _sourceProgressRevision = 0;

  Timer? _pendingNativeErrorTimer;

  _NativeDiagnostic? _openingNativeDiagnostic;

  PlayerException? _pendingNativeError;

  int? _pendingNativeErrorGeneration;

  int _pendingNativeErrorProgressRevision = 0;

  NativeDiagnosticComponent _pendingNativeErrorComponent = NativeDiagnosticComponent.either;

  String? _lastEmittedNativeError;

  DateTime? _lastEmittedNativeErrorAt;

  int? _lastEmittedNativeErrorGeneration;

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

  final _videoFrameProgressSubject = PublishSubject<int>();

  VoidCallback? _videoFrameRevisionListener;

  // =========================
  // subscriptions
  // =========================

  final List<StreamSubscription> _subscriptions = [];

  StreamSubscription? _playingSub;

  StreamSubscription? _bufferingSub;

  StreamSubscription? _videoParamsSub;

  StreamSubscription? _audioParamsSub;

  StreamSubscription? _completeSub;

  StreamSubscription? _errorSub;

  StreamSubscription? _logSub;

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
      _preferredHardwareDecoder = PlatformUtils.isMacOS
          ? 'no'
          : SettingsService.to.player.playerCompatMode.v
          ? 'mediacodec'
          : SettingsService.to.player.customPlayerOutput.v
          ? SettingsService.to.player.videoHardwareDecoder.v
          : SettingsService.to.player.enableCodec.v
          ? 'auto-safe'
          : 'no';

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

      if (PlatformUtils.isWindows) {
        var lastRevision = _controller.frameRevision.value;
        void handleFrameRevision() {
          if (_disposed) return;
          final revision = _controller.frameRevision.value;
          if (revision == lastRevision) return;
          lastRevision = revision;
          _videoFrameProgressSubject.add(revision);
        }

        _videoFrameRevisionListener = handleFrameRevision;
        _controller.frameRevision.addListener(handleFrameRevision);
      }

      await _bindListeners(sourceGeneration: _sourceFence.generation);

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
  void beginSourceTransition() {
    if (_disposed) return;
    _prepareSourceTransition();
    _sourceTransitionPrepared = true;
  }

  void _prepareSourceTransition({String? url}) {
    _pendingNativeErrorTimer?.cancel();
    _pendingNativeErrorTimer = null;
    _pendingNativeError = null;
    _pendingNativeErrorGeneration = null;
    _pendingNativeErrorComponent = NativeDiagnosticComponent.either;
    _openingNativeDiagnostic = null;
    _sourceHasVideoFrame = false;
    _sourceHasAudioFrame = false;
    _sourceProgressRevision = 0;
    _sourceFence.begin(url ?? _currentUrl);
    _playingSubject.add(false);
    _loadingSubject.add(true);
    _completeSubject.add(false);
    _widthSubject.add(null);
    _heightSubject.add(null);
  }

  Future<List<String>> _currentNativeSourcePaths() async {
    if (_player.platform is! NativePlayer) return <String>[_currentUrl ?? ''];
    try {
      final path = await (_player.platform as dynamic).getProperty('path') as String;
      return <String>[path];
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _bindNativeSourceObservers(int generation) async {
    if (_disposed || _player.platform is! NativePlayer) return;
    final native = _player.platform as dynamic;

    if (_nativePathObserved) {
      try {
        await native.unobserveProperty('path');
      } catch (_) {}
      _nativePathObserved = false;
    }
    if (_nativeFramePropertiesObserved) {
      try {
        await native.unobserveProperty('video-frame-info/picture-type');
        await native.unobserveProperty('estimated-vf-fps');
      } catch (_) {}
      _nativeFramePropertiesObserved = false;
      _usesNativeFrameProbe = false;
    }
    if (_disposed || generation != _sourceFence.generation) return;

    // Every callback captures the source lease that installed it. Reading the
    // fence's current generation inside a delayed callback relabels an old
    // room/quality event as new and was the root of stale dimensions, repeated
    // danmaku recovery and spurious decoder errors after source replacement.
    await native.observeProperty('path', (String path) async {
      _handleNativePath(path, generation);
    });
    _nativePathObserved = true;
    await native.observeProperty('video-frame-info/picture-type', (String value) async {
      _handleDecodedVideoFrameSignal(value, generation);
    });
    await native.observeProperty('estimated-vf-fps', (String value) async {
      _handleDecodedVideoFrameRate(value, generation);
    });
    _nativeFramePropertiesObserved = true;
    _usesNativeFrameProbe = true;
  }

  void _handleNativePath(String path, int generation) {
    if (_disposed || generation != _sourceFence.generation) return;
    _sourceFence.observeNativeSources(<String>[path]);
    if (_sourceFence.isOpening) return;
    if (!_sourceFence.accepts(generation)) return;
    _publishCurrentNativeSnapshot(generation);
    unawaited(_refreshCurrentNativeReadinessSnapshot(generation));
    _drainDeferredNativeDiagnostic(generation);
  }

  Future<void> _refreshCurrentNativeReadinessSnapshot(int generation) async {
    if (_disposed || !_sourceFence.accepts(generation) || _player.platform is! NativePlayer) return;
    final native = _player.platform as dynamic;
    try {
      final pictureType = (await native.getProperty('video-frame-info/picture-type') as String).trim();
      if (_sourceFence.accepts(generation)) _handleDecodedVideoFrameSignal(pictureType, generation);
    } catch (_) {
      // The property is unavailable until the first decoded video frame.
    }
    try {
      final fps = (await native.getProperty('estimated-vf-fps') as String).trim();
      if (_sourceFence.accepts(generation)) _handleDecodedVideoFrameRate(fps, generation);
    } catch (_) {
      // The property is unavailable when this source has no decoded video.
    }
    try {
      final audioFormat = (await native.getProperty('audio-params/format') as String).trim();
      if (audioFormat.isNotEmpty && _sourceFence.accepts(generation)) {
        _markDecodedAudioFrame(generation);
      }
    } catch (_) {
      // The property is unavailable until the audio decoder is configured.
    }
  }

  void _handleDecodedVideoFrameSignal(String value, int generation) {
    final pictureType = value.trim().toUpperCase();
    if (pictureType != 'I' && pictureType != 'P' && pictureType != 'B') return;
    _markDecodedVideoFrame(generation);
  }

  void _handleDecodedVideoFrameRate(String value, int generation) {
    final fps = double.tryParse(value.trim());
    if (fps == null || !fps.isFinite || fps <= 0) return;
    _markDecodedVideoFrame(generation);
  }

  void _markDecodedVideoFrame(int generation) {
    if (_disposed || !_sourceFence.accepts(generation)) return;
    _sourceHasVideoFrame = true;
    _openingNativeDiagnostic = null;
    _sourceProgressRevision++;
    // Native frame probes are progress heartbeats, not playback-state
    // transitions. Republishing playing/loading on every decoded frame made
    // PlayerManager recreate watchdog timers and notify UI listeners dozens of
    // times per second on Windows. Keep the dedicated frame stream hot while
    // emitting state only when it actually changes.
    if (_loadingSubject.value) _loadingSubject.add(false);
    if (_player.state.playing) {
      if (!_playingSubject.value) _playingSubject.add(true);
      if (_stateSubject.value != PlayerState.playing) _stateSubject.add(PlayerState.playing);
    }
    _cancelRecoveredNativeError(NativeDiagnosticComponent.video);
  }

  void _markDecodedAudioFrame(int generation) {
    if (_disposed || !_sourceFence.accepts(generation)) return;
    _sourceHasAudioFrame = true;
    _sourceProgressRevision++;
    if (_isAudioOnly && _player.state.playing) {
      if (_loadingSubject.value) _loadingSubject.add(false);
      if (!_playingSubject.value) _playingSubject.add(true);
      if (_stateSubject.value != PlayerState.playing) _stateSubject.add(PlayerState.playing);
    }
    _cancelRecoveredNativeError(NativeDiagnosticComponent.audio);
  }

  @override
  Future<bool> prepareSoftwareDecoderFallback(PlayerException error) async {
    final url = _currentUrl;
    if (_disposed ||
        _isAudioOnly ||
        error.type != PlayerErrorType.codec ||
        error.code?.startsWith('audio_') == true ||
        url == null ||
        url.isEmpty ||
        _preferredHardwareDecoder == 'no' ||
        _softwareDecoderFallbackUrl == url) {
      return false;
    }

    // Only mark the next open. Changing `hwdec` while the failing source still
    // owns the decoder can synchronously emit another error into the recovery
    // stack and race the source-generation fence.
    _softwareDecoderFallbackUrl = url;
    return true;
  }

  Future<void> _applyDecoderPolicyForSource(String url) async {
    if (_player.platform is! NativePlayer) return;
    final useSoftware = _softwareDecoderFallbackUrl == url;
    if (!useSoftware) _softwareDecoderFallbackUrl = null;
    await (_player.platform as dynamic).setProperty('hwdec', useSoftware ? 'no' : _preferredHardwareDecoder);
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
    // An explicit manager play is a new source generation even if the URL is
    // textually identical. Decoder recovery, manual retry and signed CDN URLs
    // may all reopen the same string with different native policy. Skipping
    // here used to clear the public subjects in beginSourceTransition and then
    // leave them permanently empty; it also made software-decoder fallback a
    // no-op for the exact URL that had just failed in hardware.
    _currentUrl = url;
    _isAudioOnly = audioOnly;
    if (_sourceTransitionPrepared) {
      // The manager reset the public source state before rebinding its
      // source-scoped listeners. Associate that generation with this URL.
      _sourceFence.retargetOpening(url);
      _sourceTransitionPrepared = false;
    } else {
      _prepareSourceTransition(url: url);
    }
    final sourceGeneration = _sourceFence.generation;

    try {
      _stateSubject.add(PlayerState.preparing);

      await _bindNativeSourceObservers(sourceGeneration);
      await _bindListeners(sourceGeneration: sourceGeneration, force: true);
      if (_disposed || sourceGeneration != _sourceFence.generation) return;

      await _applyDecoderPolicyForSource(url);

      await _player.open(Media(url, httpHeaders: headers), play: true);

      if (_disposed || sourceGeneration != _sourceFence.generation) return;
      _sourceFence.finishOpen(await _currentNativeSourcePaths(), authorizeSuccessfulOpen: true);
      _publishCurrentNativeSnapshot(sourceGeneration);
      unawaited(_refreshCurrentNativeReadinessSnapshot(sourceGeneration));

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

      if (_disposed || sourceGeneration != _sourceFence.generation) return;
      _publishCurrentNativeSnapshot(sourceGeneration);
      final openingDiagnostic = _openingNativeDiagnostic;
      _openingNativeDiagnostic = null;
      if (openingDiagnostic != null && !_isDiagnosticComponentReady(openingDiagnostic.prefix)) {
        if (openingDiagnostic.generation == sourceGeneration) {
          _handleNativeDiagnostic(
            openingDiagnostic.message,
            nativePrefix: openingDiagnostic.prefix,
            generation: sourceGeneration,
          );
        }
      }
      _stateSubject.add(PlayerState.ready);

      if (PlatformUtils.isMobile) {
        await setVolume(1.0);
      } else {
        final targetVolume = room?.getSavedVolume() ?? 1.0;
        await setVolume(targetVolume);
      }
    } catch (e, s) {
      if (sourceGeneration != _sourceFence.generation || _disposed) return;
      final classification = PlayerErrorClassifier.classify(e.toString());
      final exception = e is PlayerException
          ? e
          : PlayerException(
              message: 'Media open failed: $e',
              type: classification.type == PlayerErrorType.native ? PlayerErrorType.source : classification.type,
              code: classification.code,
              error: e,
              stackTrace: s,
            );

      _safeAddError(exception);

      throw exception;
    } finally {
      if (!_disposed && (_sourceHasVideoFrame || (_isAudioOnly && _sourceHasAudioFrame))) {
        _loadingSubject.add(false);
      }
    }
  }

  // =========================
  // listeners
  // =========================

  Future<void> _bindListeners({required int sourceGeneration, bool force = false}) async {
    if (_listenerBound && !force) return;

    _listenerBound = true;

    await _cancelAllSubscriptions();
    if (_disposed || sourceGeneration != _sourceFence.generation) return;

    // =========================
    // playing
    // =========================

    _playingSub = _player.stream.playing.listen(
      (playing) {
        if (_disposed) return;
        if (!_sourceFence.accepts(sourceGeneration)) return;
        final publishPlaying = shouldPublishMediaKitPlaying(playing);
        _playingSubject.add(publishPlaying);
        if (publishPlaying) {
          _sourceProgressRevision++;
          // `Player.stream.playing` is the native playback authority. Optional
          // mpv frame properties are not available on every Android backend and
          // must never suppress this state or keep the manager's readiness
          // deadline alive for a stream which is already playing.
          _loadingSubject.add(false);
          _stateSubject.add(PlayerState.playing);
          _cancelRecoveredNativeError(_isAudioOnly ? NativeDiagnosticComponent.audio : NativeDiagnosticComponent.video);
        } else {
          if (!_loadingSubject.value) _stateSubject.add(PlayerState.paused);
        }
      },
      onError: (e, s) {
        _emitError(e, s, PlayerErrorType.native, sourceGeneration);
      },
    );

    // =========================
    // buffering
    // =========================

    _bufferingSub = _player.stream.buffering.listen(
      (loading) {
        if (_disposed) return;
        if (!_sourceFence.accepts(sourceGeneration)) return;
        _loadingSubject.add(loading);

        if (loading) {
          _stateSubject.add(PlayerState.buffering);
        } else {
          _sourceProgressRevision++;
          _stateSubject.add(_playingSubject.value ? PlayerState.playing : PlayerState.paused);
          if (_playingSubject.value) {
            _cancelRecoveredNativeError(
              _isAudioOnly ? NativeDiagnosticComponent.audio : NativeDiagnosticComponent.video,
            );
          }
        }
      },
      onError: (e, s) {
        _emitError(e, s, PlayerErrorType.native, sourceGeneration);
      },
    );

    // Keep width and height from the same decoder-parameter event. Listening
    // to the two derived streams independently allowed a transient width from
    // one quality/rotation state to be paired with the previous height. That
    // malformed ratio was then propagated into portrait detection and PiP.
    _videoParamsSub = _player.stream.videoParams.listen((params) {
      if (_disposed) return;
      if (!_sourceFence.accepts(sourceGeneration)) return;
      final size = resolveMediaKitDisplaySize(params);
      _widthSubject.add(size?.width);
      _heightSubject.add(size?.height);
      if (size != null) {
        // Non-native backends do not expose mpv frame properties. Their video
        // parameter event remains the strongest available readiness signal.
        if (!_usesNativeFrameProbe) _markDecodedVideoFrame(sourceGeneration);
      }
    });

    _audioParamsSub = _player.stream.audioParams.listen((_) {
      if (_disposed) return;
      _markDecodedAudioFrame(sourceGeneration);
    });

    // =========================
    // completed
    // =========================

    _completeSub = _player.stream.completed.listen(
      (completed) {
        if (_disposed) return;
        if (!_sourceFence.accepts(sourceGeneration)) return;

        if (!completed) return;

        _completeSubject.add(true);

        _stateSubject.add(PlayerState.completed);
      },
      onError: (e, s) {
        _emitError(e, s, PlayerErrorType.native, sourceGeneration);
      },
    );

    // =========================
    // error
    // =========================

    // The same native message can legitimately be emitted by two consecutive
    // CDN lines. Stream-wide `distinct` treated the second source failure as a
    // duplicate, so the recovery chain stopped on a permanent loading state.
    // Deduplication below is scoped to one source generation instead.
    if (_player.platform is NativePlayer) {
      _logSub = _player.stream.log.listen((event) {
        if (_disposed || event.level != 'error' || !_isActionableNativeLog(event.prefix, event.text)) return;
        _handleNativeDiagnostic(event.text, nativePrefix: event.prefix, generation: sourceGeneration);
      });
    } else {
      _errorSub = _player.stream.error.listen((error) {
        if (_disposed) return;
        _handleNativeDiagnostic(error.toString(), generation: sourceGeneration);
      });
    }

    // =========================
    // collect
    // =========================

    _subscriptions.addAll([
      _playingSub!,
      _bufferingSub!,
      _videoParamsSub!,
      _audioParamsSub!,
      _completeSub!,
      ?_errorSub,
      ?_logSub,
    ]);
  }

  static bool _isActionableNativeLog(String prefix, String text) {
    final normalizedPrefix = prefix.trim().toLowerCase();
    if (normalizedPrefix == 'ffmpeg') return text.trimLeft().toLowerCase().startsWith('tcp:');
    return const <String>{
      'file',
      'vd',
      'ad',
      'ffmpeg/video',
      'ffmpeg/audio',
      'cplayer',
      'stream',
    }.contains(normalizedPrefix);
  }

  void _publishCurrentNativeSnapshot(int generation) {
    if (!_sourceFence.accepts(generation) || _disposed) return;
    final size = resolveMediaKitDisplaySize(_player.state.videoParams);
    if (size != null) {
      _widthSubject.add(size.width);
      _heightSubject.add(size.height);
      if (!_usesNativeFrameProbe) _markDecodedVideoFrame(generation);
    }
    final audioParams = _player.state.audioParams;
    if (audioParams.format?.isNotEmpty == true ||
        (audioParams.sampleRate ?? 0) > 0 ||
        (audioParams.channelCount ?? 0) > 0) {
      _markDecodedAudioFrame(generation);
    }
    if (shouldPublishMediaKitPlaying(_player.state.playing)) {
      _playingSubject.add(true);
      _loadingSubject.add(false);
      _stateSubject.add(PlayerState.playing);
      _cancelRecoveredNativeError(_isAudioOnly ? NativeDiagnosticComponent.audio : NativeDiagnosticComponent.video);
    }
  }

  void _handleNativeDiagnostic(String message, {String? nativePrefix, required int generation}) {
    if (generation != _sourceFence.generation) return;
    if (_sourceFence.isOpening || !_sourceFence.accepts(generation)) {
      _openingNativeDiagnostic = _NativeDiagnostic(message: message, prefix: nativePrefix, generation: generation);
      return;
    }
    final classification = PlayerErrorClassifier.classify(message, nativePrefix: nativePrefix);
    final exception = PlayerException(message: message, type: classification.type, code: classification.code);
    if (classification.immediatelyTerminal) {
      _emitConfirmedNativeError(exception, generation);
      return;
    }

    // mpv reports recoverable packet and hardware-decoder diagnostics on the
    // same stream as terminal failures. Give the active source one bounded
    // recovery window; a fresh frame/playing transition cancels this error.
    if (_pendingNativeErrorTimer != null) return;
    _pendingNativeError = exception;
    _pendingNativeErrorGeneration = generation;
    _pendingNativeErrorProgressRevision = _sourceProgressRevision;
    _pendingNativeErrorComponent = classification.component;
    _pendingNativeErrorTimer = Timer(const Duration(milliseconds: 1200), () {
      _pendingNativeErrorTimer = null;
      final pending = _pendingNativeError;
      final pendingGeneration = _pendingNativeErrorGeneration;
      _pendingNativeError = null;
      _pendingNativeErrorGeneration = null;
      if (pending == null || pendingGeneration == null || !_sourceFence.accepts(pendingGeneration)) return;
      final componentReady = switch (_pendingNativeErrorComponent) {
        NativeDiagnosticComponent.video => _sourceHasVideoFrame,
        NativeDiagnosticComponent.audio => _sourceHasAudioFrame,
        NativeDiagnosticComponent.either => _sourceHasVideoFrame || _sourceHasAudioFrame,
      };
      final playbackProgressed = _sourceProgressRevision > _pendingNativeErrorProgressRevision;
      final recovered = playbackProgressed && _player.state.playing && (componentReady || !_loadingSubject.value);
      if (recovered || (_player.state.playing && !_loadingSubject.value)) {
        return;
      }
      _emitConfirmedNativeError(pending, pendingGeneration);
    });
  }

  void _cancelRecoveredNativeError(NativeDiagnosticComponent progressedComponent) {
    if (_pendingNativeErrorTimer == null) return;
    if (_pendingNativeErrorComponent != NativeDiagnosticComponent.either &&
        _pendingNativeErrorComponent != progressedComponent) {
      return;
    }
    _pendingNativeErrorTimer?.cancel();
    _pendingNativeErrorTimer = null;
    _pendingNativeError = null;
    _pendingNativeErrorGeneration = null;
    _pendingNativeErrorComponent = NativeDiagnosticComponent.either;
  }

  void _drainDeferredNativeDiagnostic(int generation) {
    final diagnostic = _openingNativeDiagnostic;
    if (diagnostic != null && diagnostic.generation != generation) {
      _openingNativeDiagnostic = null;
      return;
    }
    if (diagnostic != null && _isDiagnosticComponentReady(diagnostic.prefix)) {
      _openingNativeDiagnostic = null;
      return;
    }
    if (diagnostic == null || !_sourceFence.accepts(generation)) return;
    _openingNativeDiagnostic = null;
    _handleNativeDiagnostic(diagnostic.message, nativePrefix: diagnostic.prefix, generation: generation);
  }

  bool _isDiagnosticComponentReady(String? nativePrefix) {
    final prefix = nativePrefix?.trim().toLowerCase();
    if (prefix == 'ad' || prefix == 'ffmpeg/audio') return _sourceHasAudioFrame;
    if (prefix == 'vd' || prefix == 'ffmpeg/video') return _sourceHasVideoFrame;
    return _sourceHasVideoFrame || _sourceHasAudioFrame;
  }

  void _emitConfirmedNativeError(PlayerException exception, int generation) {
    if (!_sourceFence.accepts(generation) || _disposed) return;
    _emitCurrentSourceError(exception, generation);
  }

  void _emitCurrentSourceError(PlayerException exception, int generation) {
    if (!_sourceFence.isCurrentGeneration(generation) || _disposed) return;
    final now = DateTime.now();
    if (_lastEmittedNativeErrorGeneration == generation &&
        _lastEmittedNativeError == exception.toString() &&
        _lastEmittedNativeErrorAt != null &&
        now.difference(_lastEmittedNativeErrorAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastEmittedNativeErrorGeneration = generation;
    _lastEmittedNativeError = exception.toString();
    _lastEmittedNativeErrorAt = now;
    _safeAddError(exception);
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
    _videoParamsSub = null;
    _audioParamsSub = null;

    _completeSub = null;
    _errorSub = null;
    _logSub = null;
  }

  // =========================
  // emit error
  // =========================

  void _emitError(Object error, StackTrace stackTrace, PlayerErrorType type, int generation) {
    if (_disposed || !_sourceFence.accepts(generation)) return;

    _safeAddError(PlayerException(message: error.toString(), type: type, error: error, stackTrace: stackTrace));
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed) return;

    if (_errorSubject.isClosed) return;

    _errorSubject.add(exception);
  }

  // =========================
  // widget
  // =========================

  @override
  Widget getVideoWidget({BoxFit? fit}) {
    final effectiveFit = fit ?? _videoFit;
    _videoFit = effectiveFit;
    final video = Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: effectiveFit,
      // PlaybackLifecycleCoordinator is the single lifecycle authority.
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

    _pendingNativeErrorTimer?.cancel();

    _pendingNativeErrorTimer = null;

    _sourceFence.clear();

    final frameRevisionListener = _videoFrameRevisionListener;
    if (frameRevisionListener != null) {
      _controller.frameRevision.removeListener(frameRevisionListener);
      _videoFrameRevisionListener = null;
    }

    await _cancelAllSubscriptions();

    if (_nativePathObserved && _player.platform is NativePlayer) {
      try {
        await (_player.platform as dynamic).unobserveProperty('path');
      } catch (_) {}
      _nativePathObserved = false;
    }

    if (_nativeFramePropertiesObserved && _player.platform is NativePlayer) {
      try {
        final native = _player.platform as dynamic;
        await native.unobserveProperty('video-frame-info/picture-type');
        await native.unobserveProperty('estimated-vf-fps');
      } catch (_) {}
      _nativeFramePropertiesObserved = false;
      _usesNativeFrameProbe = false;
    }

    try {
      await _player.stop();
    } catch (_) {}

    try {
      await _player.dispose();
    } catch (_) {}

    _softwareDecoderFallbackUrl = null;

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

  // =========================
  // getter
  // =========================

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _playingSubject.value;

  @override
  // Windows keeps the libmpv/D3D renderer valid after [softStop]; only the
  // current Media (and therefore the CDN transport, demuxer and decoder
  // buffers) is unloaded.  The Huya first-frame-gated hand-off can therefore
  // alternate two initialized players instead of allocating another native
  // renderer every lease period.  Keep the contract Windows-only until the
  // surface-backed mobile implementations have equivalent lifecycle proof.
  bool get isReusable => PlatformUtils.isWindows;

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
  bool get supportsVideoFrameProgress => PlatformUtils.isWindows;

  @override
  Stream<int> get onVideoFrameProgress => _videoFrameProgressSubject.stream;

  @override
  PlayerEngine get engine => PlayerEngine.mediaKit;

  @override
  Player get mediaKitPlayer => _player;

  @override
  VideoController get mediaKitVideoController => _controller;
}

class _NativeDiagnostic {
  const _NativeDiagnostic({required this.message, required this.prefix, required this.generation});

  final String message;
  final String? prefix;
  final int generation;
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
  bool _hasPublishedViewport = false;

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
      _hasPublishedViewport = false;
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
      final controller = widget.controller;
      final force = !_hasPublishedViewport;
      try {
        await controller.setSize(
          width: target.width.toInt(),
          height: target.height.toInt(),
          // StableVideoLayer deliberately unmounts the Windows Texture while a
          // covering route is present. On the first layout after reattachment,
          // reassert the viewport even when NativeVideoController cached the
          // same numbers before detachment. Size equality is not proof that the
          // current Flutter presentation owns a usable native output.
          force: force,
        );
        if (!mounted || !identical(controller, widget.controller)) return;
        _requestedSize = target;
        _hasPublishedViewport = true;
      } catch (_) {
        if (identical(controller, widget.controller)) {
          _requestedSize = null;
          _hasPublishedViewport = false;
        }
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
