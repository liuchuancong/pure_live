import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings/proxy_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class LegacySettingsMigration {
  static const _migratedKey = 'legacy_settings_migrated_to_v2';

  static Future<void> migrateIfNeeded() async {
    if (HivePrefUtil.getBool(_migratedKey) ?? false) {
      return;
    }

    final legacyData = _readLegacyAllData();
    if (legacyData.isEmpty) {
      HivePrefUtil.setBool(_migratedKey, true);
      return;
    }

    await _migrateToNewControllers(legacyData);

    HivePrefUtil.setBool(_migratedKey, true);
  }

  static Map<String, dynamic> _readLegacyAllData() {
    try {
      return {
        "themeMode": HivePrefUtil.getString("themeMode"),
        "enableDynamicTheme": HivePrefUtil.getBool("enableDynamicTheme"),
        "themeColorSwitch": HivePrefUtil.getString("themeColorSwitch"),
        "language": HivePrefUtil.getString("language"),
        "languageName": HivePrefUtil.getString("languageName"),

        "autoRefreshTime": HivePrefUtil.getInt("autoRefreshTime"),
        "enableDenseFavorites": HivePrefUtil.getBool("enableDenseFavorites"),
        "enableBackgroundPlay": HivePrefUtil.getBool("enableBackgroundPlay"),
        "enableStartUp": HivePrefUtil.getBool("enableStartUp"),
        "enableRotateScreenWithSystem": HivePrefUtil.getBool("enableRotateScreenWithSystem"),
        "enableScreenKeepOn": HivePrefUtil.getBool("enableScreenKeepOn"),
        "enableAutoCheckUpdate": HivePrefUtil.getBool("enableAutoCheckUpdate"),
        "enableFullScreenDefault": HivePrefUtil.getBool("enableFullScreenDefault"),
        "showSplashPage": HivePrefUtil.getBool("showSplashPage"),
        "textScaleFactor": HivePrefUtil.getDouble("textScaleFactor"),
        "crossAxisSpacing": HivePrefUtil.getDouble("crossAxisSpacing"),
        "mainAxisSpacing": HivePrefUtil.getDouble("mainAxisSpacing"),
        "loadingStyle": HivePrefUtil.getString("loadingStyle"),
        "loadingStyleColorSwitch": HivePrefUtil.getString("loadingStyleColorSwitch"),

        // 自动关机
        "autoShutDownTime": HivePrefUtil.getInt("autoShutDownTime"),
        "enableAutoShutDownTime": HivePrefUtil.getBool("enableAutoShutDownTime"),

        // 退出
        "dontAskExit": HivePrefUtil.getBool("dontAskExit"),
        "exitChoose": HivePrefUtil.getString("exitChoose"),

        // 字体
        "fontSizeBodySmall": HivePrefUtil.getDouble("fontSizeBodySmall"),
        "fontSizeBodyMedium": HivePrefUtil.getDouble("fontSizeBodyMedium"),
        "fontSizeBodyLarge": HivePrefUtil.getDouble("fontSizeBodyLarge"),
        "fontSizeTitleMedium": HivePrefUtil.getDouble("fontSizeTitleMedium"),
        "fontSizeTitleLarge": HivePrefUtil.getDouble("fontSizeTitleLarge"),
        "fontFamilyName": HivePrefUtil.getString("fontFamilyName"),
        "danmakuFontFamilyName": HivePrefUtil.getString("danmakuFontFamilyName"),

        // 播放器
        "videoFitIndex": HivePrefUtil.getInt("videoFitIndex"),
        "videoPlayerKey": HivePrefUtil.getString("videoPlayerKey"),
        "useHardStopOnExit": HivePrefUtil.getBool("useHardStopOnExit"),
        "enableCodec": HivePrefUtil.getBool("enableCodec"),
        "playerCompatMode": HivePrefUtil.getBool("playerCompatMode"),
        "customPlayerOutput": HivePrefUtil.getBool("customPlayerOutput"),
        "videoOutputDriver": HivePrefUtil.getString("videoOutputDriver"),
        "audioOutputDriver": HivePrefUtil.getString("audioOutputDriver"),
        "videoHardwareDecoder": HivePrefUtil.getString("videoHardwareDecoder"),
        "floatPlay": HivePrefUtil.getBool("floatPlay"),
        "audioOnly": HivePrefUtil.getBool("audioOnly"),
        "preferResolution": HivePrefUtil.getString("preferResolution"),
        "preferResolutionCellular": HivePrefUtil.getString("preferResolutionCellular"),
        "preferPlatform": HivePrefUtil.getString("preferPlatform"),

        // 弹幕
        "hideDanmaku": HivePrefUtil.getBool("hideDanmaku"),
        "danmakuTopArea": HivePrefUtil.getDouble("danmakuTopArea"),
        "danmakuArea": HivePrefUtil.getDouble("danmakuArea"),
        "danmakuBottomArea": HivePrefUtil.getDouble("danmakuBottomArea"),
        "danmakuSpeed": HivePrefUtil.getDouble("danmakuSpeed"),
        "danmakuFontSize": HivePrefUtil.getDouble("danmakuFontSize"),
        "danmakuFontBorder": HivePrefUtil.getDouble("danmakuFontBorder"),
        "danmakuOpacity": HivePrefUtil.getDouble("danmakuOpacity"),
        "enableDanmakuDisplay": HivePrefUtil.getBool("enableDanmakuDisplay"),

        // 音量
        "defaultMobileVolume": HivePrefUtil.getDouble("defaultMobileVolume"),
        "defaultDesktopVolume": HivePrefUtil.getDouble("defaultDesktopVolume"),
        "globalVolumeMute": HivePrefUtil.getBool("globalVolumeMute"),
        "roomVolumes": _decodeJsonMap(HivePrefUtil.getString("roomVolumes")),

        // Cookie
        "bilibiliCookie": HivePrefUtil.getString("bilibiliCookie"),
        "huyaCookie": HivePrefUtil.getString("huyaCookie"),
        "douyinCookie": HivePrefUtil.getString("douyinCookie"),
        "kuaishouCookie": HivePrefUtil.getString("kuaishouCookie"),

        // 代理
        "enableProxy": HivePrefUtil.getBool("enableProxy"),
        "proxyHost": HivePrefUtil.getString("proxyHost"),
        "proxyPort": HivePrefUtil.getInt("proxyPort"),

        // 收藏、历史、屏蔽
        "favoriteRooms": HivePrefUtil.getStringList("favoriteRooms"),
        "historyRooms": HivePrefUtil.getStringList("historyRooms"),
        "favoriteAreas": HivePrefUtil.getStringList("favoriteAreas"),
        "shieldList": HivePrefUtil.getStringList("shieldList"),
        "hotAreasList": HivePrefUtil.getStringList("hotAreasList"),
        "savedMenuIds": HivePrefUtil.getStringList("savedMenuIds"),

        // WebDAV
        "backupDirectory": HivePrefUtil.getString("backupDirectory"),
        "currentWebDavConfig": HivePrefUtil.getString("currentWebDavConfig"),
        "webDavConfigs": HivePrefUtil.getStringList("webDavConfigs"),
        "m3uDirectory": HivePrefUtil.getString("m3uDirectory"),

        // IPTV
        "selectedSourceName": HivePrefUtil.getString("selectedSourceName"),
        "selectedSourceId": HivePrefUtil.getString("selectedSourceId"),
        "isAutoSyncEnabled": HivePrefUtil.getBool("isAutoSyncEnabled"),
        "autoSyncHoursInterval": HivePrefUtil.getInt("autoSyncHoursInterval"),
        "customIptvUserAgent": HivePrefUtil.getString("customIptvUserAgent"),
      };
    } catch (e) {
      return {};
    }
  }

  static Future<void> _migrateToNewControllers(Map<String, dynamic> legacy) async {
    Get.find<AppSettingsController>().fromJson(legacy);
    Get.find<ThemeSettingsController>().fromJson(legacy);
    Get.find<FontSettingsController>().fromJson(legacy);
    Get.find<PlayerSettingsController>().fromJson(legacy);
    Get.find<DanmakuSettingsController>().fromJson(legacy);
    Get.find<VolumeSettingsController>().fromJson(legacy);
    Get.find<FavoriteRoomController>().fromJson(legacy);
    Get.find<HistoryController>().fromJson(legacy);
    Get.find<WebDavController>().fromJson(legacy);
    Get.find<IptvSettingsController>().fromJson(legacy);
    Get.find<CookieSettingsController>().fromJson(legacy);
    Get.find<ProxySettingsController>().fromJson(legacy);
    Get.find<WindowSizeController>().fromJson(legacy);
    Get.find<ExitSettingsController>().fromJson(legacy);
    Get.find<StartupController>().fromJson(legacy);
  }

  static Map<String, dynamic> _decodeJsonMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (_) {
      return {};
    }
  }
}
