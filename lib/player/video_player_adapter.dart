import 'package:get/get.dart';
import 'dart:developer' as dev;
import 'package:rxdart/rxdart.dart';
import 'unified_player_interface.dart';
import 'package:pure_live/common/index.dart';
import 'package:video_player/video_player.dart';
import 'package:pure_live/player/player_consts.dart';

class VideoPlayerAdapter implements UnifiedPlayer {
  // video_player 核心实例
  late VideoPlayerController _player;

  // 用于监听视频生命周期的一次性对象
  VoidCallback? _listener;

  // Subjects — 保持和原实现一致的类型和初始值
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
    // 初始化阶段不需要立即创建player，等待setDataSource
  }

  /// 播放器状态监听
  void _playerListener() {
    if (_disposed || !_player.value.isInitialized) return;

    final state = _player.value;

    // 更新播放状态
    final isPlaying = state.isPlaying;
    if (_isPlaying != isPlaying) {
      _isPlaying = isPlaying;
      if (!_playingSubject.isClosed && _playingSubject.value != isPlaying) {
        _playingSubject.add(isPlaying);
      }
    }

    // 处理播放完成
    if (state.position >= state.duration && state.duration > Duration.zero) {
      dev.log('VideoPlayer: The video is completed');
      if (!_completeSubject.isClosed && !_completeSubject.value) {
        _completeSubject.add(true);
      }
    }

    // 首次初始化完成
    if (!isInitialized && state.isInitialized) {
      isInitialized = true;
      dev.log('VideoPlayer: Initialized successfully');
    }

    // 处理错误
    if (state.hasError) {
      final errorMsg = state.errorDescription ?? 'Unknown VideoPlayer error';
      dev.log('VideoPlayer error: $errorMsg');
      SmartDialog.showToast('播放器错误: $errorMsg');
      if (!_errorSubject.isClosed) {
        _errorSubject.add('VideoPlayer error: $errorMsg');
      }
    }

    // 加载状态 (buffering)
    final isLoading = state.isBuffering;
    if (!_loadingSubject.isClosed && _loadingSubject.value != isLoading) {
      _loadingSubject.add(isLoading);
    }

    // 视频尺寸
    if (state.isInitialized) {
      final w = state.size.width.toInt();
      final h = state.size.height.toInt();
      if (!_widthSubject.isClosed && _widthSubject.value != w) {
        _widthSubject.add(w);
      }
      if (!_heightSubject.isClosed && _heightSubject.value != h) {
        _heightSubject.add(h);
      }
    }
  }

  @override
  Future<void> setDataSource(String url, List<String> playUrls, Map<String, String> headers) async {
    if (_disposed) return;

    // 重置之前的播放器
    if (_listener != null) {
      _player.removeListener(_listener!);
    }

    try {
      // 创建新的视频控制器
      _player = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers, // 设置请求头
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true, // 允许后台播放音频
        ),
      );

      // 添加状态监听
      _listener = _playerListener;
      _player.addListener(_listener!);

      // 初始化播放器
      await _player.initialize();

      // 自动播放（和原fijk实现保持一致）
      await _player.play();

      // 重置完成状态
      if (!_completeSubject.isClosed) {
        _completeSubject.add(false);
      }
    } catch (e) {
      dev.log('VideoPlayer setDataSource error: $e');
      if (!_errorSubject.isClosed) {
        _errorSubject.add('VideoPlayer init error: ${e.toString()}');
      }
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    if (_disposed || !_player.value.isInitialized) return;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed || !_player.value.isInitialized) return;
    await _player.pause();
  }

  @override
  Widget getVideoWidget(int index, Widget? controls) {
    if (!_player.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return FittedBox(
      fit: PlayerConsts.videofitList[index],
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _player.value.size.width,
        height: _player.value.size.height,
        child: AspectRatio(
          aspectRatio: _player.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [VideoPlayer(_player), if (controls != null) controls, Container()],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // 移除监听
    if (_listener != null) {
      _player.removeListener(_listener!);
      _listener = null;
    }

    // 关闭所有Subject
    _playingSubject.close();
    _errorSubject.close();
    _loadingSubject.close();
    _widthSubject.close();
    _heightSubject.close();
    _completeSubject.close();

    // 释放播放器资源
    try {
      _player.dispose();
    } catch (e) {
      dev.log('VideoPlayerAdapter dispose error: $e');
    }
  }

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

  @override
  Future<void> setVolume(double value) async {
    if (_disposed || !_player.value.isInitialized) return;
    // video_player 使用 0.0 ~ 1.0 的音量范围
    final vol = value.clamp(0.0, 1.0);
    _player.setVolume(vol);
  }

  @override
  void stop() {
    if (_disposed || !_player.value.isInitialized) return;
    _player.pause();
    _player.seekTo(Duration.zero); // 停止并重置到开始位置
  }

  @override
  void release() {
    dispose(); // 和原实现保持一致，委托给dispose
  }
}
