import 'package:pure_live/common/utils/hive_pref_util.dart';

class LiveRoomVolumeManager {
  static const double defaultVolume = 1.0;

  static String _getVolumeKey(String platform, String roomId) {
    return "room_vol_${platform.toLowerCase().trim()}_${roomId.trim()}";
  }

  static double getRoomVolume(String platform, String roomId) {
    final key = _getVolumeKey(platform, roomId);
    return HivePrefUtil.getDouble(key) ?? defaultVolume;
  }

  static Future<void> saveRoomVolume(String platform, String roomId, double volume) async {
    final key = _getVolumeKey(platform, roomId);
    final safeVolume = volume.clamp(0.0, 1.0);
    await HivePrefUtil.setDouble(key, safeVolume);
  }
}
