import 'dart:async';
import 'package:get/get.dart';
import '../models/player_state.dart';
import '../models/player_engine.dart';
import 'package:flutter/material.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:pure_live/player/core/player_pool.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

class SwitchableGlobalPlayer {
  final PlayerPool playerPool;

  SwitchableGlobalPlayer({required this.playerPool});

  UnifiedPlayer? _currentPlayer;

  // Rx Variables for Obx UI updates
  final _currentEngineRx = Rxn<PlayerEngine>();
  final _isInitializedRx = false.obs;
  final _videoKeyRx = "".obs;

  // Stream Subjects
  final _stateSubject = rx.BehaviorSubject<PlayerState>.seeded(PlayerState.idle);
  final _playingSubject = rx.BehaviorSubject<bool>.seeded(false);
  final _loadingSubject = rx.BehaviorSubject<bool>.seeded(false);
  final _completeSubject = rx.BehaviorSubject<bool>.seeded(false);
  final _errorSubject = rx.PublishSubject<PlayerException>();
  final _widthSubject = rx.BehaviorSubject<int?>.seeded(null);
  final _heightSubject = rx.BehaviorSubject<int?>.seeded(null);

  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  // =========================
  // Getters & Streams
  // =========================

  UnifiedPlayer? get currentPlayer => _currentPlayer;
  PlayerEngine? get currentEngine => _currentEngineRx.value;
  bool get isPlayingNow => _playingSubject.value;

  Stream<PlayerState> get onStateChanged => _stateSubject.stream;
  Stream<bool> get onPlaying => _playingSubject.stream;
  Stream<bool> get onLoading => _loadingSubject.stream;
  Stream<bool> get onComplete => _completeSubject.stream;
  Stream<PlayerException> get onError => _errorSubject.stream;
  Stream<int?> get width => _widthSubject.stream;
  Stream<int?> get height => _heightSubject.stream;

  // =========================
  // UI Rendering (Integrated)
  // =========================

  /// Returns the reactive video widget with FittedBox scaling
  Widget getVideoWidget(int fitIndex, {Widget? controls, required List<BoxFit> fitList}) {
    return Obx(() {
      // 1. Show loader if not initialized
      if (!_isInitializedRx.value || _currentPlayer == null) {
        return _buildPlaceholder();
      }

      // 2. Unique key to prevent texture bleeding between engines
      final engineKey = ValueKey("${_currentEngineRx.value?.name}_${_videoKeyRx.value}");
      final boxFit = fitList[fitIndex];

      return KeyedSubtree(
        key: engineKey,
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // Video Layer with specific FittedBox logic
              Positioned.fill(
                child: FittedBox(
                  fit: boxFit,
                  clipBehavior: Clip.hardEdge,
                  child: StreamBuilder<List<int?>>(
                    // Listen to width/height to resize the SizedBox
                    stream: rx.CombineLatestStream.list([width, height]),
                    builder: (context, snapshot) {
                      final w = snapshot.data?[0]?.toDouble() ?? 1920.0;
                      final h = snapshot.data?[1]?.toDouble() ?? 1080.0;
                      return SizedBox(width: w, height: h, child: _currentPlayer!.getVideoWidget());
                    },
                  ),
                ),
              ),
              // Controls Layer
              if (controls != null) Positioned.fill(child: controls),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white70)),
    );
  }

  // =========================
  // Core Methods
  // =========================

  Future<void> switchEngine(PlayerEngine engine) async {
    if (_disposed) return;
    if (_currentEngineRx.value == engine && _currentPlayer != null) return;

    _isInitializedRx.value = false;
    _stateSubject.add(PlayerState.initializing);

    try {
      await _clearSubscriptions();
      await _currentPlayer?.pause();

      final newPlayer = await playerPool.getPlayer(engine);
      _currentPlayer = newPlayer;
      _currentEngineRx.value = engine;

      _bindPlayerStreams(newPlayer);

      _isInitializedRx.value = true;
      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      _handleException('Switch engine failed', PlayerErrorType.lifecycle, e, s);
    }
  }

  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed || _currentPlayer == null) return;

    try {
      _videoKeyRx.value = url;
      _widthSubject.add(null);
      _heightSubject.add(null);
      _stateSubject.add(PlayerState.preparing);

      await _currentPlayer!.setDataSource(url, playUrls, headers);
      _stateSubject.add(PlayerState.ready);
    } catch (e, s) {
      _handleException('Set data source failed', PlayerErrorType.source, e, s);
    }
  }

  // --- Controls ---
  Future<void> play() => _currentPlayer?.play() ?? Future.value();
  Future<void> pause() => _currentPlayer?.pause() ?? Future.value();
  Future<void> stop() => _currentPlayer?.stop() ?? Future.value();
  Future<void> softStop() => _currentPlayer?.softStop() ?? Future.value();
  Future<void> setVolume(double vol) => _currentPlayer?.setVolume(vol.clamp(0.0, 1.0)) ?? Future.value();

  // =========================
  // Internal Helpers
  // =========================

  void _bindPlayerStreams(UnifiedPlayer player) {
    _subscriptions.add(
      player.onPlaying.listen((playing) {
        _playingSubject.add(playing);
        _stateSubject.add(playing ? PlayerState.playing : PlayerState.paused);
      }),
    );

    _subscriptions.add(
      player.onLoading.listen((loading) {
        _loadingSubject.add(loading);
        if (loading) _stateSubject.add(PlayerState.buffering);
      }),
    );

    _subscriptions.add(player.onComplete.listen(_completeSubject.add));
    _subscriptions.add(player.onStateChanged.listen(_stateSubject.add));
    _subscriptions.add(
      player.onError.listen((error) {
        _errorSubject.add(error);
        _stateSubject.add(PlayerState.error);
      }),
    );

    _subscriptions.add(player.width.listen(_widthSubject.add));
    _subscriptions.add(player.height.listen(_heightSubject.add));
  }

  void _handleException(String msg, PlayerErrorType type, dynamic e, StackTrace s) {
    final exception = PlayerException(message: msg, type: type, error: e, stackTrace: s);
    _errorSubject.add(exception);
    _stateSubject.add(PlayerState.error);
    throw exception;
  }

  Future<void> _clearSubscriptions() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _clearSubscriptions();
    await playerPool.disposeAll();

    await Future.wait([
      _stateSubject.close(),
      _playingSubject.close(),
      _loadingSubject.close(),
      _completeSubject.close(),
      _errorSubject.close(),
      _widthSubject.close(),
      _heightSubject.close(),
    ]);
  }
}
