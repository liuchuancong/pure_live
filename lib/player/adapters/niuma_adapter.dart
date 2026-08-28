import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/player_state.dart';
import '../models/player_engine.dart';
import '../models/player_exception.dart';
import '../models/player_error_type.dart';

import 'package:pure_live/common/index.dart';

import '../interface/niuma_player_accessor.dart';
import '../interface/unified_player_interface.dart';

class NiumaPlayerAdapter implements UnifiedPlayer, NiumaPlayerAccessor {
  NiumaPlayerController? _controller;

  bool _initialized = false;
  bool _disposed = false;
  bool _isAudioOnly = false;
  bool _settingSource = false;

  VoidCallback? _controllerListener;

  final BehaviorSubject<PlayerState> _stateSubject = BehaviorSubject.seeded(PlayerState.idle);

  final BehaviorSubject<bool> _playingSubject = BehaviorSubject.seeded(false);

  final BehaviorSubject<bool> _loadingSubject = BehaviorSubject.seeded(false);

  final PublishSubject<PlayerException> _errorSubject = PublishSubject();

  final BehaviorSubject<bool> _completeSubject = BehaviorSubject.seeded(false);

  final BehaviorSubject<int?> _widthSubject = BehaviorSubject.seeded(null);

  final BehaviorSubject<int?> _heightSubject = BehaviorSubject.seeded(null);

  @override
  Future<void> init({bool audioOnly = false}) async {
    _checkDisposed();

    if (_initialized) {
      return;
    }

    _isAudioOnly = audioOnly;
    _stateSubject.add(PlayerState.initializing);

    try {
      _initialized = true;
      _stateSubject.add(PlayerState.initialized);
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Niuma init failed',
        type: PlayerErrorType.initialization,
        error: e,
        stackTrace: s,
      );

      _emitError(exception);
      rethrow;
    }
  }

  NiumaMediaSource _createMediaSource({
    required String url,
    required List<String> playUrls,
    required Map<String, String> headers,
  }) {
    final urls = <String>[if (url.isNotEmpty) url, ...playUrls].where((url) => url.isNotEmpty).toSet().toList();

    if (urls.isEmpty) {
      throw ArgumentError('No playable source url');
    }

    final lines = <MediaLine>[
      for (var i = 0; i < urls.length; i++)
        MediaLine(
          id: 'line_$i',
          label: '线路 ${i + 1}',
          priority: i,
          source: NiumaDataSource.network(urls[i], headers: headers),
        ),
    ];

    return NiumaMediaSource.lines(lines: lines, defaultLineId: lines.first.id);
  }

  NiumaPlayerController _createController(NiumaMediaSource source) {
    final controller = NiumaPlayerController(source, options: NiumaPlayerOptions(forceIjkOnAndroid: true));

    _controller = controller;
    _bindController(controller);

    return controller;
  }

  void _bindController(NiumaPlayerController controller) {
    _unbindController();

    void listener() {
      if (_disposed) {
        return;
      }

      _syncValue(controller.value);
    }

    _controllerListener = listener;

    controller.addListener(listener);

    _syncValue(controller.value);
  }

  void _unbindController() {
    final controller = _controller;
    final listener = _controllerListener;

    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }

    _controllerListener = null;
  }

  void _syncValue(NiumaPlayerValue value) {
    if (_disposed) {
      return;
    }

    final size = value.size;

    final width = size.width.round();
    final height = size.height.round();

    if (width > 0 && _widthSubject.value != width) {
      _widthSubject.add(width);
    }

    if (height > 0 && _heightSubject.value != height) {
      _heightSubject.add(height);
    }

    switch (value.phase) {
      case PlayerPhase.idle:
        _setState(state: PlayerState.idle, loading: false, playing: false, complete: false);
        break;

      case PlayerPhase.opening:
        _setState(state: PlayerState.buffering, loading: true, playing: false, complete: false);
        break;

      case PlayerPhase.ready:
        _setState(state: PlayerState.ready, loading: false, playing: false, complete: false);
        break;

      case PlayerPhase.playing:
        _setState(state: PlayerState.playing, loading: false, playing: true, complete: false);
        break;

      case PlayerPhase.paused:
        _setState(state: PlayerState.paused, loading: false, playing: false, complete: false);
        break;

      case PlayerPhase.buffering:
        _setState(state: PlayerState.buffering, loading: true, playing: false, complete: false);
        break;

      case PlayerPhase.ended:
        _setState(state: PlayerState.completed, loading: false, playing: false, complete: true);
        break;

      case PlayerPhase.error:
        _setState(state: PlayerState.error, loading: false, playing: false, complete: false);

        final error = value.error;

        _emitError(
          PlayerException(message: error?.message ?? 'Niuma player error', type: PlayerErrorType.native, error: error),
        );
        break;
    }
  }

  void _setState({required PlayerState state, required bool loading, required bool playing, required bool complete}) {
    _stateSubject.add(state);
    _loadingSubject.add(loading);
    _playingSubject.add(playing);
    _completeSubject.add(complete);
  }

  @override
  Future<void> setDataSource(
    String url,
    List<String> playUrls,
    Map<String, String> headers, {
    LiveRoom? room,
    bool audioOnly = false,
  }) async {
    _checkDisposed();

    if (_settingSource) {
      return;
    }

    if (!_initialized) {
      await init(audioOnly: audioOnly);
    }

    _settingSource = true;
    _isAudioOnly = audioOnly;

    _loadingSubject.add(true);
    _completeSubject.add(false);

    try {
      final source = _createMediaSource(url: url, playUrls: playUrls, headers: headers);

      await _replaceController(source);

      final controller = _controller!;

      await controller.initialize();

      await controller.play();

      if (_disposed) {
        return;
      }

      await controller.setVolume(1.0);

      if (_disposed) {
        return;
      }

      await controller.play();
    } catch (e, s) {
      final exception = PlayerException(
        message: 'Niuma setDataSource failed',
        type: PlayerErrorType.source,
        error: e,
        stackTrace: s,
      );

      _emitError(exception);

      if (!_disposed) {
        _stateSubject.add(PlayerState.error);
      }

      rethrow;
    } finally {
      _settingSource = false;

      if (!_disposed) {
        _loadingSubject.add(false);
      }
    }
  }

  Future<void> _replaceController(NiumaMediaSource source) async {
    final previous = _controller;

    _unbindController();
    _controller = null;

    if (previous != null) {
      try {
        await previous.pause();
      } catch (_) {}

      try {
        await previous.dispose();
      } catch (_) {}
    }

    _resetPlaybackState();

    _createController(source);
  }

  void _resetPlaybackState() {
    _widthSubject.add(null);
    _heightSubject.add(null);
    _playingSubject.add(false);
    _loadingSubject.add(false);
    _completeSubject.add(false);
  }

  @override
  Widget getVideoWidget(BoxFit boxfit) {
    if (_isAudioOnly) {
      return const SizedBox.shrink();
    }

    final controller = _controller;

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return NiumaPlayerView(controller);
  }

  @override
  Future<void> play() async {
    if (_disposed) {
      return;
    }

    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) {
      return;
    }

    await _controller?.pause();
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    final controller = _controller;

    if (controller == null) {
      return;
    }

    await controller.pause();

    _playingSubject.add(false);
  }

  @override
  Future<void> softStop() async {
    if (_disposed) {
      return;
    }

    try {
      await _controller?.pause();
    } catch (_) {}

    _setState(state: PlayerState.idle, loading: false, playing: false, complete: false);
  }

  @override
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_disposed || _isAudioOnly == audioOnly) {
      return;
    }

    _isAudioOnly = audioOnly;
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_disposed) {
      return;
    }

    final value = volume.clamp(0.0, 1.0);

    await _controller?.setVolume(value);
  }

  @override
  Future<void> hardDispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _unbindController();

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      try {
        await controller.pause();
      } catch (_) {}

      try {
        await controller.dispose();
      } catch (_) {}
    }

    _initialized = false;

    await _stateSubject.close();
    await _playingSubject.close();
    await _loadingSubject.close();
    await _errorSubject.close();
    await _completeSubject.close();
    await _widthSubject.close();
    await _heightSubject.close();
  }

  void _emitError(PlayerException exception) {
    if (_disposed || _errorSubject.isClosed) {
      return;
    }

    _errorSubject.add(exception);
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('NiumaPlayerAdapter has been disposed');
    }
  }

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlayingNow {
    return _controller?.value.isPlaying ?? false;
  }

  @override
  bool get isReusable => !_disposed;

  @override
  Stream<PlayerState> get onStateChanged {
    return _stateSubject.stream;
  }

  @override
  Stream<bool> get onPlaying {
    return _playingSubject.stream;
  }

  @override
  Stream<PlayerException> get onError {
    return _errorSubject.stream;
  }

  @override
  Stream<bool> get onLoading {
    return _loadingSubject.stream;
  }

  @override
  Stream<bool> get onComplete {
    return _completeSubject.stream;
  }

  @override
  Stream<int?> get width {
    return _widthSubject.stream;
  }

  @override
  Stream<int?> get height {
    return _heightSubject.stream;
  }

  @override
  PlayerEngine get engine {
    return PlayerEngine.niuma;
  }

  @override
  NiumaPlayerController get niumaController {
    final controller = _controller;

    if (controller == null) {
      throw StateError('NiumaPlayerController has not been created');
    }

    return controller;
  }
}
