import 'package:get/get.dart';
import 'dart:developer' as dev;
import 'package:rxdart/rxdart.dart';
import 'unified_player_interface.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/fijk_helper.dart';
import 'package:pure_live/player/player_consts.dart';

class FijkPlayerAdapter implements UnifiedPlayer {
  final FijkPlayer _player = FijkPlayer();

  // Subjects — all properly typed and seeded
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _errorSubject = BehaviorSubject<String?>.seeded(null);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);
  final _widthSubject = BehaviorSubject<int?>.seeded(null);
  final _heightSubject = BehaviorSubject<int?>.seeded(null);
  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  bool _isPlaying = false;
  bool isInitialized = false;
  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_disposed) return;
    _player.addListener(_playerListener);
  }

  void _playerListener() {
    if (_disposed) return;

    final state = _player.state;

    // Update playing state
    final isPlaying = state == FijkState.started;
    if (_isPlaying != isPlaying) {
      _isPlaying = isPlaying;
      if (!_playingSubject.isClosed && _playingSubject.value != isPlaying) {
        _playingSubject.add(isPlaying);
      }
    }

    // Handle completion
    if (state == FijkState.completed) {
      dev.log('FijkPlayer: The video is completed');
      if (!_completeSubject.isClosed) {
        _completeSubject.add(true);
      }
    }

    // First-time initialization (set volume, etc.)
    if (!isInitialized && (state == FijkState.prepared || state == FijkState.started)) {
      isInitialized = true;
    }

    // Handle errors
    if (state == FijkState.error) {
      final errorMsg = _player.value.exception.message ?? 'Unknown FijkPlayer error';
      dev.log('FijkPlayer error: $errorMsg');
      SmartDialog.showToast('播放器错误: $errorMsg');
      if (!_errorSubject.isClosed) {
        _errorSubject.add('FijkPlayer error: $errorMsg');
      }
    }

    // Loading state
    final isLoading = state == FijkState.asyncPreparing || state == FijkState.initialized;
    if (!_loadingSubject.isClosed && _loadingSubject.value != isLoading) {
      _loadingSubject.add(isLoading);
    }

    // Video size (width/height)
    if (state == FijkState.prepared || state == FijkState.started || state == FijkState.paused) {
      final size = _player.value.size;
      if (size != null) {
        final w = size.width.toInt();
        final h = size.height.toInt();
        if (!_widthSubject.isClosed && _widthSubject.value != w) {
          _widthSubject.add(w);
        }
        if (!_heightSubject.isClosed && _heightSubject.value != h) {
          _heightSubject.add(h);
        }
      }
    }
  }

  @override
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed) return;
    final SettingsService settings = Get.find<SettingsService>();
    await _player.reset();
    await FijkHelper.setFijkOption(_player, enableCodec: settings.enableCodec.value, headers: headers);
    await _player.setDataSource(url, autoPlay: true);
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    await _player.start();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
  }

  @override
  Widget getVideoWidget(int index, Widget? controls) {
    return FijkView(
      player: _player,
      fit: FijkHelper.getIjkBoxFit(PlayerConsts.videofitList[index]),
      fs: false,
      color: Colors.black,
      panelBuilder: (FijkPlayer fijkPlayer, FijkData fijkData, BuildContext context, Size viewSize, Rect texturePos) {
        return Container();
      },
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Remove listener first
    _player.removeListener(_playerListener);

    // Close all subjects
    _playingSubject.close();
    _errorSubject.close();
    _loadingSubject.close();
    _widthSubject.close();
    _heightSubject.close();
    _completeSubject.close();

    // Release player (only once)
    try {
      _player.release();
    } catch (e) {
      debugPrint('FijkPlayerAdapter dispose error: $e');
    }
  }

  // UnifiedPlayer interface
  @override
  Stream<bool> get onPlaying => _playingSubject.stream;

  @override
  Stream<String?> get onError => _errorSubject.stream;

  @override
  Stream<bool> get onLoading => _loadingSubject.stream;

  @override
  bool get isPlayingNow => _isPlaying;

  @override
  Stream<int?> get width => _widthSubject.stream;

  @override
  Stream<int?> get height => _heightSubject.stream;

  @override
  Stream<bool> get onComplete => _completeSubject.stream;

  @override
  Future<void> setVolume(double value) async {
    // FijkPlayer uses 0.0 ~ 1.0
    if (_disposed) return;
    final vol = value.clamp(0.0, 1.0);
    await _player.setVolume(vol);
  }

  @override
  void stop() {
    if (_disposed) return;
    _player.stop();
  }

  @override
  void release() {
    dispose(); // delegate to dispose to avoid double-release
  }
}
