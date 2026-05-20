import 'dart:io';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/settings_service.dart';

class LiveRoomVolumeManager {
  static final SettingsService settings = Get.find<SettingsService>();

  static String _getVolumeKey(String platform, String roomId) {
    return "room_vol_${platform.toLowerCase().trim()}_${roomId.trim()}";
  }

  static double getRoomVolume(String platform, String roomId) {
    // 全局静音
    if (settings.globalVolumeMute.value) return 0.0;

    final key = _getVolumeKey(platform, roomId);
    final volume = settings.roomVolumes[key];

    if (volume != null) return volume.clamp(0.0, 1.0);

    // 使用全局默认音量
    return Platform.isAndroid || Platform.isIOS
        ? settings.defaultMobileVolume.value.clamp(0.0, 1.0)
        : settings.defaultDesktopVolume.value.clamp(0.0, 1.0);
  }

  static Future<void> saveRoomVolume(String platform, String roomId, double volume) async {
    final key = _getVolumeKey(platform, roomId);
    final safeVolume = volume.clamp(0.0, 1.0);
    Map<String, double> newMap = Map.from(settings.roomVolumes.value);
    newMap[key] = safeVolume;
    settings.roomVolumes.value = newMap;
  }
}
