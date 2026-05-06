import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/player_state.dart';
import 'package:flutter/material.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import '../core/player_error_dispatcher.dart';
import '../interface/unified_player_interface.dart';
import 'package:better_player_plus/better_player_plus.dart';

class BetterPlayerAdapter implements UnifiedPlayer {
  BetterPlayerController? _controller;

  bool _initialized = false;
  bool _disposed = false;
  bool _wasSoftStopped = false;
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

    const betterPlayerConfiguration = BetterPlayerConfiguration(
      autoPlay: true,
      fit: BoxFit.contain,
      handleLifecycle: true,
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
    _controller!.addEventsListener((BetterPlayerEvent event) {
      switch (event.betterPlayerEventType) {
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
          break;
        case BetterPlayerEventType.finished:
          _completeSubject.add(true);
          _stateSubject.add(PlayerState.completed);
          break;
        case BetterPlayerEventType.exception:
          final exception = PlayerException(
            message: event.parameters?['exception']?.toString() ?? 'BetterPlayer Error',
            type: PlayerErrorType.native,
          );
          _errorSubject.add(exception);
          PlayerErrorDispatcher.instance.dispatch(exception);
          break;
        default:
          break;
      }
    });
  }

  @override
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers) async {
    try {
      if (_wasSoftStopped) {
        _wasSoftStopped = false;
        await _controller?.setVolume(1.0);
      }
      _loadingSubject.add(true);

      BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        headers: headers,
      );

      await _controller!.setupDataSource(dataSource);

      _stateSubject.add(PlayerState.ready);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'BetterPlayer setDataSource failed',
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
    return BetterPlayer(controller: _controller!);
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
  @override
  Future<void> softStop() async {
    if (_controller != null) {
      _wasSoftStopped = true;
      await _controller!.setVolume(0.0); // 立即静音
    }
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    if (_controller != null) {
      try {
        await _controller!.setVolume(0.0);
        await _controller!.pause();
        _controller!.dispose();
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
}
