import 'dart:io';
import 'package:pure_live/common/index.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pure_live/common/global/platform/mobile_manager.dart';

class BackgroundService {
  static Future<void> startService(String title, String content) async {
    // 配置通知栏样式
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pure_live_service',
        channelName: 'Pure Live Background Service',
        channelDescription: 'This notification appears when the foreground service is running.',
        showWhen: true,
        priority: NotificationPriority.LOW,
      ),

      iosNotificationOptions: const IOSNotificationOptions(showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // 启动
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: content);
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: content,
        callback: startCallback,
        serviceId: 123,
        notificationIcon: const NotificationIcon(metaDataName: 'ic_notification'),
      );
    }
  }

  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<bool> requestPlatformPermissions() async {
    if (!Platform.isAndroid) return true;
    NotificationPermission notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      bool confirm = await _showExplainDialog(title: "需要通知权限", content: "为了在后台播放时显示控制条并防止直播中断，我们需要开启通知权限。");

      if (confirm) {
        await Permission.notification.request();
        notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      }

      if (notificationPermission != NotificationPermission.granted) return false;
    }

    bool isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!isIgnoring) {
      bool confirm = await _showExplainDialog(title: "需要忽略电池优化", content: "由于系统限制，开启此选项能确保直播在手机锁屏或后台时不会被强制关闭。");

      if (confirm) {
        isIgnoring = await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    }

    return isIgnoring && (notificationPermission == NotificationPermission.granted);
  }

  /// 通用的 SmartDialog 告知对话框
  static Future<bool> _showExplainDialog({required String title, required String content}) async {
    bool isConfirm = false;
    await SmartDialog.show(
      builder: (context) {
        return Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
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
        );
      },
    );
    return isConfirm;
  }
}
