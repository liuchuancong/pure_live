import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/player_state.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';

import '../interface/unified_player_interface.dart';

import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:pure_live/common/global/platform_utils.dart';

class MediaKitAdapter implements UnifiedPlayer {
  MediaKitAdapter() {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyAudioOnly);
  }

  late final Player _player;

  late final VideoController _controller;

  bool _initialized = false;

  bool _disposed = false;

  bool _listenerBound = false;

  String? _currentUrl;

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

    _listenerBound = false;

    _currentUrl = null;

    try {
      _stateSubject.add(PlayerState.initializing);

      _player = Player();

      if (_player.platform is NativePlayer) {
        final native = _player.platform as dynamic;

        await native.setProperty('force-seekable', 'yes');

        await native.setProperty('protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto');

        await native.setProperty('demuxer-lavf-probesize', '2097152');

        // Live FLV/HLS streams need a short probe rather than a long-file
        // analysis pass.  This reduces the black-screen interval before the
        // first decoded frame while retaining enough data for codec detection.
        await native.setProperty('demuxer-lavf-analyzeduration', '2');

        await native.setProperty('network-timeout', '15');

        if (SettingsService.to.player.customPlayerOutput.v) {
          await native.setProperty('ao', SettingsService.to.player.audioOutputDriver.v);
        }

        if (SettingsService.to.proxy.enableProxy.v && SettingsService.to.proxy.proxyHost.v.isNotEmpty) {
          final proxyUrl = "http://${SettingsService.to.proxy.proxyHost.v}:${SettingsService.to.proxy.proxyPort.v}";

          await native.setProperty('http-proxy', proxyUrl);
        }

        if (PlatformUtils.isMacOS) {
          await native.setProperty('hwdec', 'no');
        }
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

      // mpv may reset its selected track when a new live source opens. Apply
      // the requested mode only after `open`, when track selection is valid.
      // This also avoids waiting for a not-yet-mounted Android video surface
      // during automatic ASMR startup.
      await _audioModeTransitions.submit(audioOnly);

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
    return RepaintBoundary(
      child: Video(
        controller: _controller,
        controls: NoVideoControls,
        // LivePlay's WidgetsBindingObserver is the single lifecycle authority.
        // Letting Video apply a second, settings-only policy paused audio-only
        // rooms on Home/lock even though the background policy kept them alive.
        pauseUponEnteringBackgroundMode: false,
        resumeUponEnteringForegroundMode: false,
      ),
    );
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
    await _player.setVolume(0.0);

    await _player.pause();
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) => _audioModeTransitions.submit(audioOnly);

  Future<void> _applyAudioOnly(bool audioOnly) async {
    if (_disposed) return;

    try {
      // Use media_kit's public track API so its PlayerState stays in sync with
      // mpv. Keep the Video widget/controller mounted; only the decoded track
      // changes, avoiding an Android Surface detach/reattach cycle.
      final track = audioOnly ? VideoTrack.no() : VideoTrack.auto();
      // Keep media_kit's native command lock enabled. A Future.timeout does not
      // cancel the underlying mpv command; issuing an unlocked opposite command
      // could otherwise complete out of order and leave the actual track at the
      // stale value. This adapter-level latest-value queue serializes even the
      // work that continues after an outer timeout.
      await _player.setVideoTrack(track);
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
}
