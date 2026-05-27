import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pure_live/player/core/live_audio_handler.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

class LiveAudioService {
  static LiveAudioHandler? _handler;
  static bool _isInitializing = false;

  static Future<LiveAudioHandler?> _ensureInitialized() async {
    if (_handler != null) return _handler;
    if (_isInitializing) {
      while (_handler == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _handler;
    }

    _isInitializing = true;
    try {
      _handler = await AudioService.init(
        builder: () => LiveAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.mystyle.purelive.audio',
          androidNotificationChannelName: i18n("audio_channel_name"),
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationClickStartsActivity: true,
          notificationColor: Colors.blue,
        ),
      );
    } finally {
      _isInitializing = false;
    }
    return _handler;
  }

  static void setPlayer(UnifiedPlayer player) async {
    final handler = await _ensureInitialized();
    handler?.setPlayer(player);
  }

  static Future<void> start(String roomId, String title, String author, String? cover) async {
    final handler = await _ensureInitialized();
    if (handler == null) return;

    final item = MediaItem(
      id: roomId,
      album: i18n("app_name"),
      title: title,
      artist: author,
      artUri: (cover != null && cover.isNotEmpty) ? Uri.tryParse(cover) : null,
    );

    await handler.playMediaItem(item);
  }

  static Future<void> stop() async {
    if (_handler == null) return;
    await _handler!.stop();
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
