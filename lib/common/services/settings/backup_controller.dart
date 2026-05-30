import 'dart:io';
import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class BackupController extends GetxController {
  static BackupController get to => Get.find();

  final backupDirectory = HiveRx.string('backupDirectory', '');
  Map<String, dynamic> exportAllSettings() {
    return {
      "app": Get.find<AppSettingsController>().toJson(),
      "theme": Get.find<ThemeSettingsController>().toJson(),
      "font": Get.find<FontSettingsController>().toJson(),
      "player": Get.find<PlayerSettingsController>().toJson(),
      "danmaku": Get.find<DanmakuSettingsController>().toJson(),
      "volume": Get.find<VolumeSettingsController>().toJson(),
      "favorite": Get.find<FavoriteRoomController>().toJson(),
      "history": Get.find<HistoryController>().toJson(),
      "webdav": Get.find<WebDavController>().toJson(),
      "iptv": Get.find<IptvSettingsController>().toJson(),
    };
  }

  // ==============================
  /// 导入所有设置（给 WebDAV 下载用）
  // ==============================
  void importAllSettings(Map<String, dynamic> data) {
    Get.find<AppSettingsController>().fromJson(data["app"] ?? {});
    Get.find<ThemeSettingsController>().fromJson(data["theme"] ?? {});
    Get.find<FontSettingsController>().fromJson(data["font"] ?? {});
    Get.find<PlayerSettingsController>().fromJson(data["player"] ?? {});
    Get.find<DanmakuSettingsController>().fromJson(data["danmaku"] ?? {});
    Get.find<VolumeSettingsController>().fromJson(data["volume"] ?? {});
    Get.find<FavoriteRoomController>().fromJson(data["favorite"] ?? {});
    Get.find<HistoryController>().fromJson(data["history"] ?? {});
    Get.find<WebDavController>().fromJson(data["webdav"] ?? {});
    Get.find<IptvSettingsController>().fromJson(data["iptv"] ?? {});
  }

  bool backup(File file) {
    try {
      final data = exportAllSettings();
      file.writeAsStringSync(jsonEncode(data));
      return true;
    } catch (e) {
      return false;
    }
  }

  bool recover(File file) {
    try {
      final json = file.readAsStringSync();
      final data = jsonDecode(json);
      importAllSettings(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}
