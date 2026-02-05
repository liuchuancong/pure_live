import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';
import 'unified_player_interface.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/player_consts.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MediaKitPlayerAdapter implements UnifiedPlayer {
  late Player _player;
  late VideoController _controller;
  final SettingsService settings = Get.find<SettingsService>();

  // Subjects with correct types
  final _playingSubject = BehaviorSubject<bool>.seeded(false);
  final _errorSubject = BehaviorSubject<String?>.seeded(null);
  final _loadingSubject = BehaviorSubject<bool>.seeded(false);
  final _widthSubject = BehaviorSubject<int?>.seeded(null); // ✅ int?
  final _heightSubject = BehaviorSubject<int?>.seeded(null); // ✅ int?
  final _completeSubject = BehaviorSubject<bool>.seeded(false);

  bool _isPlaying = false;
  bool isInitialized = false;
  bool _disposed = false;

  // Stream subscriptions — use correct generic types
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<int?>? _widthSub; // ✅ int?
  StreamSubscription<int?>? _heightSub; // ✅ int?

  @override
  Future<void> init() async {
    if (_disposed) return;

    _isPlaying = false;
    isInitialized = false;
    _disposed = false;

    _player = Player();
    if (settings.customPlayerOutput.value) {
      if (_player.platform is NativePlayer) {
        await (_player.platform as dynamic).setProperty('ao', settings.audioOutputDriver.value);
      }
    }
    // Platform-specific configuration
    if (Platform.isAndroid) {
      final pp = _player.platform as NativePlayer;
      await pp.setProperty('force-seekable', 'yes');
    }
    if (_player.platform is NativePlayer) {
      if (_player.platform is NativePlayer) {
        final native = _player.platform as dynamic;

        // 1. 设置协议白名单
        await native.setProperty('protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto');

        // 2. 合并设置 demuxer 参数 (用逗号分隔，不要分两次 set)
        // 这样同时开启了重连和 5 秒超时
        // Optimized reconnection parameters
        await native.setproperty(
          'demuxer-lavf-o',
          'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_on_http_error=4xx,5xx,timeout=5000000',
        );
        await native.setproperty('stream-lavf-o', 'reconnect_streamed=1,reconnect_delay_max=5');
      }
    }

    // Initialize controller based on settings
    _controller = settings.playerCompatMode.value
        ? VideoController(
            _player,
            configuration: VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec'),
          )
        : settings.customPlayerOutput.value
        ? VideoController(
            _player,
            configuration: VideoControllerConfiguration(
              vo: settings.videoOutputDriver.value,
              hwdec: settings.videoHardwareDecoder.value,
            ),
          )
        : VideoController(
            _player,
            configuration: VideoControllerConfiguration(
              enableHardwareAcceleration: settings.enableCodec.value,
              androidAttachSurfaceAfterVideoParameters: false,
            ),
          );

    // Listen to player streams
    _playingSub = _player.stream.playing.listen((playing) {
      if (_disposed || _playingSubject.isClosed) return;
      _isPlaying = playing;
      if (_playingSubject.value != playing) {
        _playingSubject.add(playing);
      }

      if (!isInitialized) {
        isInitialized = true;
      }
    });

    _errorSub = _player.stream.error.listen((error) {
      if (_disposed || _errorSubject.isClosed) return;
      final msg = 'MediaKitPlayer error: $error';
      SmartDialog.showToast(msg);
      _errorSubject.add(msg);
    });

    _completedSub = _player.stream.completed.listen((isComplete) {
      if (_disposed || _completeSubject.isClosed) return;
      if (isComplete) {
        _completeSubject.add(true);
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (_disposed || _loadingSubject.isClosed) return;
      if (_loadingSubject.value != buffering) {
        _loadingSubject.add(buffering);
      }
    });

    _widthSub = _player.stream.width.listen((w) {
      if (_disposed || _widthSubject.isClosed) return;
      if (_widthSubject.value != w) {
        _widthSubject.add(w);
      }
    });

    _heightSub = _player.stream.height.listen((h) {
      if (_disposed || _heightSubject.isClosed) return;
      if (_heightSubject.value != h) {
        _heightSubject.add(h);
      }
    });
  }

  @override
  Future<void> setDataSource(String url, Map<String, String> headers) async {
    if (_disposed) return;
    await _player.stop();
    await _player.open(Media(url, httpHeaders: headers));
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
  }

  @override
  Widget getVideoWidget(int index, Widget? controls) {
    return Video(
      key: UniqueKey(),
      controller: _controller,
      pauseUponEnteringBackgroundMode: !settings.enableBackgroundPlay.value,
      resumeUponEnteringForegroundMode: !settings.enableBackgroundPlay.value,
      fit: PlayerConsts.videofitList[index],
      controls: NoVideoControls,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Cancel all stream subscriptions
    _playingSub?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _bufferingSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();

    // Close all subjects
    _playingSubject.close();
    _errorSubject.close();
    _loadingSubject.close();
    _widthSubject.close();
    _heightSubject.close();
    _completeSubject.close();

    // Dispose the player
    try {
      _player.dispose();
    } catch (e) {
      debugPrint('MediaKitPlayerAdapter dispose error: $e');
    }
  }

  // UnifiedPlayer interface implementations
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
    if (_disposed) return;
    final vol = (value * 100).clamp(0.0, 100.0);
    await _player.setVolume(vol);
  }

  @override
  void stop() {
    if (_disposed) return;
    _player.stop();
  }

  @override
  void release() {
    dispose();
  }
}
