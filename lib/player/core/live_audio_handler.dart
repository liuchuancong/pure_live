import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/player/core/background_playback_service.dart';
import 'package:pure_live/player/core/background_playback_policy.dart';
import 'package:pure_live/common/services/settings_service.dart';

class LiveAudioHandler extends BaseAudioHandler {
  UnifiedPlayer? _currentPlayer; // 动态绑定
  late AudioSession _session;
  late final Future<void> _sessionReady;

  StreamSubscription? _playStateSubscription;
  Timer? _sleepTimer;
  LiveAudioHandler() {
    _sessionReady = _initSession();
  }

  Future<void> setPlayer(UnifiedPlayer player) async {
    await _playStateSubscription?.cancel();
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
      final keepAlive =
          playing &&
          BackgroundPlaybackPolicy.shouldContinue(
            backgroundPlaybackEnabled: SettingsService.to.app.enableBackgroundPlay.value,
            sleepSessionActive: BackgroundPlaybackService.sleepSessionActive,
            audioOnlySessionActive: BackgroundPlaybackService.audioOnlySessionActive,
          );
      unawaited(BackgroundPlaybackService.setKeepAlive(keepAlive));
      playbackState.add(
        playbackState.value.copyWith(
          controls: [playing ? MediaControl.pause : MediaControl.play, MediaControl.stop],
          // 单直播流不存在上一首/下一首，保留播放与停止即可，避免生成
          // 无实际处理器的通知栏动作，也让紧凑通知的索引始终有效。
          androidCompactActionIndices: const [0, 1],
          playing: playing,
          processingState: AudioProcessingState.ready,
        ),
      );
    });
  }

  void configureSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null || duration <= Duration.zero) return;
    _sleepTimer = Timer(duration, () async {
      BackgroundPlaybackService.sleepSessionActive = false;
      await stop();
    });
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  /// Claims media audio focus as soon as playback starts in the room. Waiting
  /// until the notification play action is pressed makes Android pause the
  /// already-running stream when the app first goes to the background.
  Future<void> activateSession() async {
    await _sessionReady;
    await _session.setActive(true);
  }

  @override
  Future<void> play() async {
    if (_currentPlayer == null) return;
    await activateSession();
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

    BackgroundPlaybackService.sleepSessionActive = false;
    BackgroundPlaybackService.audioOnlySessionActive = false;
    _sleepTimer?.cancel();
    _sleepTimer = null;

    try {
      await _currentPlayer!.stop();
    } catch (e) {
      developer.log("Player already disposed or failed to stop: $e");
    } finally {
      await _sessionReady;
      await _session.setActive(false);
      await BackgroundPlaybackService.setKeepAlive(false);
      playbackState.add(playbackState.value.copyWith(playing: false, processingState: AudioProcessingState.idle));
    }
  }
}
