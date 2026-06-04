import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/services/utils/legacy_settings_migration.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/bilibili_account_service.dart';
import 'package:pure_live/common/services/settings/favorite_room_controller.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings/font_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/common/services/settings/proxy_settings_controller.dart';
import 'package:pure_live/common/services/settings/theme_settings_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/volume_settings_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';

class SettingsService extends GetxService {
  static SettingsService get to => Get.find<SettingsService>();

  AppSettingsController get app => Get.find<AppSettingsController>();
  ExitSettingsController get exit => Get.find<ExitSettingsController>();
  StartupController get startup => Get.find<StartupController>();
  PlayerSettingsController get player => Get.find<PlayerSettingsController>();
  DanmakuSettingsController get danmaku => Get.find<DanmakuSettingsController>();
  FontSettingsController get font => Get.find<FontSettingsController>();
  WindowSizeController get window => Get.find<WindowSizeController>();
  FavoriteRoomController get fav => Get.find<FavoriteRoomController>();
  HistoryController get history => Get.find<HistoryController>();
  CacheController get cache => Get.find<CacheController>();
  CookieSettingsController get cookieManager => Get.find<CookieSettingsController>();
  WebDavController get webdav => Get.find<WebDavController>();
  IptvSettingsController get iptv => Get.find<IptvSettingsController>();
  VolumeSettingsController get vol => Get.find<VolumeSettingsController>();
  ThemeSettingsController get theme => Get.find<ThemeSettingsController>();
  ProxySettingsController get proxy => Get.find<ProxySettingsController>();
  BackupController get backup => Get.find<BackupController>();
  RefreshConfigController get refreshConfig => Get.find<RefreshConfigController>();
  @override
  void onInit() {
    super.onInit();

    Get.lazyPut(() => StartupController());
    Get.lazyPut(() => AppSettingsController());
    Get.lazyPut(() => ThemeSettingsController());
    Get.lazyPut(() => WindowSizeController());
    Get.lazyPut(() => ProxySettingsController());
    Get.put(BiliBiliAccountService(), permanent: true);
    Get.put(FontSettingsController(), permanent: true);
    Get.lazyPut(() => PlayerSettingsController());
    Get.lazyPut(() => DanmakuSettingsController());
    Get.lazyPut(() => VolumeSettingsController());
    Get.lazyPut(() => HistoryController());
    Get.lazyPut(() => RefreshConfigController());
    Get.lazyPut(() => FavoriteRoomController());
    Get.lazyPut(() => IptvSettingsController());
    Get.lazyPut(() => CacheController());
    Get.put(ExitSettingsController(), permanent: true);
    Get.lazyPut(() => CookieSettingsController());
    Get.lazyPut(() => WebDavController());
    Get.lazyPut(() => BackupController());

    bool executionTriggered = false;
    final Timer fallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!executionTriggered) {
        executionTriggered = true;
        _forceEagerInitialization();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!executionTriggered) {
        fallbackTimer.cancel();
        executionTriggered = true;
        _forceEagerInitialization();
      }
    });
  }

  void _forceEagerInitialization() {
    Get.find<StartupController>();
    Get.find<AppSettingsController>();
    Get.find<ThemeSettingsController>();
    Get.find<WindowSizeController>();
    Get.find<ProxySettingsController>();
    Get.find<PlayerSettingsController>();
    Get.find<DanmakuSettingsController>();
    Get.find<VolumeSettingsController>();
    Get.find<HistoryController>();
    Get.find<RefreshConfigController>();
    Get.find<FavoriteRoomController>();
    Get.find<IptvSettingsController>();
    Get.find<CacheController>();
    Get.find<CookieSettingsController>();
    Get.find<WebDavController>();
    Get.find<BackupController>();

    _doMigration();
  }

  Future<void> _doMigration() async {
    await LegacySettingsMigration.migrateIfNeeded();
  }
}
