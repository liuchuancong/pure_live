import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/player_state.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import '../core/player_error_classifier.dart';

import 'package:pure_live/common/index.dart';

import '../interface/unified_player_interface.dart';

import 'package:pure_live/player/models/player_engine.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:pure_live/player/interface/video_player_accessor.dart';

class BetterPlayerAdapter
    implements UnifiedPlayer, BetterPlayerAccessor, VideoFitAwarePlayer, SourceTransitionAwarePlayer {
  BetterPlayerController? _controller;

  bool _initialized = false;
  bool _disposed = false;
  bool _isAudioOnly = false;
  bool _sourceTransitionPrepared = false;
  bool _acceptSourceEvents = false;
  bool _sourceOpening = false;
  PlayerException? _deferredSourceError;
  BoxFit _videoFit = BoxFit.contain;

  void Function(BetterPlayerEvent)? _eventListener;

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

    BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      autoPlay: true,
      fit: _videoFit,
      handleLifecycle: false,
      fullScreenByDefault: false,
      autoDispose: false,
      looping: false,
      controlsConfiguration: BetterPlayerControlsConfiguration(showControls: false),
    );

    _controller = BetterPlayerController(betterPlayerConfiguration);
    _bindListeners();
    _initialized = true;
    _stateSubject.add(PlayerState.initialized);
  }

  void _bindListeners() {
    // 先移除旧监听
    _removeEventListener();

    _eventListener = (BetterPlayerEvent event) {
      if (!_acceptSourceEvents || _disposed) return;
      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
        case BetterPlayerEventType.changedResolution:
          final size = _controller?.videoPlayerController?.value.size;
          if (size != null && size.width > 0) {
            _widthSubject.add(size.width.toInt());
            _heightSubject.add(size.height.toInt());
          }
          break;

        case BetterPlayerEventType.play:
          _playingSubject.add(true);
          _stateSubject.add(PlayerState.playing);
          break;
        case BetterPlayerEventType.pause:
          _playingSubject.add(false);
          _stateSubject.add(PlayerState.paused);
          break;
        case BetterPlayerEventType.bufferingStart:
          _loadingSubject.add(true);
          _stateSubject.add(PlayerState.buffering);
          break;
        case BetterPlayerEventType.bufferingEnd:
          _loadingSubject.add(false);
          if (_playingSubject.value) {
            _stateSubject.add(PlayerState.playing);
          }
          break;
        case BetterPlayerEventType.finished:
          _completeSubject.add(true);
          _stateSubject.add(PlayerState.completed);
          break;
        case BetterPlayerEventType.exception:
          _playingSubject.add(false);
          _loadingSubject.add(false);
          final message = event.parameters?['exception']?.toString() ?? 'BetterPlayer Error';
          final classification = PlayerErrorClassifier.classify(message);
          final exception = PlayerException(message: message, type: classification.type, code: classification.code);
          if (_sourceOpening) {
            _deferredSourceError = exception;
          } else {
            _safeAddError(exception);
          }
          break;
        default:
          break;
      }
    };

    _controller!.addEventsListener(_eventListener!);
  }

  Future<void> _cancelAllSubscriptions() async {
    _removeEventListener();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  void _removeEventListener() {
    if (_eventListener != null && _controller != null) {
      _controller!.removeEventsListener(_eventListener!);
      _eventListener = null;
    }
  }

  void _safeAddError(PlayerException exception) {
    if (_disposed || _errorSubject.isClosed) return;
    _errorSubject.add(exception);
  }

  @override
  void beginSourceTransition() {
    if (_disposed) return;
    _acceptSourceEvents = false;
    _sourceTransitionPrepared = true;
    _sourceOpening = false;
    _deferredSourceError = null;
    _playingSubject.add(false);
    _loadingSubject.add(true);
    _completeSubject.add(false);
    _widthSubject.add(null);
    _heightSubject.add(null);
  }

  void _consumeSourceTransition() {
    if (!_sourceTransitionPrepared) beginSourceTransition();
    _sourceTransitionPrepared = false;
  }

  void _publishCurrentSourceState() {
    if (!_acceptSourceEvents || _disposed) return;
    final value = _controller?.videoPlayerController?.value;
    final size = value?.size;
    if (size != null && size.width > 0 && size.height > 0) {
      _widthSubject.add(size.width.toInt());
      _heightSubject.add(size.height.toInt());
    }
    if (value?.isPlaying == true) {
      _playingSubject.add(true);
      _loadingSubject.add(false);
      _stateSubject.add(PlayerState.playing);
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
    _consumeSourceTransition();
    try {
      BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        headers: headers,
        liveStream: true,
      );

      // ExoPlayer can synchronously emit an exception while setupDataSource is
      // still pending. Bind that error to the replacement source instead of
      // dropping the only event before `_acceptSourceEvents` becomes true.
      _sourceOpening = true;
      _acceptSourceEvents = true;
      await _controller!.setupDataSource(dataSource);
      _sourceOpening = false;
      final deferredError = _deferredSourceError;
      _deferredSourceError = null;
      if (deferredError != null && _controller?.videoPlayerController?.value.hasError == true) {
        throw deferredError;
      }

      _publishCurrentSourceState();

      _stateSubject.add(PlayerState.ready);
      await setVolume(1.0);
    } catch (e, s) {
      _sourceOpening = false;
      _acceptSourceEvents = false;
      final exception = e is PlayerException
          ? e
          : PlayerException(
              message: 'BetterPlayer setDataSource failed',
              type: PlayerErrorType.source,
              error: e,
              stackTrace: s,
            );
      _safeAddError(exception);
      throw exception;
    } finally {
      if (_playingSubject.value) _loadingSubject.add(false);
    }
  }

  @override
  Widget getVideoWidget({BoxFit? fit}) {
    if (_isAudioOnly) return const SizedBox.shrink();
    if (fit != null) setVideoFit(fit);
    return BetterPlayer(controller: _controller!);
  }

  @override
  void setVideoFit(BoxFit fit) {
    if (_videoFit == fit) return;
    _videoFit = fit;
    _controller?.setOverriddenFit(fit);
  }

  @override
  Future<void> play() => _controller?.play() ?? Future.value();
  @override
  Future<void> pause() => _controller?.pause() ?? Future.value();

  @override
  Future<void> stop() async {
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
  }

  @override
  Future<void> softStop() async {
    if (_controller != null) {
      await _controller!.setVolume(0.0);
    }
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_disposed) return;
    _isAudioOnly = audioOnly;
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;

    await _cancelAllSubscriptions();

    if (_controller != null) {
      try {
        await _controller!.setVolume(0.0);
        await _controller!.pause();
        _controller!.dispose();
        _controller = null;
      } catch (e) {
        debugPrint("BetterPlayer dispose error: $e");
      }
    }

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
    await _controller?.setVolume(volume);
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
  BetterPlayerController get betterPlayerController => _controller!;

  @override
  PlayerEngine get engine => PlayerEngine.exo;
}
