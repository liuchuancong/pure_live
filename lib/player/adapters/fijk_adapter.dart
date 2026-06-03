import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/player_state.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import 'package:pure_live/common/index.dart';
import '../interface/unified_player_interface.dart';
import 'package:pure_live/player/utils/fijk_helper.dart';

class FijkAdapter implements UnifiedPlayer {
  late final FijkPlayer _player;

  bool _initialized = false;
  bool _disposed = false;
  bool _isAudioOnly = false;
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
      throw exception;
    }
  }

  void _bindListeners() {
    // 先移除旧监听
    _removePlayerListener();

    _playerListener = () {
      final value = _player.value;
      final state = value.state;

      if (value.size != null) {
        final w = value.size!.width.toInt();
        final h = value.size!.height.toInt();
        if (_widthSubject.value != w) {
          _widthSubject.add(w);
          _heightSubject.add(h);
        }
      }

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
          _safeAddError(exception);
          _player.reset();
          break;
        default:
          break;
      }
    };

    _player.addListener(_playerListener!);
  }

  Future<void> _cancelAllSubscriptions() async {
    _removePlayerListener();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  void _removePlayerListener() {
    if (_playerListener != null) {
      _player.removeListener(_playerListener!);
      _playerListener = null;
    }
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed || _errorSubject.isClosed) return;
    _errorSubject.add(exception);
  }

  Future<void> _setupProxy() async {
    if (SettingsService.to.proxy.enableProxy.v) {
      final String proxyUrl = "http://${SettingsService.to.proxy.proxyHost.v}:${SettingsService.to.proxy.proxyPort.v}";
      await _player.setOption(FijkOption.formatCategory, "http_proxy", proxyUrl);
    } else {
      await _player.setOption(FijkOption.formatCategory, "http_proxy", "");
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
    try {
      _isAudioOnly = audioOnly;
      _loadingSubject.add(true);
      if (_player.state != FijkState.idle) {
        await _player.reset();
      }
      await _setupProxy();
      await FijkHelper.setFijkOption(_player, enableCodec: SettingsService.to.player.enableCodec.v, headers: headers);

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
      _safeAddError(exception);
      throw exception;
    } finally {
      _loadingSubject.add(false);
    }
  }

  @override
  Widget getVideoWidget() {
    if (_isAudioOnly) {
      return const SizedBox.shrink();
    }
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

  Future<void> applyAudioOnlySettings() async {
    await _player.setOption(FijkOption.playerCategory, "disable-vid", "1");
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;
    _disposed = true;

    //  取消所有监听
    await _cancelAllSubscriptions();

    try {
      await _player.release();
    } catch (_) {}

    _initialized = false;

    // 关闭所有流
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

  // =========================
  // GETTER
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
