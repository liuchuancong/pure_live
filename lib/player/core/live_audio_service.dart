import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pure_live/player/core/live_audio_handler.dart';
import 'package:pure_live/player/interface/unified_player_interface.dart';

class LiveAudioService {
  static LiveAudioHandler? _handler;
  static bool _isInitializing = false;

  static Future<LiveAudioHandler?> _ensureInitialized() async {
    if (!Platform.isAndroid) return null;
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
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.mystyle.purelive.audio',
          androidNotificationChannelName: '纯粹直播播放',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationClickStartsActivity: true,
          // 增加一个默认图标（确保在 AndroidManifest 中有对应的 ic_launcher）
          notificationColor: Colors.blue,
        ),
      );
    } finally {
      _isInitializing = false;
    }
    return _handler;
  }

  /// 关联播放器实例
  static void setPlayer(UnifiedPlayer player) async {
    final handler = await _ensureInitialized();
    handler?.setPlayer(player);
  }

  static Future<void> start(String roomId, String title, String author, String? cover) async {
    if (!Platform.isAndroid) return;

    final handler = await _ensureInitialized();
    if (handler == null) return;

    // 2. 构造媒体信息
    final item = MediaItem(
      id: roomId,
      album: "纯粹直播",
      title: title,
      artist: author,
      artUri: (cover != null && cover.isNotEmpty) ? Uri.tryParse(cover) : null,
    );

    await handler.playMediaItem(item);
  }

  /// 停止服务并销毁通知
  static Future<void> stop() async {
    if (!Platform.isAndroid || _handler == null) return;
    await _handler!.stop();
  }

  /// 权限请求逻辑
  static Future<bool> requestPlatformPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. 通知权限
    if (await Permission.notification.status != PermissionStatus.granted) {
      bool confirm = await _showExplainDialog(title: "需要通知权限", content: "为了在后台播放时显示控制条并防止直播中断，我们需要开启通知权限。");
      if (confirm) await Permission.notification.request();
      if (await Permission.notification.status != PermissionStatus.granted) return false;
    }

    // 2. 电池优化 (提高后台存活率)
    if (await Permission.ignoreBatteryOptimizations.status != PermissionStatus.granted) {
      bool confirm = await _showExplainDialog(title: "需要忽略电池优化", content: "开启此选项能确保直播在手机锁屏或后台时不会被强制关闭。");
      if (confirm) await Permission.ignoreBatteryOptimizations.request();
    }
    return true;
  }

  /// 解释弹窗
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(content, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => SmartDialog.dismiss(), child: const Text("取消")),
                ElevatedButton(
                  onPressed: () {
                    isConfirm = true;
                    SmartDialog.dismiss();
                  },
                  child: const Text("去开启"),
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
