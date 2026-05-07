import 'dart:async';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';
import '../models/player_state.dart';
import 'package:flutter/material.dart';
import 'package:flv_lzc/fijkplayer.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import '../core/player_error_dispatcher.dart';
import '../interface/unified_player_interface.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/player/utils/fijk_helper.dart';
import 'package:pure_live/common/services/settings_service.dart';

class FijkAdapter implements UnifiedPlayer {
  late final FijkPlayer _player;

  bool _initialized = false;

  bool _disposed = false;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);

  final _playingSubject = BehaviorSubject<bool>.seeded(false);

  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = BehaviorSubject<PlayerException>();

  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  final _widthSubject = BehaviorSubject<int?>.seeded(null);

  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  @override
  Future<void> init() async {
    if (_initialized) return;

    try {
      _stateSubject.add(PlayerState.initializing);

      _player = FijkPlayer();

      _bindListeners();

      _initialized = true;

      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Fijk init failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );

      _errorSubject.add(exception);

      throw exception;
    }
  }

  void _bindListeners() {
    _player.addListener(() {
      final value = _player.value;
      final state = value.state;

      // 1. 同步宽高 (修复宽高流为空的问题)
      if (value.size != null) {
        if (_widthSubject.value != value.size!.width.toInt()) {
          _widthSubject.add(value.size!.width.toInt());
          _heightSubject.add(value.size!.height.toInt());
        }
      }

      // 2. 完善状态映射
      switch (state) {
        case FijkState.asyncPreparing:
        case FijkState.prepared:
          _loadingSubject.add(true);
          _stateSubject.add(PlayerState.buffering);
          break;
        case FijkState.started:
          _loadingSubject.add(false);
          _playingSubject.add(true);
          _stateSubject.add(PlayerState.playing);
          break;
        case FijkState.paused:
          _playingSubject.add(false);
          _stateSubject.add(PlayerState.paused);
          break;
        case FijkState.completed:
          _playingSubject.add(false);
          _completeSubject.add(true);
          _stateSubject.add(PlayerState.completed);
          break;
        case FijkState.error:
          _loadingSubject.add(false);
          final exception = PlayerException(message: 'Fijk native error', type: PlayerErrorType.native);
          _errorSubject.add(exception);
          _player.reset();
          PlayerErrorDispatcher.instance.dispatch(exception);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _setupProxy() async {
    final SettingsService settings = Get.find<SettingsService>();
    if (settings.enableProxy.value) {
      final String proxyUrl = "http://${settings.proxyHost.value}:${settings.proxyPort.value}";
      await _player.setOption(FijkOption.formatCategory, "http_proxy", proxyUrl);
    } else {
      await _player.setOption(FijkOption.formatCategory, "http_proxy", "");
    }
  }

  @override
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers, {LiveRoom? room}) async {
    try {
      _loadingSubject.add(true);
      if (_player.state != FijkState.idle) {
        await _player.reset();
      }
      _setupProxy();
      final SettingsService settings = Get.find<SettingsService>();
      await FijkHelper.setFijkOption(_player, enableCodec: settings.enableCodec.value, headers: headers);
      await _player.setDataSource(url, autoPlay: true);
      _stateSubject.add(PlayerState.ready);
      await setVolume(1.0);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Fijk setDataSource failed',
        type: PlayerErrorType.source,
        error: e,
        stackTrace: s,
      );

      _errorSubject.add(exception);

      throw exception;
    } finally {
      _loadingSubject.add(false);
    }
  }

  @override
  Widget getVideoWidget() {
    return FijkView(
      player: _player,
      fit: FijkFit.contain,
      fs: false,
      color: Colors.black,
      panelBuilder: (FijkPlayer fijkPlayer, FijkData fijkData, BuildContext context, Size viewSize, Rect texturePos) {
        return const SizedBox();
      },
    );
  }

  @override
  Future<void> play() => _player.start();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> softStop() async {
    if (!_initialized) return;
    await _player.reset();
    _playingSubject.add(false);
    _loadingSubject.add(false);
    _stateSubject.add(PlayerState.idle);
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;

    _disposed = true;

    await _player.release();
    _initialized = false;
    _stateSubject.add(PlayerState.idle);
    _playingSubject.add(false);
    _loadingSubject.add(false);
    await _stateSubject.close();
    await _playingSubject.close();
    await _loadingSubject.close();
    await _errorSubject.close();
    await _completeSubject.close();
    await _widthSubject.close();
    await _heightSubject.close();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

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
