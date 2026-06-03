import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'dart:developer' as developer;
import '../models/player_state.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import 'package:pure_live/common/index.dart';
import 'package:video_player/video_player.dart';
import '../interface/unified_player_interface.dart';
import 'package:pure_live/common/global/platform_utils.dart';

class FvpAdapter implements UnifiedPlayer {
  VideoPlayerController? _controller;

  bool _initialized = false;
  bool _disposed = false;
  String? _currentUrl;

  final _stateSubject = BehaviorSubject<PlayerState>.seeded(PlayerState.idle);
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);

  final _errorSubject = PublishSubject<PlayerException>();

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
      _initialized = true;
      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'FVP init failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );
      _safeAddError(exception);
      throw exception;
    }
  }

  // =========================
  // set data source
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
    if (_currentUrl == url && isPlayingNow) return;

    _currentUrl = url;

    try {
      _loadingSubject.add(true);
      _stateSubject.add(PlayerState.preparing);
      _completeSubject.add(false);
      _widthSubject.add(null);
      _heightSubject.add(null);

      // 先取消旧监听
      await _cancelAllSubscriptions();

      await _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();
      _bindListeners();

      await Future.delayed(const Duration(milliseconds: 100));
      await _controller!.play();

      final size = _controller!.value.size;
      _widthSubject.add(size.width.toInt());
      _heightSubject.add(size.height.toInt());

      _stateSubject.add(PlayerState.ready);

      if (PlatformUtils.isMobile) {
        await setVolume(1.0);
      } else {
        double targetVolume = room!.getSavedVolume();
        await setVolume(targetVolume);
      }
    } catch (e, s) {
      developer.log('FVP setDataSource failed: $e');
      final exception = PlayerException(
        message: 'FVP open failed',
        type: PlayerErrorType.source,
        error: e,
        stackTrace: s,
      );
      _safeAddError(exception);
      _stateSubject.add(PlayerState.error);
      throw exception;
    } finally {
      _loadingSubject.add(false);
    }
  }

  // =========================
  // listeners
  // =========================
  void _onPlayerValueChanged() {
    if (_disposed || _controller == null) return;

    final value = _controller!.value;
    _loadingSubject.add(value.isBuffering);

    if (value.isBuffering) {
      _stateSubject.add(PlayerState.buffering);
    }

    _playingSubject.add(value.isPlaying);

    if (!value.isBuffering) {
      _stateSubject.add(value.isPlaying ? PlayerState.playing : PlayerState.paused);
    }

    if (value.position >= value.duration && value.duration != Duration.zero) {
      _completeSubject.add(true);
      _stateSubject.add(PlayerState.completed);
    }

    if (value.hasError) {
      final type = _mapErrorType(value.errorDescription ?? '');
      _safeAddError(PlayerException(message: value.errorDescription ?? 'Unknown Error', type: type));
      _stateSubject.add(PlayerState.error);
    }
  }

  void _bindListeners() {
    if (_controller == null) return;
    _controller!.removeListener(_onPlayerValueChanged);
    _controller!.addListener(_onPlayerValueChanged);
  }

  Future<void> _cancelAllSubscriptions() async {
    // 移除播放器监听
    _controller?.removeListener(_onPlayerValueChanged);

    // 取消流订阅
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed || _errorSubject.isClosed) return;
    _errorSubject.add(exception);
  }

  // =========================
  // error mapper
  // =========================
  PlayerErrorType _mapErrorType(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('network') || lower.contains('timeout') || lower.contains('io')) {
      return PlayerErrorType.network;
    }
    if (lower.contains('codec') || lower.contains('decode')) {
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
  // video widget
  // =========================
  @override
  Widget getVideoWidget() {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox();
    }
    return VideoPlayer(controller);
  }

  // =========================
  // play
  // =========================
  @override
  Future<void> play() async => await _controller!.play();

  @override
  Future<void> pause() async => await _controller!.pause();

  @override
  Future<void> stop() async {
    await _controller!.pause();
    await _controller!.seekTo(Duration.zero);
    _stateSubject.add(PlayerState.stopped);
  }

  @override
  Future<void> softStop() async {
    await _controller!.setVolume(0.0);
    await _controller!.pause();
  }

  @override
  Future<void> setVolume(double volume) async => await _controller!.setVolume(volume);

  // =========================
  // dispose
  // =========================
  @override
  Future<void> hardDispose() async {
    if (_disposed) return;
    _disposed = true;

    // 先取消所有监听
    await _cancelAllSubscriptions();

    await _controller?.dispose();
    _controller = null;

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
