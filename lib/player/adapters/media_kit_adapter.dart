import 'dart:async';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';
import '../models/player_state.dart';
import 'package:flutter/material.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import '../interface/unified_player_interface.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:pure_live/common/services/settings_service.dart';

class MediaKitAdapter implements UnifiedPlayer {
  late final Player _player;

  late final VideoController _controller;

  final SettingsService settings = Get.find<SettingsService>();

  bool _initialized = false;

  bool _disposed = false;

  bool _listenerBound = false;

  bool _wasSoftStopped = false;

  String? _currentUrl;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);

  final _playingSubject = BehaviorSubject<bool>.seeded(false);

  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = BehaviorSubject<PlayerException>();

  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  final _widthSubject = BehaviorSubject<int?>.seeded(null);

  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  final List<StreamSubscription> _subscriptions = [];

  // =========================
  // init
  // =========================

  @override
  Future<void> init() async {
    if (_initialized) return;

    try {
      _stateSubject.add(PlayerState.initializing);

      _player = Player();

      if (_player.platform is NativePlayer) {
        final native = _player.platform as dynamic;

        await native.setProperty('force-seekable', 'yes');

        await native.setProperty('protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto');

        await native.setProperty('demuxer-lavf-probsize', '2097152');

        await native.setProperty('demuxer-lavf-analyzeduration', '10');

        await native.setProperty('network-timeout', '30');

        if (settings.customPlayerOutput.value) {
          await native.setProperty('ao', settings.audioOutputDriver.value);
        }
      }

      // =====================
      // controller
      // =====================

      _controller = settings.playerCompatMode.value
          ? VideoController(
              _player,
              configuration: const VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec'),
            )
          : settings.customPlayerOutput.value
          ? VideoController(
              _player,
              configuration: VideoControllerConfiguration(
                vo: settings.videoOutputDriver.value,
                hwdec: settings.videoHardwareDecoder.value,
              ),
            )
          : VideoController(
              _player,
              configuration: VideoControllerConfiguration(
                enableHardwareAcceleration: settings.enableCodec.value,
                androidAttachSurfaceAfterVideoParameters: false,
              ),
            );

      _bindListeners();

      _initialized = true;

      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'MediaKit init failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );

      _errorSubject.add(exception);

      throw exception;
    }
  }

  // =========================
  // set data source
  // =========================

  @override
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed) return;

    // 相同地址不重复 open
    if (_currentUrl == url && isPlayingNow) {
      return;
    }

    _currentUrl = url;

    try {
      if (_wasSoftStopped) {
        _wasSoftStopped = false;
        await setVolume(1.0);
      }
      _loadingSubject.add(true);

      _stateSubject.add(PlayerState.preparing);

      _completeSubject.add(false);

      // 重置宽高
      _widthSubject.add(null);

      _heightSubject.add(null);

      await _player.open(Media(url, httpHeaders: headers), play: true);

      _stateSubject.add(PlayerState.ready);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Media open failed',
        type: PlayerErrorType.source,
        error: e,
        stackTrace: s,
      );

      _errorSubject.add(exception);

      _stateSubject.add(PlayerState.error);

      throw exception;
    } finally {
      _loadingSubject.add(false);
    }
  }

  // =========================
  // listeners
  // =========================

  void _bindListeners() {
    if (_listenerBound) return;

    _listenerBound = true;

    // =====================
    // playing
    // =====================

    _subscriptions.add(
      _player.stream.playing.listen(
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
      ),
    );

    // =====================
    // buffering
    // =====================

    _subscriptions.add(
      _player.stream.buffering.listen(
        (loading) {
          if (_disposed) return;

          _loadingSubject.add(loading);

          if (loading) {
            _stateSubject.add(PlayerState.buffering);
          } else {
            if (_playingSubject.value) {
              _stateSubject.add(PlayerState.playing);
            } else {
              _stateSubject.add(PlayerState.paused);
            }
          }
        },
        onError: (e, s) {
          _emitError(e, s, PlayerErrorType.native);
        },
      ),
    );

    // =====================
    // width
    // =====================

    _subscriptions.add(
      _player.stream.width.listen((val) {
        if (_disposed) return;

        _widthSubject.add(val);
      }),
    );

    // =====================
    // height
    // =====================

    _subscriptions.add(
      _player.stream.height.listen((val) {
        if (_disposed) return;

        _heightSubject.add(val);
      }),
    );

    // =====================
    // completed
    // =====================

    _subscriptions.add(
      _player.stream.completed.listen(
        (completed) {
          if (_disposed) return;

          if (!completed) return;

          _completeSubject.add(true);

          _stateSubject.add(PlayerState.completed);
        },
        onError: (e, s) {
          _emitError(e, s, PlayerErrorType.native);
        },
      ),
    );

    // =====================
    // error
    // =====================

    _subscriptions.add(
      _player.stream.error.listen((error) {
        if (_disposed) return;
        final type = _mapErrorType(error.toString());
        _errorSubject.add(PlayerException(message: error.toString(), type: type));
        _stateSubject.add(PlayerState.error);
      }),
    );
  }

  // =========================
  // emit error
  // =========================

  void _emitError(Object error, StackTrace stackTrace, PlayerErrorType type) {
    if (_disposed) return;

    _errorSubject.add(PlayerException(message: error.toString(), type: type, error: error, stackTrace: stackTrace));

    _stateSubject.add(PlayerState.error);
  }

  // =========================
  // error mapper
  // =========================

  PlayerErrorType _mapErrorType(String error) {
    final lower = error.toLowerCase();

    // network

    if (lower.contains('network') || lower.contains('timeout') || lower.contains('io')) {
      return PlayerErrorType.network;
    }

    // codec

    if (lower.contains('codec') || lower.contains('mediacodec') || lower.contains('decode')) {
      return PlayerErrorType.codec;
    }

    // source

    if (lower.contains('404') || lower.contains('source') || lower.contains('open')) {
      return PlayerErrorType.source;
    }

    // texture

    if (lower.contains('surface') || lower.contains('texture')) {
      return PlayerErrorType.texture;
    }

    return PlayerErrorType.native;
  }

  // =========================
  // video widget
  // =========================

  @override
  Widget getVideoWidget() {
    return RepaintBoundary(
      child: Video(controller: _controller, controls: NoVideoControls),
    );
  }

  // =========================
  // play
  // =========================

  @override
  Future<void> play() async {
    await _player.play();
  }

  // =========================
  // pause
  // =========================

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  // =========================
  // stop
  // =========================

  @override
  Future<void> stop() async {
    await _player.pause();

    await _player.seek(Duration.zero);

    _stateSubject.add(PlayerState.stopped);
  }

  // =========================
  // soft stop
  // =========================

  @override
  Future<void> softStop() async {
    _wasSoftStopped = true;
    await _player.setVolume(0.0);
    await _player.pause();
  }

  // =========================
  // volume
  // =========================

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

    _listenerBound = false;

    for (final item in _subscriptions) {
      await item.cancel();
    }

    _subscriptions.clear();
    await _player.dispose();

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
  // getters
  // =========================

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow => _playingSubject.value;

  @override
  bool get isReusable => true;

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
