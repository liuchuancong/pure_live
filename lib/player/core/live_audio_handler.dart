import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/player/core/background_playback_policy.dart';
import 'package:pure_live/player/core/background_playback_service.dart';
import 'package:pure_live/player/core/playback_lifecycle_coordinator.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

class LiveAudioHandler extends BaseAudioHandler {
  UnifiedPlayer? _currentPlayer; // 动态绑定
  late AudioSession _session;
  late final Future<void> _sessionReady;

  StreamSubscription? _playStateSubscription;
  Timer? _sleepTimer;
  Future<void> _audioEventQueue = Future<void>.value();
  PlaybackLifecyclePauseToken? _interruptionToken;
  Future<void> Function()? _playCommand;
  Future<void> Function()? _pauseCommand;
  Future<void> Function()? _stopCommand;
  Future<PlaybackLifecyclePauseToken?> Function()? _pauseForInterruption;
  Future<bool> Function(PlaybackLifecyclePauseToken token)? _resumeFromInterruption;

  LiveAudioHandler() {
    _sessionReady = _initSession();
  }

  Future<void> setPlayer(UnifiedPlayer player) async {
    await _playStateSubscription?.cancel();
    _interruptionToken = null;
    _currentPlayer = player;
    _listenPlayState();
  }

  void configurePlaybackCommands({
    required Future<void> Function() play,
    required Future<void> Function() pause,
    required Future<void> Function() stop,
    required Future<PlaybackLifecyclePauseToken?> Function() pauseForInterruption,
    required Future<bool> Function(PlaybackLifecyclePauseToken token) resumeFromInterruption,
  }) {
    _playCommand = play;
    _pauseCommand = pause;
    _stopCommand = stop;
    _pauseForInterruption = pauseForInterruption;
    _resumeFromInterruption = resumeFromInterruption;
  }

  void _enqueueAudioEvent(Future<void> Function() operation) {
    _audioEventQueue = _audioEventQueue.then((_) => operation()).catchError((Object error, StackTrace stackTrace) {
      developer.log('Audio session event failed: $error', stackTrace: stackTrace);
    });
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
            _enqueueAudioEvent(() async {
              if (_interruptionToken != null) return;
              final pauseForInterruption = _pauseForInterruption;
              if (pauseForInterruption != null) {
                _interruptionToken = await pauseForInterruption();
              } else {
                await _currentPlayer?.pause();
              }
            });
            break;
          case AudioInterruptionType.unknown:
            break;
          case AudioInterruptionType.duck:
            _currentPlayer!.setVolume(0.2);
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
            _enqueueAudioEvent(() async {
              final token = _interruptionToken;
              _interruptionToken = null;
              final resumeFromInterruption = _resumeFromInterruption;
              if (token != null && resumeFromInterruption != null) {
                await resumeFromInterruption(token);
              } else if (resumeFromInterruption == null) {
                await _currentPlayer?.play();
              }
            });
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
    _session.becomingNoisyEventStream.listen((_) {
      _enqueueAudioEvent(() async {
        _interruptionToken = null;
        final pauseCommand = _pauseCommand;
        if (pauseCommand != null) {
          await pauseCommand();
        } else {
          await _currentPlayer?.pause();
        }
      });
    });
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
    final playCommand = _playCommand;
    await (playCommand != null ? playCommand() : _currentPlayer!.play());
  }

  @override
  Future<void> pause() async {
    if (_currentPlayer == null) return;
    final pauseCommand = _pauseCommand;
    await (pauseCommand != null ? pauseCommand() : _currentPlayer!.pause());
  }

  @override
  Future<void> stop() async {
    final stopCommand = _stopCommand;
    if (stopCommand != null) {
      await stopCommand();
      return;
    }
    await releasePlayer();
  }

  Future<void> releasePlayer() async {
    if (_currentPlayer == null) return;

    BackgroundPlaybackService.sleepSessionActive = false;
    BackgroundPlaybackService.audioOnlySessionActive = false;
    _interruptionToken = null;

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
