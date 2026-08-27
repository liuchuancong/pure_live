import 'dart:io';

import 'package:pure_live/common/index.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/player/core/live_audio_handler.dart';
import 'package:pure_live/player/core/background_playback_policy.dart';
import 'package:pure_live/player/core/background_playback_service.dart';
import 'package:pure_live/player/core/playback_lifecycle_coordinator.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';

class LiveAudioService {
  static LiveAudioHandler? _handler;
  static UnifiedPlayer? _boundPlayer;
  static Future<LiveAudioHandler?>? _initializationFuture;
  static int _sleepMinutes = 60;
  static Future<void> Function()? _playCommand;
  static Future<void> Function()? _pauseCommand;
  static Future<void> Function()? _stopCommand;
  static Future<PlaybackLifecyclePauseToken?> Function()? _pauseForInterruption;
  static Future<bool> Function(PlaybackLifecyclePauseToken token)? _resumeFromInterruption;

  static bool get isSleepSessionActive => BackgroundPlaybackService.sleepSessionActive;

  static bool get shouldContinueInBackground => BackgroundPlaybackPolicy.shouldContinue(
    backgroundPlaybackEnabled: SettingsService.to.app.enableBackgroundPlay.v,
    sleepSessionActive: BackgroundPlaybackService.sleepSessionActive,
    audioOnlySessionActive: BackgroundPlaybackService.audioOnlySessionActive,
  );

  static Future<LiveAudioHandler?> _ensureInitialized() async {
    if (_handler != null) return _handler;
    final inFlight = _initializationFuture;
    if (inFlight != null) return inFlight;

    final initialization = _initializeHandler();
    _initializationFuture = initialization;
    try {
      return await initialization;
    } finally {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    }
  }

  static Future<LiveAudioHandler?> _initializeHandler() async {
    final handler = await AudioService.init(
      builder: () => LiveAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.mystyle.purelive.audio',
        androidNotificationChannelName: i18n("audio_channel_name"),
        androidNotificationOngoing: true,
        // Keep the media foreground service alive across short interruptions
        // so screen-off playback can resume without recreating the process.
        androidStopForegroundOnPause: true,
        androidNotificationClickStartsActivity: true,
        notificationColor: Colors.blue,
      ),
    );
    _handler = handler;
    _applyPlaybackCommands(handler);
    return handler;
  }

  static void configurePlaybackCommands({
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
    final handler = _handler;
    if (handler != null) _applyPlaybackCommands(handler);
  }

  static void _applyPlaybackCommands(LiveAudioHandler handler) {
    final play = _playCommand;
    final pause = _pauseCommand;
    final stop = _stopCommand;
    final pauseForInterruption = _pauseForInterruption;
    final resumeFromInterruption = _resumeFromInterruption;
    if (play == null ||
        pause == null ||
        stop == null ||
        pauseForInterruption == null ||
        resumeFromInterruption == null) {
      return;
    }
    handler.configurePlaybackCommands(
      play: play,
      pause: pause,
      stop: stop,
      pauseForInterruption: pauseForInterruption,
      resumeFromInterruption: resumeFromInterruption,
    );
  }

  static Future<void> setPlayer(UnifiedPlayer player, {required bool audioOnly}) async {
    BackgroundPlaybackService.audioOnlySessionActive = audioOnly;
    if (PlatformUtils.isMobile || PlatformUtils.isMacOS) {
      final handler = await _ensureInitialized();
      if (handler != null && !identical(_boundPlayer, player)) {
        await handler.setPlayer(player);
        _boundPlayer = player;
      }
    }
    await syncKeepAlive();
  }

  static Future<void> start(String roomId, String title, String author, String? cover) async {
    if (!PlatformUtils.isMobile && !PlatformUtils.isMacOS) return;
    final handler = await _ensureInitialized();
    if (handler == null) return;

    final item = buildMediaItem(roomId: roomId, title: title, author: author, cover: cover);

    try {
      await handler.activateSession();
    } catch (error, stackTrace) {
      // Audio focus improves background continuity, but a vendor-specific
      // session failure must not turn an otherwise playable room into an
      // application-level playback failure.
      debugPrint('Audio session activation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    await handler.playMediaItem(item);
    handler.configureSleepTimer(BackgroundPlaybackService.sleepSessionActive ? Duration(minutes: _sleepMinutes) : null);
    await syncKeepAlive();
  }

  static MediaItem buildMediaItem({
    required String roomId,
    required String title,
    required String author,
    String? cover,
  }) {
    return MediaItem(
      id: roomId,
      album: i18nOr("app_name", "PureLive"),
      title: title,
      artist: author,
      artUri: (cover != null && cover.isNotEmpty) ? Uri.tryParse(cover) : null,
    );
  }

  static Future<void> configureSleepTimer({required bool enabled, required int minutes}) async {
    _sleepMinutes = minutes.clamp(1, AppSettingsController.maxSleepMinutes).toInt();
    BackgroundPlaybackService.sleepSessionActive = enabled;
    _handler?.configureSleepTimer(enabled ? Duration(minutes: _sleepMinutes) : null);
    await syncKeepAlive();
  }

  static Future<void> stop() async {
    BackgroundPlaybackService.sleepSessionActive = false;
    BackgroundPlaybackService.audioOnlySessionActive = false;
    if (_handler == null) return;
    if (!PlatformUtils.isMobile && !PlatformUtils.isMacOS) return;
    await _handler!.releasePlayer();
    _boundPlayer = null;
  }

  static Future<void> releaseKeepAlive() => BackgroundPlaybackService.setKeepAlive(false);

  static Future<void> syncKeepAlive() {
    final shouldKeepAlive = (_handler?.playbackState.value.playing ?? false) && shouldContinueInBackground;
    return BackgroundPlaybackService.setKeepAlive(shouldKeepAlive);
  }

  static Future<bool> requestPlatformPermissions() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.notification.status != PermissionStatus.granted) {
      bool confirm = await _showExplainDialog(
        title: i18n("permission_notification_title"),
        content: i18n("permission_notification_content"),
      );
      if (confirm) await Permission.notification.request();
      if (await Permission.notification.status != PermissionStatus.granted) return false;
    }

    if (await Permission.ignoreBatteryOptimizations.status != PermissionStatus.granted) {
      bool confirm = await _showExplainDialog(
        title: i18n("permission_battery_title"),
        content: i18n("permission_battery_content"),
      );
      if (confirm) await Permission.ignoreBatteryOptimizations.request();
    }
    return true;
  }

  static Future<bool> _showExplainDialog({required String title, required String content}) async {
    bool isConfirm = false;
    await SmartDialog.show(
      builder: (context) => Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(content, textAlign: TextAlign.center, style: AppTextStyles.t14),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => SmartDialog.dismiss(), child: Text(i18n("permission_cancel"))),
                ElevatedButton(
                  onPressed: () {
                    isConfirm = true;
                    SmartDialog.dismiss();
                  },
                  child: Text(i18n("permission_go_enable")),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return isConfirm;
  }
}
