import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/history_controller.dart';
import 'package:pure_live/common/services/settings/web_dav_controller.dart';
import 'package:pure_live/common/services/settings/startup_controller.dart';
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
  TagManagementController get tagManagement => Get.find<TagManagementController>();

  @override
  void onInit() {
    super.onInit();

    Get.lazyPut(() => StartupController(), fenix: true);
    Get.lazyPut(() => AppSettingsController(), fenix: true);
    Get.lazyPut(() => ThemeSettingsController(), fenix: true);
    Get.lazyPut(() => WindowSizeController(), fenix: true);
    Get.lazyPut(() => ProxySettingsController(), fenix: true);
    Get.lazyPut(() => PlayerSettingsController(), fenix: true);
    Get.lazyPut(() => DanmakuSettingsController(), fenix: true);
    Get.lazyPut(() => VolumeSettingsController(), fenix: true);
    Get.lazyPut(() => HistoryController(), fenix: true);
    Get.lazyPut(() => RefreshConfigController(), fenix: true);
    Get.lazyPut(() => FavoriteRoomController(), fenix: true);
    Get.lazyPut(() => IptvSettingsController(), fenix: true);
    Get.lazyPut(() => CacheController(), fenix: true);
    Get.lazyPut(() => CookieSettingsController(), fenix: true);
    Get.lazyPut(() => PageSettingsController(), fenix: true);
    Get.lazyPut(() => WebDavController(), fenix: true);
    Get.lazyPut(() => BackupController(), fenix: true);
    Get.lazyPut(() => TagManagementController(), fenix: true);
    Get.lazyPut(() => BiliBiliAccountService(), fenix: true);
    Get.lazyPut(() => FontSettingsController(), fenix: true);
    Get.lazyPut(() => LogController(), fenix: true);

    Get.put(ExitSettingsController(), permanent: true);
  }
}
