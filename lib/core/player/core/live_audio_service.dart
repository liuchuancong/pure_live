import 'dart:async';

import 'dart:io';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/core/background_playback_policy.dart';
import 'package:pure_live/core/player/core/background_playback_service.dart';
import 'package:pure_live/core/player/core/playback_lifecycle_coordinator.dart';
import 'package:pure_live/core/config/app_settings_controller.dart';

class LiveAudioService {
  LiveAudioService._();

  static Timer? _sleepTimer;
  static int _sleepMinutes = 60;
  static Future<void> Function()? _pauseCommand;

  static bool get isSleepSessionActive => BackgroundPlaybackService.sleepSessionActive;

  static bool get shouldContinueInBackground => BackgroundPlaybackPolicy.shouldContinue(
    backgroundPlaybackEnabled: SettingsService.to.app.enableBackgroundPlay.v,
    sleepSessionActive: isSleepSessionActive,
    audioOnlySessionActive: BackgroundPlaybackService.audioOnlySessionActive,
  );

  static void configurePlaybackCommands({
    required Future<void> Function() play,
    required Future<void> Function() pause,
    required Future<void> Function() stop,
    required Future<PlaybackLifecyclePauseToken?> Function() pauseForInterruption,
    required Future<bool> Function(PlaybackLifecyclePauseToken token) resumeFromInterruption,
  }) {
    _pauseCommand = pause;
  }

  static Future<void> setPlayer(
    dynamic player, {
    required bool audioOnly,
    int? sessionId,
    bool Function()? isSourceCurrent,
    double Function()? targetVolume,
  }) async {
    if (isSourceCurrent?.call() == false) return;
    BackgroundPlaybackService.audioOnlySessionActive = audioOnly;
    await syncKeepAlive();
  }

  static Future<void> start(String roomId, String title, String author, String? cover) async {
    if (BackgroundPlaybackService.sleepSessionActive) {
      _armSleepTimer();
    }
    await syncKeepAlive();
  }

  static Future<void> stop() async {
    _cancelSleepTimer();
    await syncKeepAlive();
  }

  static Future<void> configureSleepTimer({required bool enabled, required int minutes}) async {
    _sleepMinutes = minutes.clamp(1, AppSettingsController.maxSleepMinutes).toInt();
    BackgroundPlaybackService.sleepSessionActive = enabled;
    if (enabled) {
      _armSleepTimer();
    } else {
      _cancelSleepTimer();
    }
  }

  static void _armSleepTimer() {
    _cancelSleepTimer();
    _sleepTimer = Timer(Duration(minutes: _sleepMinutes), () {
      BackgroundPlaybackService.sleepSessionActive = false;
      unawaited(_pauseCommand?.call());
    });
  }

  static void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  static Future<void> configureBackgroundPlayback({required bool enabled}) {
    return BackgroundPlaybackService.setKeepAlive(enabled);
  }

  static Future<void> syncKeepAlive() {
    return configureBackgroundPlayback(enabled: SettingsService.to.app.enableBackgroundPlay.v);
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
