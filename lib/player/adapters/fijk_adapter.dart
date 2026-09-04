import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/player_state.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';

import 'package:pure_live/common/index.dart';

import '../interface/unified_player_interface.dart';

import 'package:pure_live/player/utils/fijk_helper.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/interface/fijk_player_accessor.dart';

class FijkAdapter implements UnifiedPlayer, FijkPlayerAccessor {
  late final FijkPlayer _player;

  bool _initialized = false;
  bool _disposed = false;
  bool _isAudioOnly = false;
  bool _autoStartPending = false;
  bool _autoStartScheduled = false;
  bool _videoDetached = false;
  VoidCallback? _playerListener;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = PublishSubject<PlayerException>();

  final _completeSubject = BehaviorSubject<bool>.seeded(false);
  final _widthSubject = BehaviorSubject<int?>.seeded(null);
  final _heightSubject = BehaviorSubject<int?>.seeded(null);

  final List<StreamSubscription> _subscriptions = [];

  @override
  Future<void> init({bool audioOnly = false}) async {
    if (_initialized) return;

    _isAudioOnly = audioOnly;

    try {
      _stateSubject.add(PlayerState.initializing);

      _player = FijkPlayer();

      if (audioOnly) {
        await applyAudioOnlySettings();
      }

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

      _safeAddError(exception);
      rethrow;
    }
  }

  void _bindListeners() {
    _removePlayerListener();

    _playerListener = () {
      if (_disposed) return;

      final value = _player.value;
      final state = value.state;

      final size = value.size;

      if (size != null) {
        final width = size.width.toInt();
        final height = size.height.toInt();

        if (_widthSubject.value != width) {
          _widthSubject.add(width);
        }

        if (_heightSubject.value != height) {
          _heightSubject.add(height);
        }
      }

      switch (state) {
        case FijkState.asyncPreparing:
          _loadingSubject.add(true);
          _stateSubject.add(PlayerState.buffering);
          break;

        case FijkState.prepared:
          _loadingSubject.add(true);
          _stateSubject.add(PlayerState.buffering);
          break;

        case FijkState.started:
          _autoStartPending = false;
          _autoStartScheduled = false;
          _loadingSubject.add(false);
          _playingSubject.add(true);
          _stateSubject.add(PlayerState.playing);
          break;

        case FijkState.paused:
          _loadingSubject.add(false);
          _playingSubject.add(false);
          _stateSubject.add(PlayerState.paused);
          break;

        case FijkState.completed:
          _loadingSubject.add(false);
          _playingSubject.add(false);
          _completeSubject.add(true);
          _stateSubject.add(PlayerState.completed);
          break;

        case FijkState.error:
          _loadingSubject.add(false);
          _playingSubject.add(false);

          final exception = PlayerException(
            message: 'Fijk native error',
            type: PlayerErrorType.native,
          );

          _safeAddError(exception);

          unawaited(_resetAfterError());
          break;

        default:
          break;
      }
    };

    _player.addListener(_playerListener!);
  }

  Future<void> _resetAfterError() async {
    if (_disposed) return;

    try {
      await _player.reset();
    } catch (_) {}

    if (_disposed) return;

    _autoStartPending = false;
    _autoStartScheduled = false;
    _loadingSubject.add(false);
    _playingSubject.add(false);
    _stateSubject.add(PlayerState.idle);
  }

  void _removePlayerListener() {
    if (_playerListener != null) {
      _player.removeListener(_playerListener!);
      _playerListener = null;
    }
  }

  Future<void> _cancelAllSubscriptions() async {
    _removePlayerListener();

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    _subscriptions.clear();
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed || _errorSubject.isClosed) return;

    _errorSubject.add(exception);
  }

  Future<void> _setupProxy() async {
    if (SettingsService.to.proxy.enableProxy.v) {
      final proxyUrl =
          'http://${SettingsService.to.proxy.proxyHost.v}:'
          '${SettingsService.to.proxy.proxyPort.v}';

      await _player.setOption(FijkOption.formatCategory, 'http_proxy', proxyUrl);
    } else {
      await _player.setOption(FijkOption.formatCategory, 'http_proxy', '');
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
    if (_disposed) return;

    try {
      _isAudioOnly = audioOnly;
      _autoStartPending = !audioOnly;
      _autoStartScheduled = false;
      _videoDetached = false;
      _loadingSubject.add(true);
      _playingSubject.add(false);
      _completeSubject.add(false);

      _widthSubject.add(null);
      _heightSubject.add(null);

      if (_player.state != FijkState.idle) {
        await _player.reset();
      }

      if (_disposed) return;

      await _setupProxy();

      await FijkHelper.setFijkOption(
        _player,
        enableHardwareCodec: SettingsService.to.player.enableCodec.v,
        headers: headers,
      );

      if (_disposed) return;

      await _player.setDataSource(url, autoPlay: false);

      if (_disposed) return;

      _stateSubject.add(PlayerState.ready);

      await setVolume(1.0);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Fijk setDataSource failed',
        type: PlayerErrorType.source,
        error: e,
        stackTrace: s,
      );

      _autoStartPending = false;
      _autoStartScheduled = false;
      _safeAddError(exception);

      rethrow;
    } finally {
      if (!_disposed) {
        _loadingSubject.add(false);
      }
    }
  }

  void _scheduleAutoStart() {
    if (_disposed || _isAudioOnly || !_autoStartPending || _autoStartScheduled) {
      return;
    }

    _autoStartScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoStartScheduled = false;

      if (_disposed || !_autoStartPending || _isAudioOnly) {
        return;
      }

      final state = _player.state;

      if (state != FijkState.prepared &&
          state != FijkState.paused &&
          state != FijkState.initialized) {
        return;
      }

      try {
        await _player.start();
      } catch (e, s) {
        _autoStartPending = false;

        final exception = PlayerException(
          message: 'Fijk start failed',
          type: PlayerErrorType.native,
          error: e,
          stackTrace: s,
        );

        _safeAddError(exception);
      }
    });
  }

  @override
  Widget getVideoWidget(BoxFit boxfit) {
    if (_isAudioOnly || _videoDetached) {
      return const SizedBox.shrink();
    }

    _scheduleAutoStart();

    return FijkView(
      player: _player,
      fs: false,
      color: Colors.black,
      panelBuilder:
          (
            FijkPlayer fijkPlayer,
            FijkData fijkData,
            BuildContext context,
            Size viewSize,
            Rect texturePos,
          ) {
            return const SizedBox();
          },
    );
  }

  @override
  Future<void> play() async {
    if (_disposed) return;

    _autoStartPending = false;
    _autoStartScheduled = false;

    await _player.start();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;

    _autoStartPending = false;
    _autoStartScheduled = false;

    await _player.pause();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;

    _autoStartPending = false;
    _autoStartScheduled = false;

    await _player.stop();
  }

  @override
  Future<void> softStop() async {
    if (!_initialized || _disposed) return;

    _autoStartPending = false;
    _autoStartScheduled = false;
    _videoDetached = true;

    try {
      await _player.reset();
    } catch (_) {}

    if (_disposed) return;

    _playingSubject.add(false);
    _loadingSubject.add(false);
    _completeSubject.add(false);
    _widthSubject.add(null);
    _heightSubject.add(null);
    _stateSubject.add(PlayerState.idle);
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_disposed || _isAudioOnly == audioOnly) return;

    await _player.setOption(FijkOption.playerCategory, 'disable-vid', audioOnly ? '1' : '0');

    _isAudioOnly = audioOnly;

    if (audioOnly) {
      _autoStartPending = false;
      _autoStartScheduled = false;
    }
  }

  Future<void> applyAudioOnlySettings() async {
    await _player.setOption(FijkOption.playerCategory, 'disable-vid', '1');
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;

    _disposed = true;
    _autoStartPending = false;
    _autoStartScheduled = false;

    await _cancelAllSubscriptions();

    try {
      await _player.release();
    } catch (_) {}

    _initialized = false;

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
    if (_disposed) return;

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

  @override
  PlayerEngine get engine => PlayerEngine.fijk;

  @override
  FijkPlayer get fijkPlayer => _player;
}
