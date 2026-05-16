import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

class LiveAudioHandler extends BaseAudioHandler {
  UnifiedPlayer? _currentPlayer; // 动态绑定
  late AudioSession _session;
  StreamSubscription? _playStateSubscription;
  LiveAudioHandler() {
    _initSession();
  }

  void setPlayer(UnifiedPlayer player) {
    _currentPlayer = player;
    _listenPlayState();
  }

  Future<void> _initSession() async {
    _session = await AudioSession.instance;
    await _session.configure(const AudioSessionConfiguration.music());

    // 音频中断（来电、通知）
    _session.interruptionEventStream.listen((event) {
      if (_currentPlayer == null) return;
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
          case AudioInterruptionType.duck:
            _currentPlayer!.setVolume(0.2);
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
            play();
            break;
          case AudioInterruptionType.duck:
            _currentPlayer!.setVolume(1.0);
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // 拔掉耳机 / 连接蓝牙音箱暂停
    _session.becomingNoisyEventStream.listen((_) => pause());
  }

  /// 监听播放状态同步到通知栏
  void _listenPlayState() {
    if (_currentPlayer == null) return;
    _playStateSubscription?.cancel();
    _playStateSubscription = _currentPlayer!.onPlaying.listen((playing) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: [playing ? MediaControl.pause : MediaControl.play, MediaControl.stop],
          androidCompactActionIndices: const [0, 1],
          playing: playing,
          processingState: AudioProcessingState.ready,
        ),
      );
    });
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> play() async {
    if (_currentPlayer == null) return;
    await _session.setActive(true);
    await _currentPlayer!.play();
  }

  @override
  Future<void> pause() async {
    if (_currentPlayer == null) return;
    await _currentPlayer!.pause();
  }

  @override
  Future<void> stop() async {
    if (_currentPlayer == null) return;

    try {
      await _currentPlayer!.stop();
    } catch (e) {
      developer.log("Player already disposed or failed to stop: $e");
    } finally {
      await _session.setActive(false);
      playbackState.add(playbackState.value.copyWith(playing: false, processingState: AudioProcessingState.idle));
    }
  }
}
