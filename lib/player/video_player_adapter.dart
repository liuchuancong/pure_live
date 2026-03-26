import 'package:get/get.dart';
import 'dart:developer' as dev;
import 'package:rxdart/rxdart.dart';
import 'unified_player_interface.dart';
import 'package:pure_live/common/index.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pure_live/player/audio_service.dart';
import 'package:pure_live/player/player_consts.dart';

class VideoPlayerAdapter implements UnifiedPlayer {
  // 使用可空类型，防止未初始化时调用报错
  VideoPlayerController? _player;
  @override
  VideoPlayerController? get lowLevelPlayer => _player;
  // Subjects — 保持和原实现一致
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _errorSubject = BehaviorSubject<String?>.seeded(null);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);
  final _widthSubject = BehaviorSubject<int?>.seeded(null);
  final _heightSubject = BehaviorSubject<int?>.seeded(null);
  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  bool _isPlaying = false;
  bool _disposed = false;
  static late MyAudioHandler _audioHandler;
  @override
  Future<void> init() async {
    // 初始化 audio_service
    initAudioService();
  }

  Future<void> initAudioService() async {
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mystyle.purelive',
        androidNotificationChannelName: 'Media Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true, // 暂停时自动尝试停止前台通知
        notificationColor: Colors.transparent, // 尽量淡化
      ),
    );
  }

  void _playerListener() {
    if (_disposed || _player == null || !_player!.value.isInitialized) return;

    final state = _player!.value;

    // 1. 更新播放状态
    if (_isPlaying != state.isPlaying) {
      _isPlaying = state.isPlaying;
      _playingSubject.add(_isPlaying);
      _audioHandler.updateState(_isPlaying);
    }

    // 2. 处理播放完成
    if (state.position >= state.duration && state.duration > Duration.zero) {
      if (!_completeSubject.value) _completeSubject.add(true);
    }

    // 3. 处理错误
    if (state.hasError) {
      final errorMsg = state.errorDescription ?? 'Unknown VideoPlayer error';
      dev.log('VideoPlayer error: $errorMsg');
      _errorSubject.add(errorMsg);
    }

    // 4. 加载状态 (Buffering)
    _loadingSubject.add(state.isBuffering);

    // 5. 更新视频尺寸 (用于触发 UI 刷新)
    final w = state.size.width.toInt();
    final h = state.size.height.toInt();
    if (_widthSubject.value != w) _widthSubject.add(w);
    if (_heightSubject.value != h) _heightSubject.add(h);
  }

  @override
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed) return;

    // 停止并销毁旧实例
    if (_player != null) {
      _player!.removeListener(_playerListener);
      await _player!.dispose();
      _player = null;
    }

    try {
      _loadingSubject.add(true);
      var settings = Get.find<SettingsService>();
      _player = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: settings.enableBackgroundPlay.value,
        ),
      );

      _player!.addListener(_playerListener);

      // 等待初始化完成
      await _player!.initialize();

      if (!_disposed && _player != null) {
        await _player!.play();
        _completeSubject.add(false);
        _errorSubject.add(null);
      }
      _audioHandler.mediaItem.add(MediaItem(id: url, album: 'PureLive', title: '直播中'));
    } catch (e) {
      dev.log('VideoPlayer setDataSource error: $e');
      _errorSubject.add(e.toString());
      SmartDialog.showToast('播放器初始化失败');
    } finally {
      _loadingSubject.add(false);
    }
  }

  @override
  Widget getVideoWidget(int index, Widget? controls) {
    final boxFit = PlayerConsts.videofitList[index];

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: boxFit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _player!.value.size.width,
                height: _player!.value.size.height,
                child: VideoPlayer(_player!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> play() async => await _player?.play();

  @override
  Future<void> pause() async => await _player?.pause();

  @override
  void stop() {
    _player?.pause();
    _audioHandler.stop();
    _player?.seekTo(Duration.zero);
  }

  @override
  Future<void> setVolume(double value) async {
    await _player?.setVolume(value.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _player?.removeListener(_playerListener);
    _player?.dispose();

    _playingSubject.close();
    _errorSubject.close();
    _loadingSubject.close();
    _widthSubject.close();
    _heightSubject.close();
    _completeSubject.close();
  }

  @override
  void release() => dispose();

  // UnifiedPlayer 接口实现
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
}
