import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
import 'package:pure_live/common/services/utils/legacy_settings_migration.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/page_settings_controller.dart';
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
  PageSettingsController get page => Get.find<PageSettingsController>();
  LogController get log => Get.find<LogController>();

  @override
  void onInit() {
    super.onInit();

    Get.lazyPut(() => LogController());
    Get.lazyPut(() => BiliBiliAccountService());
    Get.lazyPut(() => FontSettingsController());
    Get.lazyPut(() => ExitSettingsController());
    Get.lazyPut(() => StartupController());
    Get.lazyPut(() => AppSettingsController());
    Get.lazyPut(() => ThemeSettingsController());
    Get.lazyPut(() => WindowSizeController());
    Get.lazyPut(() => ProxySettingsController());
    Get.lazyPut(() => PlayerSettingsController());
    Get.lazyPut(() => DanmakuSettingsController());
    Get.lazyPut(() => VolumeSettingsController());
    Get.lazyPut(() => HistoryController());
    Get.lazyPut(() => RefreshConfigController());
    Get.lazyPut(() => FavoriteRoomController());
    Get.lazyPut(() => IptvSettingsController());
    Get.lazyPut(() => CacheController());
    Get.lazyPut(() => CookieSettingsController());
    Get.lazyPut(() => PageSettingsController());
    Get.lazyPut(() => WebDavController());
    Get.lazyPut(() => BackupController());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      _forceEagerInitialization();
    });
  }

  void _forceEagerInitialization() {
    Get.put(Get.find<LogController>());
    Get.put(Get.find<BiliBiliAccountService>());
    Get.put(Get.find<FontSettingsController>());
    Get.put(Get.find<ExitSettingsController>());
    Get.put(Get.find<StartupController>());
    Get.put(Get.find<AppSettingsController>());
    Get.put(Get.find<ThemeSettingsController>());
    Get.put(Get.find<WindowSizeController>());
    Get.put(Get.find<ProxySettingsController>());
    Get.put(Get.find<PlayerSettingsController>());
    Get.put(Get.find<DanmakuSettingsController>());
    Get.put(Get.find<VolumeSettingsController>());
    Get.put(Get.find<HistoryController>());
    Get.put(Get.find<RefreshConfigController>());
    Get.put(Get.find<FavoriteRoomController>());
    Get.put(Get.find<IptvSettingsController>());
    Get.put(Get.find<CacheController>());
    Get.put(Get.find<CookieSettingsController>());
    Get.find<PageSettingsController>();
    Get.put(Get.find<WebDavController>());
    Get.put(Get.find<BackupController>());
    _doMigration();
  }

  Future<void> _doMigration() async {
    await LegacySettingsMigration.migrateIfNeeded();
  }
}
