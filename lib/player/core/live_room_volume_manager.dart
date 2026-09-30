import 'dart:io';

import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings_service.dart';

class LiveRoomVolumeManager {
  static String _getVolumeKey(String platform, String roomId) {
    return "room_vol_${platform.toLowerCase().trim()}_${roomId.trim()}";
  }

  static double getRoomVolume(String platform, String roomId) {
    if (SettingsService.to.vol.globalVolumeMute.v) return 0.0;

    final key = _getVolumeKey(platform, roomId);
    final volume = SettingsService.to.vol.roomVolumes[key];

    if (volume != null && volume.isFinite) return volume.clamp(0.0, 1.0).toDouble();

    return Platform.isAndroid || Platform.isIOS
        ? VolumeSettingsController.normalizeVolume(SettingsService.to.vol.defaultMobileVolume.v, fallback: 0.5)
        : VolumeSettingsController.normalizeVolume(SettingsService.to.vol.defaultDesktopVolume.v, fallback: 1.0);
  }

  static Future<void> saveRoomVolume(String platform, String roomId, double volume) async {
    if (!volume.isFinite) return;
    final key = _getVolumeKey(platform, roomId);
    final newMap = Map<String, double>.from(SettingsService.to.vol.roomVolumes);
    newMap[key] = volume.clamp(0.0, 1.0).toDouble();
    SettingsService.to.vol.roomVolumes = newMap;
  }
}
